pragma ton-solidity >=0.56.0;

library EverduesGas {

    uint128 constant ROOT_INITIAL_BALANCE                   = 1 ever;
    uint128 constant FEE_PROXY_INITIAL_BALANCE              = 1 ever;

    uint128 constant ACCOUNT_INITIAL_BALANCE                = 0.5 ever;
    uint128 constant SUBSCRIPTION_INITIAL_BALANCE           = 0.5 ever;
    uint128 constant SERVICE_INITIAL_BALANCE                = 0.5 ever;
    uint128 constant INDEX_INITIAL_BALANCE                  = 0.1 ever;

    uint128 constant EXECUTE_SUBSCRIPTION_VALUE             = 0.5 ever;
    uint128 constant DEPLOY_SUBSCRIPTION_VALUE              = 0.5 ever;

    uint128 constant UPGRADE_MIN_VALUE                      = 1 ever;

    uint128 constant TRANSFER_MIN_VALUE                     = 0.6 ever;
    uint128 constant MESSAGE_MIN_VALUE                      = 0.5 ever;

    uint128 constant DEPLOY_EMPTY_WALLET_VALUE              = 0.5 ever;
    uint128 constant DEPLOY_EMPTY_WALLET_GRAMS              = 0.1 ever;

    uint128 constant SWAP_TIP3_TO_EVER_MIN_VALUE            = 4 ever;
}