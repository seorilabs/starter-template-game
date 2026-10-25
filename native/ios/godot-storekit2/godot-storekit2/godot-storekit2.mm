#include "godot-storekit2.h"

#include <cmath>

#include "core/object/class_db.h"

#import "godot_storekit2-Swift.h"

@import StoreKit;
@import UIKit;
#import <Security/Security.h>
#import <objc/message.h>

static NSString *fromGodotString(const String &src) {
	return [NSString stringWithUTF8String:src.utf8().get_data()];
}

static String toGodotString(NSString *src) {
	if (src == nil) {
		return String();
	}
	return String::utf8(src.UTF8String);
}

// StoreKit 오류의 분류와 숫자만 남긴다. Apple ID, 영수증, 서버 응답은 기록하지 않는다.
static NSString *safeStoreKitErrorDomain(NSString *domain) {
	if ([domain isEqualToString:SKErrorDomain]) {
		return @"StoreKit";
	}
	if ([domain isEqualToString:NSURLErrorDomain]) {
		return @"URL";
	}
	if ([domain isEqualToString:NSCocoaErrorDomain]) {
		return @"Cocoa";
	}
	if ([domain isEqualToString:@"AMSErrorDomain"]) {
		return @"AMS";
	}
	if ([domain isEqualToString:@"ASDErrorDomain"]) {
		return @"ASD";
	}
	return @"Other";
}

static Dictionary transactionDictionary(TransactionData *data) {
	Dictionary result;
	result["error"] = toGodotString(data.error);
	result["product_id"] = toGodotString(data.productId);
	result["transaction_id"] = toGodotString(data.transactionId);
	result["original_transaction_id"] = toGodotString(data.originalTransactionId);
	result["app_account_token"] = toGodotString(data.appAccountToken);
	result["environment"] = toGodotString(data.environment);
	result["transaction_state"] = (GodotStoreKit2::TransactionState)data.transactionState;
	return result;
}

