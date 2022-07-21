pragma ton-solidity >=0.56.0;

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
    
}