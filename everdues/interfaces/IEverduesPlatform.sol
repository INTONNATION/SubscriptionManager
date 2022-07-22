pragma ton-solidity >=0.56.0;

interface IEverduesPlatform {
	function initializeByRoot(
		TvmCell code,
		TvmCell contract_params,
		uint32 version
	) external;
}