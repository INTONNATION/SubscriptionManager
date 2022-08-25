pragma ton-solidity >=0.56.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./EverduesFeeProxyBase.sol";

contract EverduesFeeProxy is EverduesFeeProxyBase {
	function upgrade(
		TvmCell code,
		uint32 version,
		address send_gas_to,
		TvmCell contract_params
	) external onlyRoot {
		tvm.rawReserve(EverduesGas.FEE_PROXY_INITIAL_BALANCE, 2);
		TvmCell data = abi.encode(
			root,
			send_gas_to,
			current_version,
			version,
			type_id,
			platform_code,
			platform_params,
			contract_params,
			code,
			mtds_root_address,
			dex_root_address,
			wallets_mapping
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
			updateSupportedCurrencies(supportedCurrencies, send_gas_to);
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
				mtds_root_address,
				dex_root_address,
				wallets_mapping
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
					address,
					address,
					mapping(address => BalanceWalletStruct)
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
