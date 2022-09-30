pragma ton-solidity >=0.56.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./EverduesFeeProxyBase.sol";

contract EverduesFeeProxy is EverduesFeeProxyBase {
	function upgrade(
		TvmCell code,
		uint32 version,
		address send_gas_to,
		TvmCell upgrade_params
	) external onlyRoot {
		tvm.rawReserve(
			math.max(
				EverduesGas.FEE_PROXY_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		TvmCell contract_params = abi.encode(
			dues_root_address,
			dex_root_address,
			wallets_mapping,
			account_threshold,
			recurring_payment_gas,
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
			address[] supportedCurrencies = abi.decode(
				contract_params,
				(address[])
			);
			setSupportedCurrencies(supportedCurrencies, send_gas_to);
		} else if (old_version > 0) {
			TvmCell upgrade_params;
			(
				dues_root_address,
				dex_root_address,
				wallets_mapping,
				account_threshold,
				recurring_payment_gas,
				upgrade_params
			) = abi.decode(
				contract_params,
				(
					address,
					address,
					mapping(address => BalanceWalletStruct),
					uint128,
					uint128,
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
