pragma ton-solidity >=0.56.0;

library MetaduesGas {

    uint128 constant ROOT_INITIAL_BALANCE                   = 1 ever;
    uint128 constant ACCOUNT_INITIAL_BALANCE                = 3 ever;
    uint128 constant SUBSCRIPTION_INITIAL_BALANCE           = 2 ever;
    uint128 constant SERVICE_INITIAL_BALANCE                = 1 ever;
    uint128 constant INDEX_INITIAL_BALANCE                  = 0.1 ever;
    uint128 constant FEE_PROXY_INITIAL_BALANCE              = 1 ever;

    uint128 constant DEPLOY_SUBSCRIPTION_MIN_VALUE          = 1 ever;
    uint128 constant UPDATE_INDEX_VALUE                     = 0.1 ever;

    uint128 constant SET_SERVICE_INDEXES_VALUE              = 0.2 ever;
    uint128 constant EXECUTE_SUBSCRIPTION_VALUE             = 0.5 ever;
    uint128 constant INIT_SUBSCRIPTION_VALUE                = 0.5 ever;
    uint128 constant INIT_MESSAGE_VALUE                     = 0.5 ever;

    uint128 constant UPGRADE_ROOT_MIN_VALUE                 = 2 ever;
    uint128 constant UPGRADE_ACCOUNT_MIN_VALUE              = 2 ever;
    uint128 constant UPGRADE_SUBSCRIPTION_MIN_VALUE         = 2 ever;
    uint128 constant UPGRADE_SERVICE_MIN_VALUE              = 2 ever;
    uint128 constant UPGRADE_FEE_PROXY_MIN_VALUE            = 2 ever;

    uint128 constant TRANSFER_MIN_VALUE                     = 0.6 ever;
    uint128 constant DEPLOY_EMPTY_WALLET_VALUE              = 0.5 ever;
    uint128 constant DEPLOY_EMPTY_WALLET_GRAMS              = 0.2 ever;
    uint128 constant CANCEL_MIN_VALUE                       = 0.5 ever;
}