pragma ton-solidity >=0.56.0;

abstract contract EverduesFeeProxyStorage {
	address public root;
	address public mtds_root_address;
	address public dex_root_address;
	uint32 public current_version;
	uint128 public account_threshold = 10 ever; // default value
	address _tmp_swap_currency_root_;
	TvmCell platform_code;
	TvmCell platform_params;
	uint8 type_id;

	struct BalanceWalletStruct {
		address wallet;
		uint128 balance;
		address dex_ever_pair_address;
	}

	mapping(address => BalanceWalletStruct) public wallets_mapping;
	// token_root -> send_gas_to
	mapping(address => address) _tmp_deploying_wallets;
}