void GodotStoreKit2::_bind_methods() {
 ClassDB::bind_method(D_METHOD("request_account_token", "nonce", "client_id"), &GodotStoreKit2::request_account_token);
 ADD_SIGNAL(MethodInfo("account_token_received", PropertyInfo(Variant::STRING, "token"), PropertyInfo(Variant::STRING, "code")));
	ClassDB::bind_method(D_METHOD("request_product_info", "product_id"), &GodotStoreKit2::request_product_info);
	ClassDB::bind_method(D_METHOD("purchase_product", "product_id", "app_account_token", "quantity"), &GodotStoreKit2::purchase_product, DEFVAL(1));
	ClassDB::bind_method(D_METHOD("request_refund", "product_id"), &GodotStoreKit2::request_refund);
	ClassDB::bind_method(D_METHOD("current_entitlements", "product_ids"), &GodotStoreKit2::current_entitlements);
	ClassDB::bind_method(D_METHOD("request_iap_environment"), &GodotStoreKit2::request_iap_environment);
	ClassDB::bind_method(D_METHOD("sync"), &GodotStoreKit2::sync);
	ClassDB::bind_method(D_METHOD("request_review"), &GodotStoreKit2::request_review);
	ClassDB::bind_method(D_METHOD("economic_snapshot"), &GodotStoreKit2::economic_snapshot);
	ClassDB::bind_method(D_METHOD("analytics_log_event", "payload"), &GodotStoreKit2::analytics_log_event);
	ClassDB::bind_method(
			D_METHOD("configure_app_check", "app_id", "api_key", "project_id", "sender_id", "bundle_id"),
			&GodotStoreKit2::configure_app_check);
	ClassDB::bind_method(D_METHOD("request_app_check_token", "limited_use"), &GodotStoreKit2::request_app_check_token);
	ClassDB::bind_method(D_METHOD("keychain_read", "service", "account"), &GodotStoreKit2::keychain_read);
	ClassDB::bind_method(D_METHOD("keychain_write", "service", "account", "value"), &GodotStoreKit2::keychain_write);
	ClassDB::bind_method(D_METHOD("keychain_delete", "service", "account"), &GodotStoreKit2::keychain_delete);
	ClassDB::bind_method(D_METHOD("save_image_to_photos", "path"), &GodotStoreKit2::save_image_to_photos);
	ClassDB::bind_method(D_METHOD("share_image", "path", "text"), &GodotStoreKit2::share_image);

	ADD_SIGNAL(MethodInfo("transaction_state_changed", PropertyInfo(Variant::DICTIONARY, "transaction")));
	ADD_SIGNAL(MethodInfo("purchase_completed", PropertyInfo(Variant::DICTIONARY, "transaction")));
	ADD_SIGNAL(MethodInfo("refund_request_completed", PropertyInfo(Variant::DICTIONARY, "response")));
	ADD_SIGNAL(MethodInfo("product_price_received", PropertyInfo(Variant::DICTIONARY, "price")));
	ADD_SIGNAL(MethodInfo("product_info_received", PropertyInfo(Variant::DICTIONARY, "info")));
	ADD_SIGNAL(MethodInfo("current_entitlements_received", PropertyInfo(Variant::DICTIONARY, "response")));
	ADD_SIGNAL(MethodInfo("iap_environment_received", PropertyInfo(Variant::DICTIONARY, "response")));
	ADD_SIGNAL(MethodInfo("synchronized", PropertyInfo(Variant::STRING, "error")));
	ADD_SIGNAL(MethodInfo("app_check_token_received", PropertyInfo(Variant::DICTIONARY, "response")));
	ADD_SIGNAL(MethodInfo("photo_library_saved", PropertyInfo(Variant::DICTIONARY, "response")));
	ADD_SIGNAL(MethodInfo("photo_share_completed", PropertyInfo(Variant::DICTIONARY, "response")));

	BIND_ENUM_CONSTANT(FAILED);
	BIND_ENUM_CONSTANT(REFUNDED);
	BIND_ENUM_CONSTANT(PENDING);
	BIND_ENUM_CONSTANT(DEFERRED);
	BIND_ENUM_CONSTANT(PURCHASED);
	BIND_ENUM_CONSTANT(RESTORED);
	BIND_ENUM_CONSTANT(EXPIRED);
	BIND_ENUM_CONSTANT(CANCELED);
}

Signal GodotStoreKit2::request_product_info(String p_product_id) {
	[proxy getProductInfoWithProductId:fromGodotString(p_product_id) completionHandler:^(ProductInfo *info, NSError *error) {
		Dictionary result;
		if (error) {
			result["error"] = toGodotString(error.userInfo[NSLocalizedDescriptionKey]);
		} else {
			result["error"] = String();
			result["product_id"] = toGodotString(info.productId);
			result["display_name"] = toGodotString(info.displayName);
			result["description"] = toGodotString(info.productDescription);
			result["is_purchased"] = info.isPurchased;
			PriceInfo *priceInfo = info.priceInfo;
			result["currency_value"] = priceInfo.currencyValue;
			result["currency_code"] =  toGodotString(priceInfo.currencyCode);
			result["currency_symbol"] = toGodotString(priceInfo.currencySymbol);
			result["localized_price"] = toGodotString(priceInfo.localizedDisplay);
		}

		call_deferred("emit_signal", "product_info_received", result);
	}];

	return Signal(this, "product_info_received");
}

Signal GodotStoreKit2::purchase_product(String p_product_id, String p_app_account_token, int p_quantity) {;
	[proxy purchaseProductWithProductId:fromGodotString(p_product_id) appAccountToken:fromGodotString(p_app_account_token) quantity:p_quantity completionHandler:^(TransactionData *data, NSError *error) {
		Dictionary result;
		if (error) {
			result["error"] = toGodotString(error.userInfo[NSLocalizedDescriptionKey]);
		} else {
			result = transactionDictionary(data);
		}

		call_deferred("emit_signal", "purchase_completed", result);
	}];

	return Signal(this, "purchase_completed");
}

