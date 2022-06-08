pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/EverduesErrors.sol";
import "libraries/EverduesGas.sol";
import "libraries/MsgFlag.sol";
import "interfaces/IEverduesIndex.sol";
import "interfaces/IEverduesSubscriptionService.sol";

contract SubscriptionService is IEverduesSubscriptionService {
	TvmCell public service_params;
	address public root;
	address public service_owner;
	address public subscription_service_index_address;
	address public subscription_service_index_identificator_address;
	uint8 public status = 0;
	TvmCell platform_code;
	TvmCell platform_params;
	TvmCell code;
	uint32 current_version;
	uint8 type_id;

	struct ServiceParams {
		address to;
		uint128 value;
		uint32 period;
		string name;
		string description;
		string image;
		address currency_root;
		string category;
	}

	ServiceParams public svcparams;

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

	function getParams() external override view responsible returns (TvmCell) {
		tvm.rawReserve(
			math.max(
				EverduesGas.SERVICE_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		return {
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED
		} service_params;
	}

	function getInfo() external override view responsible returns (TvmCell) {
		tvm.rawReserve(
			math.max(
				EverduesGas.SERVICE_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		TvmBuilder info;
		info.store(status);
		return {
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED
		} info.toCell();
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
			status,
			svcparams
		);
		tvm.setcode(code_);
		tvm.setCurrentCode(code_);
		onCodeUpgrade(data);
	}

	function onCodeUpgrade(TvmCell upgrade_data) private {
		(
			address root_,
			address send_gas_to,
			uint32 old_version,
			uint32 version,
			uint8 type_id_,
			TvmCell platform_code_,
			TvmCell platform_params_,
			TvmCell contract_params,
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
		tvm.resetStorage();

		root = root_;
		current_version = version;
		platform_code = platform_code_;
		platform_params = platform_params_;
		type_id = type_id_;
		if (old_version == 0) {
			TvmCell nextCell;
			(service_owner, svcparams.name) = platform_params.toSlice().decode(
				address,
				string
			);
			(
				svcparams.to,
				svcparams.value,
				svcparams.period,
				nextCell
			) = contract_params.toSlice().decode(address, uint128, uint32, TvmCell);
			TvmCell nextCell2;
			(, svcparams.description, svcparams.image, nextCell2) = nextCell
				.toSlice()
				.decode(string, string, string, TvmCell);
			(svcparams.currency_root, svcparams.category) = nextCell2
				.toSlice()
				.decode(address, string);
			service_params = contract_params;
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
				TvmCell service_params_,
				address subscription_service_index_address_,
				address subscription_service_index_identificator_address_,
			    uint8 status_,
				SubscriptionService.ServiceParams svcparams_
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
						address,
						address,
						uint8,
						SubscriptionService.ServiceParams
					)
				);
			service_params = service_params_;
			subscription_service_index_address = subscription_service_index_address_;
			subscription_service_index_identificator_address = subscription_service_index_identificator_address_;
			status = status_;
			svcparams = svcparams_;
			send_gas_to.transfer({
				value: 0,
				flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
			});
		}
	}

	function setIndexes(
		address subscription_service_index_address_,
		address subscription_service_index_identificator_address_
	) external onlyRoot {
		tvm.rawReserve(
			math.max(
				EverduesGas.SERVICE_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		subscription_service_index_address = subscription_service_index_address_;
		subscription_service_index_identificator_address = subscription_service_index_identificator_address_;
		emit ServiceDeployed(subscription_service_index_address, subscription_service_index_identificator_address);
		service_owner.transfer({
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}

	function updateServiceParams(TvmCell new_service_params) public onlyRoot {
		tvm.rawReserve(
			math.max(
				EverduesGas.SERVICE_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		TvmCell nextCell;
		(
			svcparams.to,
			svcparams.value,
			svcparams.period,
			nextCell
		) = new_service_params.toSlice().decode(
			address,
			uint128,
			uint32,
			TvmCell
		);
		TvmCell nextCell2;
		(, svcparams.description, svcparams.image, nextCell2) = nextCell
			.toSlice()
			.decode(string, string, string, TvmCell);
		(svcparams.currency_root, svcparams.category) = nextCell2
			.toSlice()
			.decode(address, string);
		service_params = new_service_params;
		service_owner.transfer({
			value: 0,
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
