pragma ton-solidity >= 0.39.0;

library MetaduesErrors {
    
    uint8 constant error_not_enough_balance_in_message           = 100;
    uint8 constant error_wrong_tvc                               = 101;
    uint8 constant error_address_is_empty                        = 102;
    uint8 constant error_platform_code_is_not_empty              = 103;
    uint8 constant error_message_low_value                       = 104;
        
    uint8 constant error_salt_is_empty                           = 105;
    uint8 constant error_salt_is_not_match_static_var            = 106;
    uint8 constant error_define_owner_in_salt                    = 107;
    uint8 constant error_define_wallet_hash_in_salt              = 108;
    
    
    uint8 constant error_message_sender_is_not_my_owner          = 109;
    uint8 constant error_message_sender_address_not_specified    = 110;
    uint8 constant error_message_sender_is_not_root              = 111;
    uint8 constant error_message_sender_is_not_owner             = 112;
    uint8 constant error_message_sender_is_not_metadues_root     = 113;
    uint8 constant error_message_sender_is_not_index             = 114;
    uint8 constant error_message_sender_is_not_service_owner     = 115;
    uint8 constant error_message_sender_is_not_currency_root     = 116;
    uint8 constant error_message_sender_is_not_dex_root          = 117;
    uint8 constant error_message_sender_is_not_pending_owner     = 118;
    uint8 constant error_message_sender_is_equal_owner           = 119;

    uint8 constant error_wallet_not_exist                        = 120;
    uint8 constant error_subscription_status_already_active      = 121;
    uint8 constant subscription_unknown_account_address         = 122;

}