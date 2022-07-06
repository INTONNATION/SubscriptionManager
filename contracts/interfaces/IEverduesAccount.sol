pragma ton-solidity >=0.56.0;

interface IEverduesAccount {
	event AccountDeployed(uint32 current_version);
	event Deposit(address walletAddress, uint128 amount);
	event Withdraw(address walletAddress, uint128 amount);
	event BalanceSynced(uint128 balance);

	function paySubscription(
		uint128 value,
		address currency_root,
		address subscription_wallet,
		uint128 pay_subscription_gas
	) external;

	function getNextPaymentStatus(
		address service_address,
		uint128 value,
		address currency_root
	) external responsible returns (uint8, uint128);
}
