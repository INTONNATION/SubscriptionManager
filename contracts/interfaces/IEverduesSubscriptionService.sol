pragma ton-solidity >=0.56.0;

interface IEverduesSubscriptionService {
	function getParams() external view responsible returns (TvmCell);

	function getInfo() external view responsible returns (TvmCell);

	function cancel() external;
}
