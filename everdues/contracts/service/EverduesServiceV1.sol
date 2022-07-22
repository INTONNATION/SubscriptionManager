pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "./EverduesServiceBase.sol";

contract EverduesService_V1 is EverduesServiceBase {
	function upgrade(
		TvmCell code_,
		uint32 version,
		address send_gas_to,
		TvmCell contract_params
	) external override onlyRoot {
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
		// check that contract deployed from root
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
}