Signal GodotStoreKit2::request_refund(String p_product_id) {
	[proxy requestRefundWithProductId:fromGodotString(p_product_id) completionHandler:^(NSString *status, NSError *error) {
		Dictionary result;
		result["product_id"] = p_product_id;
		if (error) {
			result["ok"] = false;
			result["error"] = toGodotString(error.userInfo[NSLocalizedDescriptionKey]);
		} else {
			result["ok"] = true;
			result["status"] = toGodotString(status);
			result["error"] = String();
		}

		call_deferred("emit_signal", "refund_request_completed", result);
	}];

	return Signal(this, "refund_request_completed");
}

Signal GodotStoreKit2::current_entitlements(Array p_product_ids) {
	NSMutableArray<NSString *> *product_ids = [NSMutableArray arrayWithCapacity:p_product_ids.size()];
	for (int64_t index = 0; index < p_product_ids.size(); index++) {
		[product_ids addObject:fromGodotString(String(p_product_ids[index]))];
	}
	[proxy getCurrentEntitlementsWithProductIds:product_ids completionHandler:^(NSArray<TransactionData *> *data, NSError *error) {
		Dictionary result;
		Array transactions;
		if (!error) {
			for (TransactionData *transaction in data) {
				transactions.push_back(transactionDictionary(transaction));
			}
		}
		result["ok"] = error == nil;
		result["transactions"] = transactions;
		call_deferred("emit_signal", "current_entitlements_received", result);
	}];

	return Signal(this, "current_entitlements_received");
}

Signal GodotStoreKit2::request_iap_environment() {
	[proxy getIapEnvironmentWithCompletionHandler:^(NSString *environment, NSError *error) {
		Dictionary result;
		result["ok"] = error == nil && environment.length > 0;
		result["environment"] = error == nil ? toGodotString(environment) : String();
		call_deferred("emit_signal", "iap_environment_received", result);
	}];
	return Signal(this, "iap_environment_received");
}

Signal GodotStoreKit2::sync() {
	[proxy restorePurchasesWithCompletionHandler:^(NSError *error) {
		String result;
		if (error) {
			NSError *underlying = error.userInfo[NSUnderlyingErrorKey];
			if (![underlying isKindOfClass:NSError.class]) {
				underlying = nil;
			}
			NSLog(@"[iap] storekit_sync_failed domain=%@ code=%ld underlying_domain=%@ underlying_code=%ld",
					safeStoreKitErrorDomain(error.domain), (long)error.code,
					underlying ? safeStoreKitErrorDomain(underlying.domain) : @"None",
					underlying ? (long)underlying.code : 0L);
			result = toGodotString(error.localizedDescription);
		}

		call_deferred("emit_signal", "synchronized", result);
	}];

	return Signal(this, "synchronized");
}

// 긍정 순간의 명시적 사용자 액션이 끝난 직후 Godot main thread에서 호출된다.
// StoreKit은 quota에 따라 sheet를 표시하지 않을 수 있으므로 foreground scene 확보와
// requestReview API 호출 여부만 반환하고, 표시·리뷰 작성 여부는 추론하지 않는다.
bool GodotStoreKit2::request_review() {
	if (@available(iOS 14.0, *)) {
		for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
			if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:UIWindowScene.class]) {
				[SKStoreReviewController requestReviewInScene:(UIWindowScene *)scene];
				return true;
			}
		}
	}
	return false;
}

