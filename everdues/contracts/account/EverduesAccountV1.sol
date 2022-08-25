pragma ton-solidity >=0.56.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../../interfaces/IEverduesAccount.sol";
import "./EverduesAccountBase.sol";

contract EverduesAccount_V1 is IEverduesAccount, EverduesAccountBase {
	function upgrade(
		TvmCell code,
		uint32 version,
		TvmCell contract_params
	) external override onlyRoot {
		TvmCell data = abi.encode(
			root,
			current_version,
			version,
			type_id,
			platform_code,
			platform_params,
			contract_params,
			code,
			dex_root_address,
			wever_root,
			wallets_mapping
		);
		tvm.setcode(code);
		tvm.setCurrentCode(code);
		onCodeUpgrade(data);
	}

	function onCodeUpgrade(TvmCell data) private {
		tvm.rawReserve(EverduesGas.ACCOUNT_INITIAL_BALANCE, 2);
		tvm.resetStorage();
		uint32 old_version;
		TvmCell contract_params;
		TvmCell code;
		(
			root,
			old_version,
			current_version,
			type_id,
			platform_code,
			platform_params,
			contract_params,
			code
		) = abi.decode(
			data,
			(address, uint32, uint32, uint8, TvmCell, TvmCell, TvmCell, TvmCell)
		);
		if (old_version > 0 && contract_params.toSlice().empty()) {
			(
				,
				,
				,
				,
				,
				,
				,
				,
				dex_root_address,
				wever_root,
				wallets_mapping
			) = abi.decode(
				data,
				(
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
		} else if (old_version == 0) {
			(
				dex_root_address,
				wever_root, /*address tip3_to_ever_address*/
				,
				account_gas_threshold
			) = abi.decode(
				contract_params,
				(address, address, address, uint128)
			);
		}
		emit AccountDeployed(current_version);
	}
}
