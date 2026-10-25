extends Node
## Only native presentation. Earned callbacks never grant a game or platform reward.
var unit := ""
var _initialized := false
var _generation := 0
var _ad: RewardedAd
var _showing := false
var _previous_mute := false

func available() -> bool:
	return OS.get_name() in ["Android", "iOS"] and Engine.has_singleton("PoingGodotAdMob") and not unit.is_empty()

func busy() -> bool: return _showing

func prepare() -> Dictionary:
	if not available(): return {"ok": false, "code": "ads_sdk_unavailable"}
	if _initialized: return {"ok": true}
	if OS.get_name() == "iOS":
		# The iOS product uses no tracking. No ATT or UMP prompt is requested.
		var privacy: Object = Engine.get_singleton("SeoriAccountLink")
		if privacy == null or not privacy.has_method("prepare_non_tracking_ads"):
			return {"ok": false, "code": "ads_privacy_unavailable"}
		privacy.prepare_non_tracking_ads()
		MobileAds.set_gad_has_consent_for_cookies(false)
	else:
		var consent: Dictionary = await _android_consent()
		if not consent.ok: return consent
	MobileAds.set_publisher_first_party_id_enabled(false)
	var configuration := RequestConfiguration.new()
	configuration.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_T
	MobileAds.set_request_configuration(configuration)
	var answer: Array[bool] = []
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status: InitializationStatus) -> void: answer.append(true)
	MobileAds.initialize(listener)
	await _wait(answer, 30000)
	_initialized = not answer.is_empty()
	return {"ok": _initialized, "code": "" if _initialized else "ads_init_timeout"}

func _android_consent() -> Dictionary:
	var information := UserMessagingPlatform.consent_information
	var answer: Array[bool] = []
	information.update(ConsentRequestParameters.new(), func() -> void: answer.append(true), func(_error: FormError) -> void: answer.append(false))
	await _wait(answer, 30000)
	if answer.is_empty() or not answer[0]: return {"ok": false, "code": "ads_consent_unavailable"}
	if information.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED:
		if not information.get_is_consent_form_available(): return {"ok": false, "code": "ads_consent_unavailable"}
		var forms: Array[ConsentForm] = []
		var failed: Array[bool] = []
		UserMessagingPlatform.load_consent_form(func(form: ConsentForm) -> void: forms.append(form), func(_error: FormError) -> void: failed.append(true))
		var deadline := Time.get_ticks_msec() + 30000
		while forms.is_empty() and failed.is_empty() and Time.get_ticks_msec() < deadline: await get_tree().process_frame
		if forms.is_empty(): return {"ok": false, "code": "ads_consent_unavailable"}
		answer.clear()
		forms[0].show(func(error: FormError) -> void: answer.append(error == null))
		await _wait(answer, 180000)
		if answer.is_empty() or not answer[0]: return {"ok": false, "code": "ads_consent_unavailable"}
	return {"ok": information.get_consent_status() in [ConsentInformation.ConsentStatus.NOT_REQUIRED, ConsentInformation.ConsentStatus.OBTAINED], "code": "ads_consent_unavailable"}

func privacy_options_required() -> bool:
	return OS.get_name() == "Android" and available() and UserMessagingPlatform.consent_information.get_privacy_options_requirement_status() == ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED

func privacy_options() -> void:
	if privacy_options_required(): UserMessagingPlatform.show_privacy_options_form()

func load_ad() -> Dictionary:
	if not _initialized: return {"ok": false, "code": "ads_sdk_unavailable"}
	_discard()
	var generation := _generation
	var answer: Array[bool] = []
	var callbacks := RewardedAdLoadCallback.new()
	callbacks.on_ad_loaded = func(ad: RewardedAd) -> void:
		if generation != _generation: ad.destroy()
		else:
			_ad = ad
			answer.append(true)
	callbacks.on_ad_failed_to_load = func(_error: LoadAdError) -> void:
		if generation == _generation: answer.append(false)
	var request := AdRequest.new()
	request.extras = {"npa": "1"}
	RewardedAdLoader.new().load(unit, request, callbacks)
	await _wait(answer, 30000)
	if generation != _generation or answer.is_empty() or not answer[0]:
		_discard()
		return {"ok": false, "code": "ad_load_failed"}
	return {"ok": true}

func show_ad(ssv: Dictionary) -> Dictionary:
	if _ad == null or str(ssv.get("custom_data", "")).is_empty() or str(ssv.get("user_id", "")).is_empty():
		return {"ok": false, "code": "ad_claim_missing"}
	var options := ServerSideVerificationOptions.new()
	options.custom_data = str(ssv.custom_data)
	options.user_id = str(ssv.user_id)
	_ad.set_server_side_verification_options(options)
	var answer: Array[bool] = []
	var generation := _generation
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item: RewardedItem) -> void: pass
	var callbacks := FullScreenContentCallback.new()
	callbacks.on_ad_dismissed_full_screen_content = func() -> void:
		if generation == _generation:
			_restore_audio()
			answer.append(true)
	callbacks.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void:
		if generation == _generation:
			_restore_audio()
			answer.append(false)
	_ad.full_screen_content_callback = callbacks
	_previous_mute = AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, true)
	_showing = true
	_ad.show(listener)
	await _wait(answer, 180000)
	# An unclosed native screen stays busy; a late close cannot satisfy another show.
	if answer.is_empty(): return {"ok": false, "code": "ad_close_timeout"}
	var shown := answer[0]
	_discard()
	return {"ok": shown, "code": "" if shown else "ad_show_failed"}

func _wait(answer: Array, duration: int) -> void:
	var deadline := Time.get_ticks_msec() + duration
	while answer.is_empty() and Time.get_ticks_msec() < deadline: await get_tree().process_frame

func _restore_audio() -> void:
	if _showing: AudioServer.set_bus_mute(0, _previous_mute)
	_showing = false

func _discard() -> void:
	_generation += 1
	if _ad != null:
		_ad.destroy()
		_ad = null

func _exit_tree() -> void:
	_restore_audio()
	_discard()
