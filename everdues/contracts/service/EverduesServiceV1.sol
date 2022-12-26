pragma ton-solidity >=0.56.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./EverduesServiceBase.sol";

contract EverduesService_V1 is EverduesServiceBase {
	function upgrade(
		TvmCell code,
		uint32 version,
		address send_gas_to,
		TvmCell upgrade_params
	) external override onlyRoot {
		TvmCell contract_params = abi.encode(
			service_params,
			subscription_plans,
			subscription_service_index_address,
			subscription_service_index_identificator_address,
			status,
			owner_pubkey,
			account_address,
			service_gas_compenstation,
			subscription_gas_compenstation,
			identificator,
			abi_hash,
			supported_chains,
			external_supported_tokens,
			wallet_balance,
			upgrade_params
		);
		TvmCell data = abi.encode(
			root,
			send_gas_to,
			current_version,
			version,
			type_id,
			platform_code,
			platform_params,
			contract_params,
			code
		);
		tvm.setcode(code);
		tvm.setCurrentCode(code);
		onCodeUpgrade(data);
	}

	function onCodeUpgrade(TvmCell upgrade_data) private {
		tvm.rawReserve(EverduesGas.SERVICE_INITIAL_BALANCE, 0);
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
			(account_address) = abi.decode(platform_params, (address));
			(TvmCell service_params_cell, TvmCell additional_params) = abi
				.decode(contract_params, (TvmCell, TvmCell));
			TvmCell subscription_plans_cell;
			TvmCell supported_chains_cell;
			TvmCell supported_external_tokens_cell;
			(service_params, subscription_plans_cell, supported_chains_cell, supported_external_tokens_cell) = abi.decode(
				service_params_cell,
				(TvmCell, TvmCell, TvmCell, TvmCell)
			);
			subscription_plans = abi.decode(
				subscription_plans_cell,
				(mapping(uint8 => TvmCell))
			);
			supported_chains = abi.decode(
				supported_chains_cell,
				(mapping(uint8 => string))
			);
			external_supported_tokens = abi.decode(
				supported_external_tokens_cell,
				(mapping(uint8 => string[]))
			);
			(
				subscription_service_index_address,
				subscription_service_index_identificator_address,
				owner_pubkey,
				service_gas_compenstation,
				subscription_gas_compenstation,
				identificator,
				abi_hash
			) = abi.decode(
				additional_params,
				(address, address, uint256, uint8, uint8, TvmCell, uint256)
			);
			emit ServiceDeployed(
				subscription_service_index_address,
				subscription_service_index_identificator_address
			);
			registation_timestamp = now;
		} else if (old_version > 0) {
			TvmCell upgrade_params;
			(
				service_params,
				subscription_plans,
				subscription_service_index_address,
				subscription_service_index_identificator_address,
				status,
				owner_pubkey,
				account_address,
				service_gas_compenstation,
				subscription_gas_compenstation,
				identificator,
				abi_hash,
				supported_chains,
				external_supported_tokens,
				wallet_balance,
				upgrade_params
			) = abi.decode(
				contract_params,
				(
					TvmCell,
					mapping(uint8 => TvmCell),
					address,
					address,
					uint8,
					uint256,
					address,
					uint8,
					uint8,
					TvmCell,
					uint256,
					mapping(uint8 => string),
					mapping(uint8 => string[]),
					BalanceWalletStruct,
					TvmCell
				)
			);
			if (!upgrade_params.toSlice().empty()) {
				// parse upgrade data
			}
			send_gas_to.transfer({
				value: 0,
				bounce: false,
				flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
			});
		}
	}
}
