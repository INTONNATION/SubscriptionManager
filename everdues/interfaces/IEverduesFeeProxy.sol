pragma ton-solidity >=0.56.0;

interface IEverduesFeeProxy {
	function executePaySubscription(
		address account_address,
		address service_address,
		uint128 value,
		address currency_root,
		address subscription_wallet,
		uint128 account_gas_balance,
		bool subscription_deploy,
		bool external_subscription,
		uint128 additional_gas
	) external;

	function setAccountGasThreshold(
		uint128 account_threshold_,
		address send_gas_to
	) external;

	function setRecurringPaymentGas(uint128 recurring_payment_gas_) external;

	function updateSupportedCurrencies(
		TvmCell fee_proxy_contract_params,
		address send_gas_to
	) external;

	function updateSupportedWrappedTokens(address tip3_root, address send_gas_to) external;

	function setDUESRootAddress(address dues_root, address send_gas_to)
		external;

	function setDexRootAddress(address dex_root, address send_gas_to) external;

	function transferRevenue(address revenue_to, address send_gas_to) external;

	function swapRevenueToDUES(address currency_root, address send_gas_to)
		external;

	function syncBalance(address currency_root, address send_gas_to) external;

	function swapTIP3ToEver(
		uint128 amount,
		address currency_root,
		address dex_ever_pair_address,
		address tip3_to_ever_address
	) external;

	function upgrade(
		TvmCell code,
		uint32 version,
		address send_gas_to,
		TvmCell contract_params
	) external;
}
