package com.seorilabs.accountlink

import android.util.Log
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.NoCredentialException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.appcheck.FirebaseAppCheck
import com.google.firebase.appcheck.playintegrity.PlayIntegrityAppCheckProviderFactory
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

/**
 * 계정 연결(ADR 0030)용 Android 플러그인.
 *
 * - Google ID token: Credential Manager. nonce 는 Seori Platform 이 발급한 challenge 값을 그대로 넣는다.
 *   Google 이 그 값을 ID token 의 nonce claim 에 담고 Platform 이 대조한다.
 * - App Check token: Play Integrity Firebase App Check. Platform 이 계정 연결 요청마다 검증한다.
 * 토큰은 저장·로그하지 않고 신호로 한 번만 넘긴다.
 *
 * 신호
 *  - google_id_token(id_token: String)
 *  - google_id_failed(code: String, message: String)
 *    code: cancelled | no_credential | unavailable | busy | invalid_request
 *  - app_check_token(token: String)
 *  - app_check_failed(code: String)  code: unavailable | busy
 */
class SeoriAccountLinkPlugin(godot: Godot) : GodotPlugin(godot) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    @Volatile private var busy = false
    @Volatile private var appCheckBusy = false
    private var appCheck: FirebaseAppCheck? = null

    override fun getPluginName() = "SeoriAccountLink"

    @UsedByGodot
    fun configureFirebase(apiKey: String, appId: String, projectId: String, senderId: String): Boolean {
        val context = activity ?: return false
        if (apiKey.isBlank() || appId.isBlank() || projectId.isBlank() || senderId.isBlank()) return false
        val existing = FirebaseApp.getApps(context).firstOrNull()
        if (existing != null) return existing.options.projectId == projectId && existing.options.applicationId == appId
        val options = FirebaseOptions.Builder().setApiKey(apiKey).setApplicationId(appId)
            .setProjectId(projectId).setGcmSenderId(senderId).build()
        FirebaseApp.initializeApp(context, options)
        return true
    }

    override fun getPluginSignals() = setOf(
        SignalInfo("google_id_token", String::class.java),
        SignalInfo("google_id_failed", String::class.java, String::class.java),
        SignalInfo("app_check_token", String::class.java),
        SignalInfo("app_check_failed", String::class.java),
    )

    @UsedByGodot
    fun signIn(serverClientId: String, nonce: String) {
        val activity = activity
        if (activity == null || serverClientId.isBlank() || nonce.isBlank()) {
            emitSignal("google_id_failed", "invalid_request", "missing activity, client id or nonce")
            return
        }
        if (busy) {
            emitSignal("google_id_failed", "busy", "sign-in already in progress")
            return
        }
        busy = true
        // 버튼으로 시작한 명시적 로그인이라 Sign in with Google 옵션을 쓴다.
        // 기기에 계정이 없어도 계정 추가 화면으로 이어진다.
        val option = GetSignInWithGoogleOption.Builder(serverClientId)
            .setNonce(nonce)
            .build()
        val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
        scope.launch {
            try {
                val result = CredentialManager.create(activity).getCredential(activity, request)
                val credential = result.credential
                if (credential is CustomCredential &&
                    credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL
                ) {
                    val token = GoogleIdTokenCredential.createFrom(credential.data).idToken
                    emitSignal("google_id_token", token)
                } else {
                    emitSignal("google_id_failed", "unavailable", "unexpected credential type")
                }
            } catch (e: GetCredentialCancellationException) {
                emitSignal("google_id_failed", "cancelled", "user cancelled")
            } catch (e: NoCredentialException) {
                emitSignal("google_id_failed", "no_credential", "no Google account available")
            } catch (e: GetCredentialException) {
                Log.w(TAG, "credential error type=${e.type}")
                emitSignal("google_id_failed", "unavailable", e.type)
            } catch (e: Exception) {
                Log.w(TAG, "credential error ${e.javaClass.simpleName}")
                emitSignal("google_id_failed", "unavailable", e.javaClass.simpleName)
            } finally {
                busy = false
            }
        }
    }

    /** Play Integrity App Check token. 캐시된 유효 토큰이 있으면 그대로 준다(Platform 은 소비하지 않고 검증만 한다). */
    @UsedByGodot
    fun appCheckToken() {
        val client = appCheckClient()
        if (client == null) {
            emitSignal("app_check_failed", "unavailable")
            return
        }
        if (appCheckBusy) {
            emitSignal("app_check_failed", "busy")
            return
        }
        appCheckBusy = true
        client.getAppCheckToken(false)
            .addOnSuccessListener { token ->
                appCheckBusy = false
                emitSignal("app_check_token", token.token)
            }
            .addOnFailureListener { e ->
                appCheckBusy = false
                Log.w(TAG, "app check error ${e.javaClass.simpleName}")
                emitSignal("app_check_failed", "unavailable")
            }
    }

    private fun appCheckClient(): FirebaseAppCheck? {
        appCheck?.let { return it }
        val activity = activity ?: return null
        return try {
            // godotx Firebase 가 google-services 설정으로 기본 앱을 이미 만들었다. 없으면 같은 설정으로 만든다.
            val app = FirebaseApp.getApps(activity).firstOrNull() ?: FirebaseApp.initializeApp(activity) ?: return null
            FirebaseAppCheck.getInstance(app).also {
                it.installAppCheckProviderFactory(PlayIntegrityAppCheckProviderFactory.getInstance())
                appCheck = it
            }
        } catch (e: Exception) {
            Log.w(TAG, "app check init ${e.javaClass.simpleName}")
            null
        }
    }

    companion object {
        private const val TAG = "SeoriAccountLink"
    }
}