// ProcessInfo.systemUptime은 같은 OS 부팅 세션에서 프로세스 재시작 뒤에도 이어진다.
// Date는 10분 버킷 boot epoch 식별자에만 쓰며, 시계가 바뀌어 ID가 달라지면 경과를
// 더하지 않고 새 기준점만 저장하도록 도메인 계층이 fail-closed 한다.
Dictionary GodotStoreKit2::economic_snapshot() {
	Dictionary result;
	double uptime_seconds = NSProcessInfo.processInfo.systemUptime;
	if (!std::isfinite(uptime_seconds) || uptime_seconds <= 0.0) {
		result["trusted"] = false;
		result["source"] = "ios_unavailable";
		result["anchor_id"] = String();
		result["anchor_msec"] = 0;
		return result;
	}
	double boot_epoch_seconds = NSDate.date.timeIntervalSince1970 - uptime_seconds;
	int64_t boot_bucket = (int64_t)std::floor(boot_epoch_seconds / 600.0);
	result["trusted"] = true;
	result["source"] = "ios_system_uptime";
	result["anchor_id"] = String("ios:") + String::num_int64(boot_bucket);
	result["anchor_msec"] = (int64_t)std::floor(uptime_seconds * 1000.0);
	return result;
}

bool GodotStoreKit2::analytics_log_event(String p_payload) {
	Class bridge_class = NSClassFromString(@"GodotFirebaseAppCheckBridge");
	SEL selector = NSSelectorFromString(@"logEventWithPayload:");
	if (bridge_class == Nil || ![bridge_class respondsToSelector:selector]) {
		return false;
	}
	using LogEventFunction = BOOL (*)(id, SEL, NSString *);
	auto log_event = reinterpret_cast<LogEventFunction>(objc_msgSend);
	return log_event(bridge_class, selector, fromGodotString(p_payload));
}

bool GodotStoreKit2::configure_app_check(
		String p_app_id,
		String p_api_key,
		String p_project_id,
		String p_sender_id,
		String p_bundle_id) {
	Class bridge_class = NSClassFromString(@"GodotFirebaseAppCheckBridge");
	SEL selector = NSSelectorFromString(@"configureWithAppID:apiKey:projectID:senderID:bundleID:");
	if (bridge_class == Nil || ![bridge_class respondsToSelector:selector]) {
		return false;
	}
	using ConfigureFunction = BOOL (*)(id, SEL, NSString *, NSString *, NSString *, NSString *, NSString *);
	auto configure = reinterpret_cast<ConfigureFunction>(objc_msgSend);
	return configure(
			bridge_class,
			selector,
			fromGodotString(p_app_id),
			fromGodotString(p_api_key),
			fromGodotString(p_project_id),
			fromGodotString(p_sender_id),
			fromGodotString(p_bundle_id));
}

Signal GodotStoreKit2::request_app_check_token(bool p_limited_use) {
	Class bridge_class = NSClassFromString(@"GodotFirebaseAppCheckBridge");
	SEL selector = NSSelectorFromString(@"requestTokenWithLimitedUse:completion:");
	if (bridge_class == Nil || ![bridge_class respondsToSelector:selector]) {
		Dictionary result;
		result["ok"] = false;
		result["error"] = "app_check_bridge_unavailable";
		call_deferred("emit_signal", "app_check_token_received", result);
		return Signal(this, "app_check_token_received");
	}

	using RequestTokenFunction = void (*)(id, SEL, BOOL, void (^)(NSString *, NSString *));
	auto request_token = reinterpret_cast<RequestTokenFunction>(objc_msgSend);
	request_token(bridge_class, selector, p_limited_use, ^(NSString *token, NSString *error) {
		Dictionary result;
		if (error != nil || token == nil || token.length == 0) {
			result["ok"] = false;
			result["error"] = toGodotString(error);
		} else {
			Dictionary token_result;
			token_result["token"] = toGodotString(token);
			result["ok"] = true;
			result["result"] = token_result;
		}
		call_deferred("emit_signal", "app_check_token_received", result);
	});
	return Signal(this, "app_check_token_received");
}

