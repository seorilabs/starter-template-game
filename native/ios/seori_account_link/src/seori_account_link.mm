#import <AuthenticationServices/AuthenticationServices.h>
#import <FirebaseAppCheck/FirebaseAppCheck.h>
#import <FirebaseCore/FirebaseCore.h>
#import <UIKit/UIKit.h>

#include "seori_account_link.h"

#include "core/object/class_db.h"

@interface SeoriAppleSignInDelegate : NSObject <ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding>
@property(nonatomic, strong) ASAuthorizationController *controller;
@property(nonatomic, weak) UIWindow *window;
@end

@implementation SeoriAppleSignInDelegate

- (ASPresentationAnchor)presentationAnchorForAuthorizationController:(ASAuthorizationController *)controller {
	return self.window;
}

- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithAuthorization:(ASAuthorization *)authorization {
	self.controller = nil;
	NSString *token = nil;
	NSString *code = nil;
	if ([authorization.credential isKindOfClass:[ASAuthorizationAppleIDCredential class]]) {
		ASAuthorizationAppleIDCredential *credential = (ASAuthorizationAppleIDCredential *)authorization.credential;
		if (credential.identityToken != nil) {
			token = [[NSString alloc] initWithData:credential.identityToken encoding:NSUTF8StringEncoding];
		}
		// 계정 삭제 때 서버가 Apple 승인을 철회하려면 authorization code 가 필요하다(5분, 1회용).
		if (credential.authorizationCode != nil) {
			code = [[NSString alloc] initWithData:credential.authorizationCode encoding:NSUTF8StringEncoding];
		}
	}
	SeoriAccountLink *plugin = SeoriAccountLink::get_singleton();
	if (plugin == nullptr) {
		return;
	}
	if (token.length > 0) {
		plugin->finish(String::utf8(token.UTF8String), "", code.length > 0 ? String::utf8(code.UTF8String) : String());
	} else {
		plugin->finish("", "invalid_request");
	}
}

- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithError:(NSError *)error {
	self.controller = nil;
	SeoriAccountLink *plugin = SeoriAccountLink::get_singleton();
	if (plugin == nullptr) {
		return;
	}
	// Same codes as the Android SeoriAccountLink plugin.
	String code = "unavailable";
	if ([error.domain isEqualToString:ASAuthorizationErrorDomain]) {
		switch (error.code) {
			case ASAuthorizationErrorCanceled:
				code = "cancelled";
				break;
			case ASAuthorizationErrorNotInteractive:
				code = "no_credential";
				break;
			default:
				break;
		}
	}
	plugin->finish("", code);
}

@end

SeoriAccountLink *SeoriAccountLink::singleton = nullptr;

SeoriAccountLink *SeoriAccountLink::get_singleton() {
	return singleton;
}

void SeoriAccountLink::_bind_methods() {
	ClassDB::bind_method(D_METHOD("configure_firebase", "api_key", "app_id", "project_id", "sender_id"), &SeoriAccountLink::configure_firebase);
	ClassDB::bind_method(D_METHOD("sign_in", "nonce"), &SeoriAccountLink::sign_in);
	ADD_SIGNAL(MethodInfo("apple_id_token", PropertyInfo(Variant::STRING, "id_token"), PropertyInfo(Variant::STRING, "authorization_code")));
	ADD_SIGNAL(MethodInfo("apple_id_failed", PropertyInfo(Variant::STRING, "code"), PropertyInfo(Variant::STRING, "message")));
	ClassDB::bind_method(D_METHOD("app_check_token"), &SeoriAccountLink::app_check_token);
	ClassDB::bind_method(D_METHOD("prepare_non_tracking_ads"), &SeoriAccountLink::prepare_non_tracking_ads);
	ADD_SIGNAL(MethodInfo("app_check_token", PropertyInfo(Variant::STRING, "token")));
	ADD_SIGNAL(MethodInfo("app_check_failed", PropertyInfo(Variant::STRING, "code")));
}

void SeoriAccountLink::prepare_non_tracking_ads() {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	for (NSString *key in [defaults dictionaryRepresentation]) {
		if ([key hasPrefix:@"IABTCF_"] || [key hasPrefix:@"IABGPP_"] || [key isEqualToString:@"IABUSPrivacy_String"]) {
			[defaults removeObjectForKey:key];
		}
	}
}

