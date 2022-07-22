pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "../../interfaces/IEverduesAccount.sol";
import "./EverduesAccountBase.sol";

contract EverduesAccount_V1 is IEverduesAccount, EverduesAccountBase {
	function upgrade(
		TvmCell code,
		uint32 version,
		TvmCell contract_params
	) external override onlyRoot {
		TvmCell wallets_mapping_cell = abi.encode(wallets_mapping);
		TvmCell data = abi.encode(
			root,
			current_version,
			version,
			type_id,
			platform_code,
			platform_params,
			contract_params,
			code,
			wallets_mapping_cell,
			dex_root_address,
			wever_root
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
			TvmCell wallets_mapping_cell;
			(
				,
				,
				,
				,
				,
				,
				,
				,
				wallets_mapping_cell,
				dex_root_address,
				wever_root
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
					TvmCell,
					address,
					address
				)
			);
			wallets_mapping = abi.decode(
				wallets_mapping_cell,
				(mapping(address => BalanceWalletStruct))
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
