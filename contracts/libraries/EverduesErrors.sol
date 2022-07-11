pragma ton-solidity >=0.56.0;

library EverduesErrors {
	uint8 constant error_address_is_empty = 102;
	uint8 constant error_platform_code_is_not_empty = 103;
	uint8 constant error_message_low_value = 104;
	uint8 constant error_salt_is_empty = 105;
	uint8 constant error_message_sender_is_not_owner = 112;
	uint8 constant error_message_sender_is_not_everdues_root = 113;
	uint8 constant error_message_sender_is_not_service_owner = 115;
	uint8 constant error_message_sender_is_not_currency_root = 116;
	uint8 constant error_message_sender_is_not_dex_root = 117;
	uint8 constant error_message_sender_is_not_pending_owner = 118;
	uint8 constant error_message_sender_is_equal_owner = 119;
	uint8 constant error_message_sender_is_not_service_address = 120;
	uint8 constant error_message_sender_is_not_account_address = 121;
	uint8 constant error_wallet_not_exist = 122;
	uint8 constant error_subscription_status_already_active = 123;
	uint8 constant error_subscription_already_executed = 126;
	uint8 constant error_subscription_is_stopped = 128;
	uint8 constant error_service_is_not_active = 129;
	uint8 constant error_message_sender_is_not_subscription_wallet = 130;
	uint8 constant error_message_sender_is_not_feeproxy_wallet = 131;
	uint8 constant error_message_sender_is_not_account_wallet = 132;
	uint8 constant error_message_sender_is_not_my_subscription = 134;
	uint8 constant error_message_sender_is_not_dex_pair = 135;
}
