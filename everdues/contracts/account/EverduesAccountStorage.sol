pragma ton-solidity >=0.56.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../Platform.sol";

abstract contract EverduesAccountStorage {
	uint32 current_version;
	uint8 type_id;
	address root;
	address dex_root_address;
	address wever_root;
	TvmCell platform_code;
	TvmCell platform_params;
	uint128 account_gas_threshold;
	uint256 public abi_hash;

	struct BalanceWalletStruct {
		address wallet;
		uint128 balance;
		address dex_ever_pair_address;
	}

	struct GetDexPairOperation {
		address currency_root;
		address send_gas_to;
	}

	struct SubscriptionOperation {
		address currency_root;
		uint128 value;
		address subscription_wallet;
		uint128 pay_subscription_gas;
		address subscription_contract;
		uint128 gas_value;
		bool subscription_deploy;
		uint8 service_gas_compenstation;
		uint8 subscription_gas_compenstation;
		address service_address;
	}

	struct DepositTokens {
		address wallet;
		uint128 amount;
	}

	mapping(address => BalanceWalletStruct) public wallets_mapping;
	mapping(address => address) _tmp_sync_balance;
	mapping(uint64 => GetDexPairOperation) _tmp_get_pairs;
	mapping(uint64 => SubscriptionOperation) _tmp_subscription_operations;
	mapping(address => DepositTokens) tmp_deposit_tokens;

	function _buildSubscriptionParams(
		address subscription_owner,
		address service_address
	) internal inline pure returns (TvmCell) {
		TvmBuilder builder;
		builder.store(subscription_owner);
		builder.store(service_address);
		return builder.toCell();
	}

	function _buildPlatformParamsOwnerAddress(address account_owner)
		internal
		inline
		pure
		returns (TvmCell)
	{
		TvmBuilder builder;
		builder.store(account_owner);
		return builder.toCell();
	}

	function _buildInitData(uint8 type_id_, TvmCell params)
		internal
		inline
		view
		returns (TvmCell)
	{
		return
			tvm.buildStateInit({
				contr: Platform,
				varInit: {
					root: root,
					type_id: type_id_,
					platform_params: params
				},
				pubkey: 0,
				code: platform_code
			});
	}
}
