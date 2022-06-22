pragma ton-solidity >=0.56.0;

interface IEverduesRoot {
	function deployAccount(uint256 pubkey) external;

	function deploySubscription(
		address service_address,
		TvmCell identificator,
		uint256 owner_pubkey,
		uint8 subscription_plan,
		uint128 additional_gas
	) external;

	function deployService(
		TvmCell service_params,
		TvmCell identificator,
		uint256 owner_pubkey,
		bool publish_to_catalog,
		uint128 additional_gas
	) external;

	function upgradeAccount(uint256 pubkey) external;

	function upgradeService(
		string service_name,
		string category,
		uint256 owner_pubkey
	) external;

	function upgradeSubscription(address service_address, uint256 owner_pubkey)
		external;

	function upgradeSubscriptionPlan(
		address service_address,
		uint8 subscription_plan,
		uint256 owner_pubkey
	) external;

	function updateServiceIdentificator(
		string service_name,
		TvmCell identificator,
		uint256 owner_pubkey
	) external;

	function updateServiceParams(
		string service_name,
		TvmCell new_service_params,
		uint256 owner_pubkey
	) external;

	function updateSubscriptionIdentificator(
		address service_address,
		TvmCell identificator,
		uint256 owner_pubkey
	) external;

	function cancelService(string name, uint256 owner_pubkey) external;
}
