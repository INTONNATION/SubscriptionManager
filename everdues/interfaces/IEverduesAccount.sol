pragma ton-solidity >=0.56.0;

interface IEverduesAccount {
	event AccountDeployed(uint32 current_version);
	event Deposit(address walletAddress, uint128 amount);
	event Withdraw(address walletAddress, uint128 amount);
	event BalanceSynced(uint128 balance);

	function destroyAccount(address send_gas_to) external;
	
	function paySubscription(
		uint128 value,
		address currency_root,
		address service_address,
		address subscription_wallet,
		bool subscription_deploy,
		bool external_subscription,
		uint128 recurring_payment_gas,
		uint128 additional_gas
	) external;

	function getNextPaymentStatus(
		address service_address,
		uint128 value,
		address currency_root
	) external responsible returns (uint8, uint128);

	function upgrade(
		TvmCell code,
		uint32 version,
		address send_gas_to,
		TvmCell contract_params
	) external;
}
