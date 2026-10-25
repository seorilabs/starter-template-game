// Seori Platform account linking (ADR 0030) for iOS:
// - Sign in with Apple identity token (no name, email or user id is requested or stored)
// - Firebase App Check token (App Attest) that Platform verifies on the account-link endpoints
#pragma once

#include "core/object/object.h"
#include "core/string/ustring.h"

@class SeoriAppleSignInDelegate;

class SeoriAccountLink : public Object {
	GDCLASS(SeoriAccountLink, Object);

	static SeoriAccountLink *singleton;
	SeoriAppleSignInDelegate *delegate = nullptr;
	bool app_check_busy = false;

protected:
	static void _bind_methods();

public:
	static SeoriAccountLink *get_singleton();
	// Must run before FirebaseApp is configured (plugin registration order).
	static void install_app_check_provider();
	bool configure_firebase(const String &p_api_key, const String &p_app_id, const String &p_project_id, const String &p_sender_id);

	// p_nonce is the SHA-256 hex of the Platform challenge nonce. Returns false when it cannot start
	// (busy, no window, bad nonce); otherwise exactly one of apple_id_token / apple_id_failed follows.
	bool sign_in(const String &p_nonce);
	// Returns false when App Check is unavailable or busy; otherwise app_check_token or app_check_failed follows.
	bool app_check_token();
	void prepare_non_tracking_ads();

	void finish(const String &p_token, const String &p_code, const String &p_authorization_code = String());
	void finish_app_check(const String &p_token);

	SeoriAccountLink();
	~SeoriAccountLink();
};
