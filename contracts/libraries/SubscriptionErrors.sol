pragma ton-solidity >= 0.39.0;

library SubscriptionErrors {
    uint8 constant error_salt_is_empty = 100;
    uint8 constant error_message_sender_is_not_subsman  = 101;
    uint8 constant error_define_owner_address_in_static_vars = 102;
    uint8 constant error_define_wallet_hash_in_salt = 103;
    uint8 constant error_define_wallet_address_in_static_vars = 104;
    uint8 constant error_not_enough_balance_in_message = 105;
    uint8 constant error_incorrect_service_params = 106;
    uint8 constant error_message_sender_is_not_index = 107;
    uint8 constant error_subscription_status_already_active = 108;
    uint8 constant incorrect_subscription_address_in_constructor = 109;
    uint8 constant error_message_sender_is_not_my_owner = 110;
}