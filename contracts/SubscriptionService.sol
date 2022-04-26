pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/MetaduesErrors.sol";
import "libraries/MetaduesGas.sol";
import "libraries/MsgFlag.sol";
import "interfaces/IEverduesIndex.sol";

contract SubscriptionService {
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
	address public root;
	address public service_owner;
	address public subscription_service_index_address;
	address public subscription_service_index_identificator_address;
	TvmCell platform_code;
	TvmCell platform_params;
	TvmCell code;
	uint32 current_version;
	uint8 type_id;
	TvmCell public service_params;
	uint8 public status = 0;

	ServiceParams public svcparams;

	constructor() public {
		revert();
	}

	modifier onlyRoot() {
		require(
			msg.sender == root,
			MetaduesErrors.error_message_sender_is_not_root
		);
		_;
	}

	function getParams() external view responsible returns (TvmCell) {
		tvm.rawReserve(MetaduesGas.SERVICE_INITIAL_BALANCE, 2);
		return service_params;
	}

	function getInfo() external view responsible returns (TvmCell) {
		tvm.rawReserve(MetaduesGas.SERVICE_INITIAL_BALANCE, 2);
		TvmBuilder info;
		info.store(status);
		return info.toCell();
	}

	function pause() public onlyRoot {
		tvm.rawReserve(MetaduesGas.SERVICE_INITIAL_BALANCE, 2);
		status = 1;
		service_owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	function resume() public onlyRoot {
		tvm.rawReserve(MetaduesGas.SERVICE_INITIAL_BALANCE, 2);
		status = 0;
		service_owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	function upgrade(
		TvmCell code,
		uint32 version,
		address send_gas_to
	) external onlyRoot {
		tvm.rawReserve(MetaduesGas.SERVICE_INITIAL_BALANCE, 2);
		TvmBuilder builder;
		TvmBuilder upgrade_params;
		builder.store(root);
		builder.store(send_gas_to);
		builder.store(current_version);
		builder.store(version);
		builder.store(type_id);
		builder.store(platform_code);
		builder.store(platform_params);
		builder.store(service_params);
		builder.store(code);
		tvm.setcode(code);
		tvm.setCurrentCode(code);
		onCodeUpgrade(builder.toCell());
	}

	function onCodeUpgrade(TvmCell upgrade_data) private {
		tvm.rawReserve(MetaduesGas.SERVICE_INITIAL_BALANCE, 2);
		TvmSlice s = upgrade_data.toSlice();
		(
			address root_,
			address send_gas_to,
			uint32 old_version,
			uint32 version,
			uint8 type_id_
		) = s.decode(address, address, uint32, uint32, uint8);

		if (old_version == 0) {
			tvm.resetStorage();
		}

		root = root_;
		current_version = version;
		type_id = type_id_;
		TvmCell nextCell;
		platform_code = s.loadRef();
		platform_params = s.loadRef();
		(service_owner, svcparams.name) = platform_params.toSlice().decode(
			address,
			string
		);
		service_params = s.loadRef();
		(
			svcparams.to,
			svcparams.value,
			svcparams.period,
			nextCell
		) = service_params.toSlice().decode(address, uint128, uint32, TvmCell);
		TvmCell nextCell2;
		(, svcparams.description, svcparams.image, nextCell2) = nextCell
			.toSlice()
			.decode(string, string, string, TvmCell);
		(svcparams.currency_root, svcparams.category) = nextCell2
			.toSlice()
			.decode(address, string);
		send_gas_to.transfer({
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}

	function setIndexes(
		address subscription_service_index_address_,
		address subscription_service_index_identificator_address_
	) external onlyRoot {
		tvm.rawReserve(MetaduesGas.SERVICE_INITIAL_BALANCE, 2);
		subscription_service_index_address = subscription_service_index_address_;
		subscription_service_index_identificator_address = subscription_service_index_identificator_address_;
		service_owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	function updateServiceParams(TvmCell new_service_params) public onlyRoot {
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
		service_owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function cancel() external onlyRoot {
		IEverduesIndex(subscription_service_index_address).cancel();
		IEverduesIndex(subscription_service_index_identificator_address)
			.cancel();
		selfdestruct(service_owner);
	}

	function updateIdentificator(TvmCell identificator_, address send_gas_to)
		external
		onlyRoot
	{
		IEverduesIndex(subscription_service_index_identificator_address)
			.updateIdentificator{value: 0, flag: MsgFlag.REMAINING_GAS}(
			identificator_,
			send_gas_to
		);
	}
}
