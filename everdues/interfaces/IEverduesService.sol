pragma ton-solidity >=0.56.0;
import "../contracts/service/EverduesServiceStorage.sol";

interface IEverduesService {

	function getGasCompenstationProportion() external view responsible returns(uint8 service_gas_compenstation,uint8 subscription_gas_compenstation);
	
	function getMetadata() external view responsible returns(EverduesServiceStorage.MetadataStruct);

	function getParams(uint8 subscription_plan)
		external
		view
		responsible
		returns (TvmCell);

	function getInfo() external view responsible returns (TvmCell);

	function cancel() external;

	function upgrade(
		TvmCell code_,
		uint32 version,
		address send_gas_to,
		TvmCell contract_params
	) external;
}
