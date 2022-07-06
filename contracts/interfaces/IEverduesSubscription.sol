pragma ton-solidity >=0.56.0;

interface IEverduesSubscription {
	event paramsRecieved(TvmCell service_params_);

	function subscriptionStatus() external returns (uint8);

	function executeSubscription(uint128 paySubscriptionGas) external;

	function replenishGas() external;
}
