pragma ton-solidity >=0.56.0;

interface IEverduesFeeProxy {
	function executePaySubscription(
		address account_address,
		address service_address,
		uint128 value,
		address currency_root,
		address subscription_wallet,
		uint128 account_gas_balance,
		uint128 additional_gas
	) external;

	function setAccountGasThreshold(
		uint128 account_threshold_,
		address send_gas_to
	) external;

	function setSupportedCurrencies(
		TvmCell fee_proxy_contract_params,
		address send_gas_to
	) external;

	function setMTDSRootAddress(address mtds_root, address send_gas_to)
		external;

	function setDexRootAddress(address dex_root, address send_gas_to) external;

	function transferRevenue(address revenue_to, address send_gas_to) external;

	function swapRevenueToMTDS(address currency_root, address send_gas_to)
		external;

	function syncBalance(address currency_root, address send_gas_to) external;

	function upgrade(
		TvmCell code,
		uint32 version,
		address send_gas_to,
		TvmCell contract_params
	) external;
}