// 사진 앨범 저장. 빈 error 문자열이면 성공, 그 외에는 실패 사유다.
Signal GodotStoreKit2::save_image_to_photos(String p_path) {
	[photo_proxy saveImageWithPath:fromGodotString(p_path) completion:^(NSString *error) {
		Dictionary result;
		bool ok = error == nil || error.length == 0;
		result["ok"] = ok;
		result["error"] = ok ? String() : toGodotString(error);
		call_deferred("emit_signal", "photo_library_saved", result);
	}];

	return Signal(this, "photo_library_saved");
}

// 공유 시트. 사용자가 취소하면 ok=false, error="cancelled"로 돌아온다.
Signal GodotStoreKit2::share_image(String p_path, String p_text) {
	[photo_proxy shareImageWithPath:fromGodotString(p_path) text:fromGodotString(p_text) completion:^(NSString *error) {
		Dictionary result;
		bool ok = error == nil || error.length == 0;
		result["ok"] = ok;
		result["error"] = ok ? String() : toGodotString(error);
		call_deferred("emit_signal", "photo_share_completed", result);
	}];

	return Signal(this, "photo_share_completed");
}

GodotStoreKit2::GodotStoreKit2() {
	proxy = [[GodotStoreKit2Proxy alloc] initWithTransactionCallback:^(TransactionData *data) {
		_on_transaction_state_changed(data);
	}];
	photo_proxy = [[GodotPhotoShareProxy alloc] init];
}

void GodotStoreKit2::_on_transaction_state_changed(TransactionData *data) {
	call_deferred("emit_signal", "transaction_state_changed", transactionDictionary(data));
}

Dictionary GodotStoreKit2::keychain_read(String p_service, String p_account) {
	Dictionary result;
	NSDictionary *query = @{
		(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
		(__bridge id)kSecAttrService: fromGodotString(p_service),
		(__bridge id)kSecAttrAccount: fromGodotString(p_account),
		(__bridge id)kSecReturnData: @YES,
		(__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne,
	};
	CFTypeRef item = nullptr;
	OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &item);
	if (status == errSecItemNotFound) {
		result["ok"] = true;
		result["found"] = false;
		return result;
	}
	if (status != errSecSuccess || item == nullptr) {
		result["ok"] = false;
		return result;
	}
	NSData *data = (__bridge_transfer NSData *)item;
	NSString *value = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if (value == nil) {
		result["ok"] = false;
		return result;
	}
	result["ok"] = true;
	result["found"] = true;
	result["value"] = toGodotString(value);
	return result;
}

bool GodotStoreKit2::keychain_write(String p_service, String p_account, String p_value) {
	NSDictionary *query = @{
		(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
		(__bridge id)kSecAttrService: fromGodotString(p_service),
		(__bridge id)kSecAttrAccount: fromGodotString(p_account),
	};
	NSData *data = [fromGodotString(p_value) dataUsingEncoding:NSUTF8StringEncoding];
	NSDictionary *update = @{ (__bridge id)kSecValueData: data };
	OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)update);
	if (status == errSecItemNotFound) {
		NSMutableDictionary *insert = [query mutableCopy];
		insert[(__bridge id)kSecValueData] = data;
		insert[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
		status = SecItemAdd((__bridge CFDictionaryRef)insert, nullptr);
	}
	return status == errSecSuccess;
}

bool GodotStoreKit2::keychain_delete(String p_service, String p_account) {
	NSDictionary *query = @{
		(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
		(__bridge id)kSecAttrService: fromGodotString(p_service),
		(__bridge id)kSecAttrAccount: fromGodotString(p_account),
	};
	OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
	return status == errSecSuccess || status == errSecItemNotFound;
}


bool GodotStoreKit2::request_account_token(String p_nonce, String p_client_id) {
	[proxy requestAccountTokenWithNonce:fromGodotString(p_nonce) clientId:fromGodotString(p_client_id) completion:^(NSString *token, NSString *code) {
		call_deferred("emit_signal", "account_token_received", toGodotString(token), toGodotString(code));
	}];
	return true;
}
