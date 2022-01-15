pragma ton-solidity >= 0.39.0;

library SubscriptionServiceErrors {
    uint8 constant error_salt_is_empty                       = 100;
    uint8 constant error_message_sender_is_not_subsman       = 101;
    uint8 constant error_define_owner_in_salt                = 102;
    uint8 constant error_message_sender_is_not_index         = 103;
    uint8 constant error_message_sender_is_not_service_owner = 104;
    uint8 constant error_low_message_value                   = 105;
}