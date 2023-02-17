pragma ton-solidity >=0.56.0;

library EverduesErrors {
	uint8 constant error_address_is_empty = 101;
	uint8 constant error_platform_code_is_not_empty = 102;
	uint8 constant error_message_low_value = 103;
	uint8 constant error_salt_is_empty = 104;
	uint8 constant error_message_sender_is_not_owner = 105;
	uint8 constant error_message_sender_is_not_everdues_root = 106;
	uint8 constant error_message_sender_is_not_service_owner = 107;
	uint8 constant error_message_sender_is_not_currency_root = 108;
	uint8 constant error_message_sender_is_not_dex_root = 109;
	uint8 constant error_message_sender_is_not_pending_owner = 110;
	uint8 constant error_message_sender_is_equal_owner = 111;
	uint8 constant error_message_sender_is_not_service_address = 112;
	uint8 constant error_message_sender_is_not_account_address = 113;
	uint8 constant error_wallet_not_exist = 114;
	uint8 constant error_subscription_status_already_active = 115;
	uint8 constant error_subscription_status_is_not_processed = 125;
	uint8 constant error_subscription_already_executed = 116;
	uint8 constant error_subscription_is_stopped = 117;
	uint8 constant error_subscription_has_no_service_params = 118;
	uint8 constant error_service_is_not_active = 119;
	uint8 constant error_message_sender_is_not_subscription_wallet = 120;
	uint8 constant error_message_sender_is_not_feeproxy_wallet = 121;
	uint8 constant error_message_sender_is_not_account_wallet = 122;
	uint8 constant error_message_sender_is_not_root_wallet = 126;
	uint8 constant error_message_sender_is_not_my_subscription = 123;
	uint8 constant error_message_sender_is_not_dex_pair = 124;
	uint8 constant error_service_tokens_already_locked = 127;
	uint8 constant error_tip3_low_value = 128;
	uint8 constant error_subscription_status_is_not_stopped = 129;
}