bool SeoriAccountLink::configure_firebase(const String &p_api_key, const String &p_app_id, const String &p_project_id, const String &p_sender_id) {
	if (p_api_key.is_empty() || p_app_id.is_empty() || p_project_id.is_empty() || p_sender_id.is_empty()) return false;
	if ([FIRApp defaultApp] != nil) {
		return String::utf8([FIRApp defaultApp].options.projectID.UTF8String) == p_project_id
			&& String::utf8([FIRApp defaultApp].options.googleAppID.UTF8String) == p_app_id;
	}
	// App Check must be selected before FirebaseApp is initialized.
	install_app_check_provider();
	FIROptions *options = [[FIROptions alloc]
		initWithGoogleAppID:[NSString stringWithUTF8String:p_app_id.utf8().get_data()]
		GCMSenderID:[NSString stringWithUTF8String:p_sender_id.utf8().get_data()]];
	options.APIKey = [NSString stringWithUTF8String:p_api_key.utf8().get_data()];
	options.projectID = [NSString stringWithUTF8String:p_project_id.utf8().get_data()];
	[FIRApp configureWithOptions:options];
	return [FIRApp defaultApp] != nil;
}

void SeoriAccountLink::install_app_check_provider() {
	if ([FIRApp defaultApp] != nil) {
		// The provider factory only applies to apps configured after it is set.
		NSLog(@"SeoriAccountLink: FirebaseApp already configured, App Check provider not installed");
		return;
	}
	[FIRAppCheck setAppCheckProviderFactory:[FIRAppAttestProviderFactory new]];
}

bool SeoriAccountLink::app_check_token() {
	if (app_check_busy || [FIRApp defaultApp] == nil) {
		return false;
	}
	app_check_busy = true;
	// Platform verifies without consuming, so a cached valid token is fine.
	[[FIRAppCheck appCheck] tokenForcingRefresh:NO
									 completion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
										 dispatch_async(dispatch_get_main_queue(), ^{
											 SeoriAccountLink *plugin = SeoriAccountLink::get_singleton();
											 if (plugin == nullptr) {
												 return;
											 }
											 String value = (token != nil && token.token.length > 0) ? String::utf8(token.token.UTF8String) : String();
											 plugin->finish_app_check(value);
										 });
									 }];
	return true;
}

void SeoriAccountLink::finish_app_check(const String &p_token) {
	app_check_busy = false;
	if (p_token.is_empty()) {
		call_deferred(SNAME("emit_signal"), "app_check_failed", "unavailable");
	} else {
		call_deferred(SNAME("emit_signal"), "app_check_token", p_token);
	}
}

static UIWindow *seori_key_window() {
	for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
		if (![scene isKindOfClass:[UIWindowScene class]]) {
			continue;
		}
		for (UIWindow *window in ((UIWindowScene *)scene).windows) {
			if (window.isKeyWindow) {
				return window;
			}
		}
	}
	return nil;
}

bool SeoriAccountLink::sign_in(const String &p_nonce) {
	if (p_nonce.is_empty() || p_nonce.length() > 128 || delegate.controller != nil) {
		return false;
	}
	UIWindow *window = seori_key_window();
	if (window == nil) {
		return false;
	}
	ASAuthorizationAppleIDRequest *request = [[ASAuthorizationAppleIDProvider new] createRequest];
	// No name or email scope: the identity token alone proves the account.
	request.requestedScopes = @[];
	request.nonce = [NSString stringWithUTF8String:p_nonce.utf8().get_data()];
	ASAuthorizationController *controller = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[ request ]];
	delegate.window = window;
	delegate.controller = controller;
	controller.delegate = delegate;
	controller.presentationContextProvider = delegate;
	[controller performRequests];
	return true;
}

void SeoriAccountLink::finish(const String &p_token, const String &p_code, const String &p_authorization_code) {
	// Signals reach GDScript on the next main loop iteration, never inside the UIKit callback.
	if (p_token.is_empty()) {
		call_deferred(SNAME("emit_signal"), "apple_id_failed", p_code, "");
	} else {
		call_deferred(SNAME("emit_signal"), "apple_id_token", p_token, p_authorization_code);
	}
}

SeoriAccountLink::SeoriAccountLink() {
	singleton = this;
	delegate = [SeoriAppleSignInDelegate new];
}

SeoriAccountLink::~SeoriAccountLink() {
	if (singleton == this) {
		singleton = nullptr;
	}
	delegate = nil;
}
