pragma ton-solidity >=0.56.0;

interface IEverduesIndex {
	function cancel() external;

	function updateIndexData(TvmCell index_data, address send_gas_to) external;
}
