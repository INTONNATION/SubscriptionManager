pragma ton-solidity >= 0.57.0;

library MetaduesGas {

    uint128 constant ROOT_INITIAL_BALANCE                   = 1 ton;
    uint128 constant ACCOUNT_INITIAL_BALANCE                = 1 ton;
    uint128 constant SUBSCRIPTION_INITIAL_BALANCE           = 1 ton;
    uint128 constant SERVICE_INITIAL_BALANCE                = 1 ton;
    uint128 constant INDEX_INITIAL_BALANCE                  = 1 ton;

    uint128 constant DEPLOY_ACCOUNT_MIN_VALUE               = 2 ton;
    uint128 constant DEPLOY_SUBSCRIPTION_MIN_VALUE          = 1 ton;
    uint128 constant DEPLOY_FEE_PROXY_MIN_VALUE            = 1 ton;

    uint128 constant SET_SERVICE_INDEXES_VALUE             = 0.5 ton;
    uint128 constant TRANSFER_ROOT_OWNERSHIP_VALUE  = 0.5 ton;
    uint128 constant GET_TOKEN_DETAILS_VALUE        = 0.5 ton;

    uint128 constant PLATFORM_DEPLOY_VALUE          = 0.1 ton;
    uint128 constant SET_PLATFORM_CODE_VALUE        = 0.1 ton;

    uint128 constant UPGRADE_ROOT_MIN_VALUE         = 10 ton;
    uint128 constant UPGRADE_ACCOUNT_MIN_VALUE      = 5 ton;
    uint128 constant UPGRADE_SUBSCRIPTION_MIN_VALUE         = 5 ton;

    uint128 constant TRANSFER_MIN_VALUE             = 1 ton;
    uint128 constant SUCCESS_CALLBACK_VALUE         = 0.1 ton;
}