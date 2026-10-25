@tool
extends EditorPlugin
## Android 내보내기에 SeoriAccountLink AAR 과 Credential Manager·App Check 의존성을 넣는다.
## 소스: native/android/seori_account_link, 빌드: tools/build_android_identity.sh

var export_plugin: AccountLinkExportPlugin


func _enter_tree() -> void:
	export_plugin = AccountLinkExportPlugin.new()
	add_export_plugin(export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(export_plugin)
	export_plugin = null


class AccountLinkExportPlugin extends EditorExportPlugin:
	const PLUGIN_NAME := "SeoriAccountLink"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		var build_type := "debug" if debug else "release"
		return PackedStringArray(["seori_account_link/bin/%s/%s-%s.aar" % [build_type, PLUGIN_NAME, build_type]])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		# 플러그인 build.gradle 의 compileOnly 와 같은 버전이어야 한다.
		return PackedStringArray([
			"androidx.credentials:credentials:1.5.0",
			"androidx.credentials:credentials-play-services-auth:1.5.0",
			"com.google.android.libraries.identity.googleid:googleid:1.1.1",
			"org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0",
			"com.google.firebase:firebase-appcheck-playintegrity:19.4.1",
		])

	func _get_name() -> String:
		return PLUGIN_NAME
