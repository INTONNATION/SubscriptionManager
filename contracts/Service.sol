pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/EverduesErrors.sol";
import "libraries/EverduesGas.sol";
import "libraries/MsgFlag.sol";
import "interfaces/IEverduesIndex.sol";
import "interfaces/IEverduesService.sol";

contract Service is IEverduesService {
	address public root;
	address public service_owner;
	address public subscription_service_index_address;
	address public subscription_service_index_identificator_address;
	uint8 public status = 0;
	uint256 public registation_timestamp;
	mapping(uint8 => TvmCell) public subscription_plans;
	TvmCell public service_params;
	TvmCell platform_code;
	TvmCell platform_params;
	TvmCell code;
	uint32 current_version;
	uint8 type_id;

	constructor() public {
		revert();
	}

	modifier onlyRoot() {
		require(
			msg.sender == root,
			EverduesErrors.error_message_sender_is_not_root
		);
		_;
	}

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
			subscription_plans[subscription_plan]
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

	function pause() public onlyRoot {
		tvm.rawReserve(
			math.max(
				EverduesGas.SERVICE_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		status = 1;
		service_owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}

	function resume() public onlyRoot {
		tvm.rawReserve(
			math.max(
				EverduesGas.SERVICE_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		status = 0;
		service_owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}

	function upgrade(
		TvmCell code_,
		uint32 version,
		address send_gas_to,
		TvmCell contract_params
	) external onlyRoot {
		TvmCell data = abi.encode(
			root,
			send_gas_to,
			current_version,
			version,
			type_id,
			platform_code,
			platform_params,
			contract_params,
			code_,
			service_params,
			subscription_service_index_address,
			subscription_service_index_identificator_address,
			status
		);
		tvm.setcode(code_);
		tvm.setCurrentCode(code_);
		onCodeUpgrade(data);
	}

	function onCodeUpgrade(TvmCell upgrade_data) private {
		tvm.resetStorage();
		address send_gas_to;
		uint32 old_version;
		TvmCell contract_params;
		(
			root,
			send_gas_to,
			old_version,
			current_version,
			type_id,
			platform_code,
			platform_params,
			contract_params,
			/*TvmCell code*/

		) = abi.decode(
			upgrade_data,
			(
				address,
				address,
				uint32,
				uint32,
				uint8,
				TvmCell,
				TvmCell,
				TvmCell,
				TvmCell
			)
		);
		if (old_version == 0) {
			(TvmCell service_params_cell, TvmCell additional_params) = abi
				.decode(contract_params, (TvmCell, TvmCell));
			TvmCell subscription_plans_cell;
			(service_params, subscription_plans_cell) = abi.decode(
				service_params_cell,
				(TvmCell, TvmCell)
			);
			subscription_plans = abi.decode(
				subscription_plans_cell,
				(mapping(uint8 => TvmCell))
			);
			(
				subscription_service_index_address,
				subscription_service_index_identificator_address
			) = abi.decode(additional_params, (address, address));
			emit ServiceDeployed(
				subscription_service_index_address,
				subscription_service_index_identificator_address
			);
			registation_timestamp = now;
		} else if (old_version > 0) {
			(
				,
				,
				,
				,
				,
				,
				,
				,
				,
				service_params,
				subscription_plans,
				subscription_service_index_address,
				subscription_service_index_identificator_address,
				status
			) = abi.decode(
				upgrade_data,
				(
					address,
					address,
					uint32,
					uint32,
					uint8,
					TvmCell,
					TvmCell,
					TvmCell,
					TvmCell,
					TvmCell,
					mapping(uint8 => TvmCell),
					address,
					address,
					uint8
				)
			);
			send_gas_to.transfer({
				value: 0,
				bounce: false,
				flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
			});
		}
	}

	function updateServiceParams(TvmCell new_service_params) public onlyRoot {
		tvm.rawReserve(
			math.max(
				EverduesGas.SERVICE_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		TvmCell subscription_plans_cell;
		(service_params, subscription_plans_cell) = abi.decode(
			new_service_params,
			(TvmCell, TvmCell)
		);
		subscription_plans = abi.decode(
			subscription_plans_cell,
			mapping(uint8 => TvmCell)
		);
		service_owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}

	function cancel() external override onlyRoot {
		IEverduesIndex(subscription_service_index_address).cancel();
		IEverduesIndex(subscription_service_index_identificator_address)
			.cancel();
		selfdestruct(service_owner);
	}

	function updateIdentificator(TvmCell identificator_, address send_gas_to)
		external
		view
		onlyRoot
	{
		IEverduesIndex(subscription_service_index_identificator_address)
			.updateIdentificator{value: 0, flag: MsgFlag.REMAINING_GAS}(
			identificator_,
			send_gas_to
		);
	}
}
