pragma ton-solidity >=0.56.0;

import "../libraries/EverduesGas.sol";
import "../libraries/MsgFlag.sol";
import "../interfaces/IEverduesService.sol";

abstract contract EverduesServiceStorage is IEverduesService {
	address public account_address;
	uint256 public owner_pubkey;
	address public subscription_service_index_address;
	address public subscription_service_index_identificator_address;
	uint8 public status = 0;
	uint256 public registation_timestamp;
	TvmCell public service_params;
	mapping(uint8 => TvmCell) public subscription_plans;

	address root;
	TvmCell platform_code;
	TvmCell platform_params;
	uint32 current_version;
	uint8 type_id;

	function getParams(uint8 subscription_plan)
		external
		view
		responsible
		override
		returns (TvmCell)
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.SERVICE_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		TvmCell response = abi.encode(
			service_params,
			subscription_plans[subscription_plan],
			owner_pubkey
		);
		return
			{value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false} response;
	}

	function getInfo() external view responsible override returns (TvmCell) {
		tvm.rawReserve(
			math.max(
				EverduesGas.SERVICE_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		TvmBuilder info;
		info.store(status);
		return
			{value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false} info
				.toCell();
	}
}
