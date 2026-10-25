#pragma once

#include "core/object/ref_counted.h"

#include "core/string/ustring.h"
#include "core/variant/array.h"
#include "core/variant/dictionary.h"
#include "core/variant/type_info.h"

@class GodotStoreKit2Proxy;
@class GodotPhotoShareProxy;
@class TransactionData;
@class InitializationData;

class GodotStoreKit2 : public RefCounted {
	GDCLASS(GodotStoreKit2, RefCounted)

	GodotStoreKit2Proxy *proxy;
	GodotPhotoShareProxy *photo_proxy;

	static void _bind_methods();

	void _on_transaction_state_changed(TransactionData *data);

public:
	// Keep in sync with Swiftenum.
	enum TransactionState {
		FAILED,
		REFUNDED,
		PENDING,
		DEFERRED,
		PURCHASED,
		RESTORED,
		EXPIRED,
		CANCELED,
	};

	bool is_product_available(String p_product_id);
	bool is_product_purchased(String p_product_id);
	Signal request_product_info(String p_product_id);
	Signal request_product_price(String p_product_id);
	Signal purchase_product(String p_product_id, String p_app_account_token, int p_quantity = 1);
	Signal request_refund(String p_product_id);
	Signal current_entitlements(Array p_product_ids);
	Signal request_iap_environment();
	Signal sync();
	bool request_account_token(String p_nonce, String p_client_id);
	bool request_review();
	Dictionary economic_snapshot();
	bool analytics_log_event(String p_payload);
	bool configure_app_check(
			String p_app_id,
			String p_api_key,
			String p_project_id,
			String p_sender_id,
			String p_bundle_id);
	Signal request_app_check_token(bool p_limited_use);
	Dictionary keychain_read(String p_service, String p_account);
	bool keychain_write(String p_service, String p_account, String p_value);
	bool keychain_delete(String p_service, String p_account);
	// 사진 앨범 저장 / 공유 시트. 게임이 이미 저장한 PNG의 절대경로를 받는다.
	Signal save_image_to_photos(String p_path);
	Signal share_image(String p_path, String p_text);
	GodotStoreKit2();
};

VARIANT_ENUM_CAST(GodotStoreKit2::TransactionState)
