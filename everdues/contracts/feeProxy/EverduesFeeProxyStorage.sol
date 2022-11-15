pragma ton-solidity >=0.56.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../Platform.sol";

abstract contract EverduesFeeProxyStorage {
	address public root;
	address public dues_root_address;
	address public dex_root_address;
	uint32 public current_version;
	uint128 public account_threshold = 4 ever; // default value
	address _tmp_swap_currency_root_;
	TvmCell platform_code;
	TvmCell platform_params;
	uint8 type_id;
	uint128 public recurring_payment_gas;

	struct BalanceWalletStruct {
		address wallet;
		uint128 balance;
	}
	struct SyncWalletBalanceStruct {
		address send_gas_to;
		address currency_root;
	}

	mapping(address => BalanceWalletStruct) public wallets_mapping;
	// token_root -> send_gas_to
	mapping(address => address) _tmp_deploying_wallets;
	mapping(address => SyncWalletBalanceStruct) _tmp_sync_wallets;
	address cross_chain_token;

	function _buildSubscriptionParams(
		address subscription_owner,
		address service_address
	) internal inline pure returns (TvmCell) {
		TvmBuilder builder;
		builder.store(subscription_owner);
		builder.store(service_address);
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
