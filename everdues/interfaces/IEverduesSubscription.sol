pragma ton-solidity >=0.56.0;

interface IEverduesSubscription {
	event paramsRecieved(TvmCell service_params_);
	event SubscriptionDeleted();

	function subscriptionStatus() external returns (uint8);

	function executeSubscription(uint128 paySubscriptionGas) external;

	function upgradeSubscriptionPlan(uint8 new_subscription_plan) external;

	function upgrade(
		TvmCell code,
		uint32 version,
		address send_gas_to,
		TvmCell contract_params_
	) external;
}
