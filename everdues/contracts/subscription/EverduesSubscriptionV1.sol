pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "./EverduesSubscriptionBase.sol";

contract EverduesSubscriprion_V1 is EverduesSubscriptionBase {
	function upgrade(
		TvmCell code,
		uint32 version,
		address send_gas_to,
		TvmCell contract_params_
	) external override onlyRoot {
		TvmCell data = abi.encode(
			root,
			send_gas_to,
			current_version,
			version,
			type_id,
			platform_code,
			platform_params,
			contract_params_,
			code,
			subscription,
			address_fee_proxy,
			account_address,
			subscription_index_address,
			subscription_index_identificator_address,
			service_fee,
			subscription_fee,
			svcparams,
			preprocessing_window,
			subscription_wallet,
			service_address,
			owner_pubkey,
			subscription_plan,
			service_pubkey,
			compensate_subscription_deploy
		);
		tvm.setcode(code);
		tvm.setCurrentCode(code);
		onCodeUpgrade(data);
	}

	function onCodeUpgrade(TvmCell upgrade_data) private {
		tvm.rawReserve(EverduesGas.SUBSCRIPTION_INITIAL_BALANCE, 0);
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
			(
				address_fee_proxy,
				service_fee,
				subscription_fee,
				root_pubkey,
				subscription_index_address,
				subscription_index_identificator_address,
				service_address,
				account_address,
				owner_pubkey,
				subscription_plan,
				identificator,
				abi_hash
			) = abi.decode(
				contract_params,
				(
					address,
					uint8,
					uint8,
					uint256,
					address,
					address,
					address,
					address,
					uint256,
					uint8,
					TvmCell,
					uint256
				)
			);
			compensate_subscription_deploy = true;
			IEverduesService(service_address).getParams{
				value: 0,
				bounce: true,
				flag: MsgFlag.ALL_NOT_RESERVED,
				callback: EverduesSubscriptionBase.onGetParams
			}(subscription_plan);
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
				subscription,
				address_fee_proxy,
				account_address,
				subscription_index_address,
				subscription_index_identificator_address,
				service_fee,
				subscription_fee,
				svcparams,
				preprocessing_window,
				subscription_wallet,
				service_address,
				owner_pubkey,
				subscription_plan,
				service_pubkey,
				compensate_subscription_deploy,
				identificator,
				abi_hash
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
					EverduesSubscriptionStorage.paymentStatus,
					address,
					address,
					address,
					address,
					uint8,
					uint8,
					EverduesSubscriptionStorage.serviceParams,
					uint32,
					address,
					address,
					uint256,
					uint8,
					uint256,
					bool,
					TvmCell,
					uint256
				)
			);
			send_gas_to.transfer({
				value: 0,
				flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
			});
		}
	}
}
