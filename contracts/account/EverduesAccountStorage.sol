pragma ton-solidity >=0.56.0;
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

	struct BalanceWalletStruct {
		address wallet;
		uint128 balance;
		address dex_ever_pair_address;
	}

	struct GetDexPairOperation {
		address currency_root;
		address send_gas_to;
	}

	struct ExchangeOperation {
		address currency_root;
		uint128 value;
		address subscription_wallet;
		uint128 pay_subscription_gas;
		address subscription_contract;
	}

	struct DepositTokens {
		address wallet;
		uint128 amount;
	}

	mapping(address => BalanceWalletStruct) public wallets_mapping;
	mapping(address => address) _tmp_sync_balance;
	mapping(uint64 => GetDexPairOperation) _tmp_get_pairs;
	mapping(uint64 => ExchangeOperation) _tmp_exchange_operations;
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