pragma ton-solidity >= 0.39.0;

library SubsManErrors {
    uint8 constant error_not_enough_balance_in_message          = 100;
    uint8 constant error_wrong_wallet_tvc                       = 101;
    uint8 constant error_message_sender_is_not_my_owner         = 102;
    uint8 constant error_message_sender_address_not_specified   = 103;
}