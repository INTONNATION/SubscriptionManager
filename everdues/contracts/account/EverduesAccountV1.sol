pragma ton-solidity >=0.56.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../../interfaces/IEverduesAccount.sol";
import "./EverduesAccountBase.sol";

contract EverduesAccount_V1 is IEverduesAccount, EverduesAccountBase {
	function upgrade(
		TvmCell code,
		uint32 version,
		address send_gas_to,
		TvmCell upgrade_params
	) external override onlyRoot {
		TvmCell contract_params = abi.encode(
			dex_root_address,
			wever_root,
			wallets_mapping,
			abi_hash,
			cross_chain_token,
			totalExternalEarned,
			totalPaid,
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

	function onCodeUpgrade(TvmCell data) private {
		tvm.rawReserve(EverduesGas.ACCOUNT_INITIAL_BALANCE, 2);
		tvm.resetStorage();
		uint32 old_version;
		address send_gas_to;
		TvmCell contract_params;
		TvmCell code;
		(
			root,
			send_gas_to,
			old_version,
			current_version,
			type_id,
			platform_code,
			platform_params,
			contract_params,
			code
		) = abi.decode(
			data,
			(address, address, uint32, uint32, uint8, TvmCell, TvmCell, TvmCell, TvmCell)
		);
		if (old_version > 0) {
			TvmCell upgrade_params;
			(
				dex_root_address,
				wever_root,
				wallets_mapping,
				abi_hash,
				cross_chain_token,	
				totalExternalEarned,
				totalPaid,
				upgrade_params
			) = abi.decode(
				contract_params,
				(
					address,
					address,
					mapping(address => BalanceWalletStruct),
					uint256,
					address,
					uint256,
					uint256,
					TvmCell
				)
			);
			if (!upgrade_params.toSlice().empty()) {
				// parse upgrade data
			}
		} else if (old_version == 0) {
			(
				dex_root_address,
				wever_root,
				//*address tip3_to_ever_address
				,
				account_gas_threshold,
				abi_hash,
				cross_chain_token
			) = abi.decode(
				contract_params,
				(address, address, address, uint128, uint256, address)
			); 
			pubkey = tvm.pubkey();
		}
		if (send_gas_to.value != 0) {
			send_gas_to.transfer({
				value: 0,
				flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
			});
		}
		emit AccountDeployed(current_version);
	}
}
