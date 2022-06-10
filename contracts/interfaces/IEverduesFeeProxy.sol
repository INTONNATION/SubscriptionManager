pragma ton-solidity >=0.56.0;

interface IEverduesFeeProxy {
	//event AccountDeployed(uint32 current_version);

	function executePaySubscription(address account_address, address service_address, uint128 value, address currency_root, address subscription_wallet, uint128 account_gas_balance, uint128 additional_gas) external;
}
