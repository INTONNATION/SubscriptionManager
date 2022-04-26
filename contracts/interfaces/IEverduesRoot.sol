pragma ton-solidity >=0.56.0;

interface IEverduesRoot {

	function deployAccount(uint256 pubkey) external;
	function deploySubscription(address service_address, TvmCell identificator, uint256 owner_pubkey, uint128 additional_gas) external;
    function deployService(TvmCell service_params, TvmCell identificator, uint128 additional_gas) external;

    function upgradeAccount(uint256 pubkey) external;
	function upgradeService(string service_name, string category) external;
	function upgradeSubscription(address service_address) external;

	function updateServiceIdentificator(string service_name, string category, TvmCell identificator) external;
	function updateServiceParams(string service_name, string category, TvmCell new_service_params) external;
	function updateSubscriptionIdentificator(address service_address, TvmCell identificator) external;

	function cancelSubscription(address service_address) external;
	function cancelService(string name) external;
}