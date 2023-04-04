pragma ton-solidity >=0.56.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../../libraries/EverduesGas.sol";
import "../../libraries/MsgFlag.sol";
import "../../interfaces/IEverduesService.sol";

abstract contract EverduesServiceStorage {
	address public account_address;
	uint256 public owner_pubkey;
	address public subscription_service_index_address;
	address public subscription_service_index_identificator_address;
	uint8 public status = 0;
	uint256 public registation_timestamp;
	TvmCell public service_params;
	TvmCell public identificator;
	uint256 public abi_hash;
	uint8 service_gas_compenstation;
	uint8 subscription_gas_compenstation;
	mapping(uint8 => TvmCell) public subscription_plans;
	mapping(uint8 => string) public supported_chains;
	mapping(uint8 => string[]) public external_supported_tokens;

	address public root;
	TvmCell platform_code;
	TvmCell platform_params;
	uint32 current_version;
	uint8 type_id;


	struct BalanceWalletStruct {
		address currency_root;
		address wallet;
		uint128 tokens;
	}

	struct MetadataStruct {
		TvmCell service_params;
		mapping(uint8 => TvmCell) subscription_plans;
		mapping(uint8 => string) supported_chains;
		mapping(uint8 => string[]) external_supported_tokens;
		address account_address;
	}

	BalanceWalletStruct public wallet_balance;

	function getExternalChainAddress(
		uint8 chain_id
	) external view returns (string) {
		return supported_chains[chain_id];
	}

	function getMetadata() external view returns (MetadataStruct) {
		MetadataStruct returned_data;
		returned_data.service_params = service_params;
		returned_data.subscription_plans = subscription_plans;
		returned_data.supported_chains = supported_chains;
		returned_data.external_supported_tokens = external_supported_tokens;
		returned_data.account_address = account_address;
		return returned_data;
	}

	function getParams(
		uint8 subscription_plan
	) external view responsible returns (TvmCell) {
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

	function getInfo() external view responsible returns (TvmCell) {
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

	function getGasCompenstationProportion()
		external
		view
		responsible
		returns (uint8, uint8)
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.SERVICE_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		return
			{value: 0, bounce: false, flag: MsgFlag.ALL_NOT_RESERVED} (
				service_gas_compenstation,
				subscription_gas_compenstation
			);
	}
}
