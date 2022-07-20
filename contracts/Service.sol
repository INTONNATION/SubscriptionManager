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

	constructor() public {
		revert();
	}

	modifier onlyRoot() {
		require(
			msg.sender == root,
			EverduesErrors.error_message_sender_is_not_everdues_root
		);
		_;
	}

	modifier onlyOwner() {
		require(
			msg.pubkey() == owner_pubkey,
			EverduesErrors.error_message_sender_is_not_owner
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

	function pause() external onlyOwner {
		tvm.accept();
		status = 1;
	}

	function resume() external onlyOwner {
		tvm.accept();
		status = 0;
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
			status,
			owner_pubkey
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
				subscription_service_index_identificator_address,
				owner_pubkey
			) = abi.decode(additional_params, (address, address, uint256));
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
				status,
				owner_pubkey
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
					uint8,
					uint256
				)
			);
			send_gas_to.transfer({
				value: 0,
				bounce: false,
				flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
			});
		}
	}

	function updateServiceParams(TvmCell new_service_params) external onlyOwner {
		tvm.accept();
		TvmCell subscription_plans_cell;
		(service_params, subscription_plans_cell) = abi.decode(
			new_service_params,
			(TvmCell, TvmCell)
		);
		subscription_plans = abi.decode(
			subscription_plans_cell,
			mapping(uint8 => TvmCell)
		);
	}

	function cancel() external override onlyOwner {
		emit ServiceDeleted();
		IEverduesIndex(subscription_service_index_address).cancel();
		IEverduesIndex(subscription_service_index_identificator_address)
			.cancel();
		selfdestruct(account_address);
	}

	function updateIdentificator(TvmCell identificator_)
		external
		view
		onlyOwner
	{
		IEverduesIndex(subscription_service_index_identificator_address)
			.updateIdentificator{value: 0, flag: MsgFlag.REMAINING_GAS}(
			identificator_,
			address(this)
		);
	}
}
