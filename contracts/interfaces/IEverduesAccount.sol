pragma ton-solidity >=0.56.0;

interface IEverduesAccount {
    function paySubscription(
        uint128 value,
        address currency_root,
        address account_wallet,
        address subscription_wallet,
        address service_address,
        uint128 pay_subscription_gas
    ) external responsible returns (uint8);
}