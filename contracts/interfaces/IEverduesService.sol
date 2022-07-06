pragma ton-solidity >=0.56.0;

interface IEverduesService {
	event ServiceDeployed(
		address subscription_service_index_address,
		address subscription_service_index_identificator_address
	);

	function getParams(uint8 subscription_plan)
		external
		view
		responsible
		returns (TvmCell);

	function getInfo() external view responsible returns (TvmCell);

	function cancel() external;
}
