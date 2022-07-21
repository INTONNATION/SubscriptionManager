pragma ton-solidity >=0.56.0;

import "./EverduesAccountStorage.sol";

import "../libraries/ContractTypes.sol";
import "../libraries/EverduesErrors.sol";

import "../interfaces/IEverduesAccount.sol";
import "../interfaces/IEverduesSubscription.sol";

abstract contract EverduesAccountSettings is EverduesAccountStorage {
	modifier onlyFeeProxy() {
		address fee_proxy_address = address(
			tvm.hash(
				_buildInitData(
					ContractTypes.FeeProxy,
					_buildPlatformParamsOwnerAddress(root)
				)
			)
		);
		require(
			msg.sender == fee_proxy_address,
			EverduesErrors.error_message_sender_is_not_dex_root
		);
		_;
	}

	modifier onlyRoot() {
		require(
			msg.sender == root,
			EverduesErrors.error_message_sender_is_not_owner
		);
		_;
	}

	modifier onlyOwner() {
		require(
			msg.pubkey() == tvm.pubkey(),
			EverduesErrors.error_message_sender_is_not_owner
		);
		tvm.accept();
		_;
	}

	modifier onlyDexRoot() {
		require(
			msg.sender == dex_root_address,
			EverduesErrors.error_message_sender_is_not_dex_root
		);
		_;
	}

	modifier onlyDexPair(address sender) {
		for (
			(address tokenRoot, BalanceWalletStruct tokenBalance):
			wallets_mapping
		) {
			if (tokenBalance.dex_ever_pair_address == sender) {
				_;
			}
		}
		revert(EverduesErrors.error_message_sender_is_not_dex_pair);
	}

	function destroyAccount(address send_gas_to)
		external
		onlyOwner /*onlyRoot*/
	{
		selfdestruct(send_gas_to);
	}
}
