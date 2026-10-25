extends RefCounted
## Buttons drive public account operations; provider proofs never enter UI fields.

static func show_account(c: Control) -> void:
	c._clear(c.tr_text("My account", "내 계정"))
	var box: VBoxContainer = c._scroll()
	var info: Dictionary = c.accounts.details
	box.add_child(c._label(c.tr_text("Connected account", "연결된 계정") if c.accounts.connected() else c.tr_text("Create or recover an account to connect services.", "계정을 만들거나 복구하면 서비스를 이용할 수 있습니다."), 20))
	if not info.is_empty():
		box.add_child(c._label("UID  " + str(info.get("uid", "—")), 18))
	if not str(info.get("saveStatus", "")).is_empty():
		box.add_child(c._label(c.tr_text("Cloud save: ", "클라우드 저장: ") + str(info.saveStatus)))
	if not str(info.get("deletionStatus", "")).is_empty():
		box.add_child(c._label(c.tr_text("Deletion request: ", "탈퇴 요청: ") + str(info.deletionStatus)))
	if c.accounts.status == "busy":
		box.add_child(c._label(c.tr_text("Connecting…", "연결 중입니다…")))
	elif not c.accounts.error.is_empty():
		box.add_child(c._label(c._error_text(c.accounts.error)))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	var create: Button = c._button(c.tr_text("Create new account", "새 계정 만들기"), func() -> void:
		if c.accounts.connected(): confirmation(c, "create")
		else: c.accounts.perform("create")
	, grid)
	create.name = "account_create"
	create.disabled = not c.accounts.capabilities().get("create", false) or c.accounts.status == "busy"
	c._button(c.tr_text("UID and support code", "UID와 지원 코드"), func() -> void: c._open("support"), grid).name = "account_identifiers"
	var recover: Button = c._button(c.tr_text("Recover previous account", "이전 계정 복구"), func() -> void: c._open("account_recovery"), grid)
	recover.name = "account_recovery"
	recover.disabled = not c.accounts.capabilities().get("recover", false) or c.accounts.status == "busy"
	c._button(c.tr_text("Link and manage account", "계정 연결과 관리"), func() -> void: c._open("account_manage"), grid).name = "account_manage"
	for item in [["refresh", c.tr_text("Refresh account and save", "계정과 저장 새로 확인")], ["deletion_status", c.tr_text("Check deletion request", "탈퇴 처리 상태 확인")]]:
		var action := str(item[0])
		if c.accounts.capabilities().get(action, false):
			c._button(str(item[1]), func() -> void: c.accounts.perform(action), grid).name = "account_" + action
	for item in [["keep_cloud", c.tr_text("Load server progress", "서버 진행 불러오기")], ["keep_local", c.tr_text("Use this device's progress", "이 기기 진행 사용")]]:
		var action := str(item[0])
		if c.accounts.capabilities().get(action, false):
			c._button(str(item[1]), func() -> void: confirmation(c, action), grid).name = "account_" + action
	if c.accounts.port == null:
		box.add_child(c._label(c.tr_text("Account services are unavailable in this build.", "이 빌드에서는 계정 서비스를 지원하지 않습니다.")))

static func manage(c: Control) -> void:
	c._clear(c.tr_text("Manage account", "계정 관리"))
	var box: VBoxContainer = c._scroll()
	var caps: Dictionary = c.accounts.capabilities()
	for provider in caps.get("providers", []):
		var selected := str(provider)
		var link: Button = c._button(c.tr_text("Link with %s", "%s로 계정 연결") % selected.capitalize(), func() -> void: c.accounts.perform("link", {"provider": selected}), box)
		link.name = "link_" + selected
		link.disabled = not c.accounts.connected() or c.accounts.status == "busy"
	var logout: Button = c._button(c.tr_text("Sign out", "로그아웃"), func() -> void: confirmation(c, "logout"), box)
	logout.name = "account_logout"
	logout.disabled = not c.accounts.connected() or not caps.get("logout", false)
	var delete: Button = c._button(c.tr_text("Delete account", "계정 탈퇴"), func() -> void: confirmation(c, "delete"), box)
	delete.name = "account_delete"
	delete.disabled = not c.accounts.connected() or not caps.get("delete", false)
	box.add_child(c._label(c.tr_text("Link your account before signing out so you can recover it.", "로그아웃 전에 계정을 연결해 두면 이전 계정을 복구할 수 있습니다.")))

static func recovery(c: Control) -> void:
	c._clear(c.tr_text("Recover account", "계정 복구"))
	var box: VBoxContainer = c._scroll()
	box.add_child(c._label(c.tr_text("Enter your previous UID, then sign in with its linked provider.", "이전 UID를 입력하고 연결해 둔 로그인 수단으로 인증해 주세요.")))
	var uid := LineEdit.new()
	uid.name = "recovery_uid"
	uid.placeholder_text = c.tr_text("Previous account UID", "이전 계정 UID")
	uid.custom_minimum_size.y = 56 * c._ui_scale()
	uid.max_length = 128
	box.add_child(uid)
	for provider in c.accounts.capabilities().get("providers", []):
		var selected := str(provider)
		c._button(c.tr_text("Recover with %s", "%s로 계정 복구") % selected.capitalize(), func() -> void:
			if uid.text.strip_edges().is_empty():
				c._show_error("expected_uid_required")
				return
			c.accounts.perform("recover", {"provider": selected, "expectedUid": uid.text.strip_edges()})
		, box).name = "recover_" + selected

static func confirmation(c: Control, action: String) -> void:
	c.config.account_action = action
	c._open("account_confirmation")

static func confirm(c: Control) -> void:
	var action := str(c.config.get("account_action", ""))
	c._clear(c.tr_text("Confirm account action", "계정 작업 확인"))
	var box: VBoxContainer = c._scroll()
	box.add_child(c._label("UID  " + str(c.accounts.details.get("uid", "—"))))
	var description: String = c.tr_text("Your current account will be signed out. Save its UID and link it before continuing.", "현재 계정에서 로그아웃합니다. 계속하기 전에 UID를 보관하고 계정을 연결해 주세요.")
	if action == "delete":
		description = c.tr_text("This requests permanent deletion of this account and its saved data. It cannot be undone.", "이 계정과 저장 데이터의 영구 삭제를 요청합니다. 되돌릴 수 없습니다.")
	elif action == "keep_cloud":
		description = c.tr_text("Replace this device's progress with the server save? Unsynced progress will be backed up on this device.", "서버 저장으로 이 기기의 진행을 바꿀까요? 아직 보내지 못한 진행은 이 기기에 백업합니다.")
	elif action == "keep_local":
		description = c.tr_text("Replace the server save with this device's progress? The other device's progress may be replaced.", "이 기기의 진행을 서버에 보낼까요? 다른 기기에서 진행한 내용이 바뀔 수 있습니다.")
	box.add_child(c._label(description, 20))
	var proceed: Button = c._button(c.tr_text("Confirm and continue", "확인하고 계속"), func() -> void: c.accounts.perform(action), box, true)
	proceed.name = "account_confirm"
	proceed.disabled = c.accounts.status == "busy"
	c._button(c.tr_text("Cancel", "취소"), c._back, box).name = "account_cancel"
