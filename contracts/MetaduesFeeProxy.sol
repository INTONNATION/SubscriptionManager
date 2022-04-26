pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/MetaduesErrors.sol";
import "libraries/PlatformTypes.sol";
import "libraries/MsgFlag.sol";
import "libraries/MetaduesGas.sol";
import "libraries/DexOperationTypes.sol";
import "./interfaces/IDexRoot.sol";
import "./Platform.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenWallet.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenRoot.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/TIP3TokenWallet.sol";

contract MetaduesFeeProxy {
	address public root;
	TvmCell platform_code;
	TvmCell platform_params;
	address mtds_root_address;
	address sync_balance_currency_root; // mutex
	address dex_root_address;
	uint32 current_version;
	uint8 type_id;

	struct balance_wallet_struct {
		address wallet;
		uint128 balance;
	}

	mapping(address => balance_wallet_struct) public wallets_mapping;
	// token_root -> send_gas_to
	mapping(address => address) _tmp_deploying_wallets;

	constructor() public {
		revert();
	}

	modifier onlyRoot() {
		require(
			msg.sender == root,
			MetaduesErrors.error_message_sender_is_not_root
		);
		_;
	}

	modifier onlyDexRoot() {
		require(
			msg.sender == dex_root_address,
			MetaduesErrors.error_message_sender_is_not_dex_root
		);
		_;
	}

	modifier onlyCurrencyRoot() {
		require(
			msg.sender == sync_balance_currency_root,
			MetaduesErrors.error_message_sender_is_not_currency_root
		);
		_;
	}

	function onAcceptTokensTransfer(
		address tokenRoot,
		uint128 amount,
		address sender,
		address senderWallet,
		address remainingGasTo,
		TvmCell payload
	) external {
		optional(balance_wallet_struct) current_balance_struct = wallets_mapping
			.fetch(tokenRoot);
		if (current_balance_struct.hasValue()) {
			balance_wallet_struct current_balance_key = current_balance_struct
				.get();
			current_balance_key.balance += amount;
			wallets_mapping[tokenRoot] = current_balance_key;
		}
		remainingGasTo.transfer({
			value: 0,
			flag: MsgFlag.REMAINING_GAS + MsgFlag.IGNORE_ERRORS
		});
	}

	function swapRevenueToMTDS(address currency_root, address send_gas_to)
		external
		onlyRoot
	{
		tvm.rawReserve(
			math.max(
				MetaduesGas.FEE_PROXY_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		require(
			sync_balance_currency_root == address(0),
			MetaduesErrors.error_address_is_empty
		); // mutex
		sync_balance_currency_root = currency_root; // critical area
		_tmp_deploying_wallets[currency_root] = send_gas_to;
		optional(
			balance_wallet_struct
		) current_balance_struct_opt = wallets_mapping.fetch(currency_root);
		if (current_balance_struct_opt.hasValue()) {
			balance_wallet_struct current_balance_struct = current_balance_struct_opt
					.get();
			if (current_balance_struct.balance > 0) {
				IDexRoot(dex_root_address).getExpectedPairAddress{
					value: 0,
					flag: MsgFlag.ALL_NOT_RESERVED,
					bounce: false,
					callback: MetaduesFeeProxy.onGetExpectedPairAddress
				}(mtds_root_address, currency_root);
			}
		} else {
			send_gas_to.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
		}
	}

	function onGetExpectedPairAddress(address dex_pair_address)
		external
		onlyDexRoot
	{
		tvm.rawReserve(
			math.max(
				MetaduesGas.FEE_PROXY_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		require(
			msg.value > MetaduesGas.TRANSFER_MIN_VALUE,
			MetaduesErrors.error_message_low_value
		);
		require(
			_tmp_deploying_wallets.exists(msg.sender) &&
				!wallets_mapping.exists(msg.sender),
			MetaduesErrors.error_wallet_not_exist
		);
		TvmBuilder builder;
		builder.store(DexOperationTypes.EXCHANGE);
		builder.store(uint64(0));
		builder.store(uint128(0));
		builder.store(uint128(0));

		optional(balance_wallet_struct) current_balance_struct = wallets_mapping
			.fetch(sync_balance_currency_root);
		balance_wallet_struct current_balance_key = current_balance_struct
			.get();
		address send_gas_to = _tmp_deploying_wallets[msg.sender];
		ITokenWallet(current_balance_key.wallet).transfer{
			value: MetaduesGas.TRANSFER_MIN_VALUE,
			flag: MsgFlag.SENDER_PAYS_FEES
		}(
			current_balance_key.balance, // amount
			dex_pair_address, // recipient
			0, // deployWalletValue
			send_gas_to, // remainingGasTo
			true, // notify
			builder.toCell() // payload
		);
		current_balance_key.balance = 0;
		wallets_mapping[sync_balance_currency_root] = current_balance_key;
		sync_balance_currency_root = address(0); // free mutex
		send_gas_to.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	function syncBalance(address currency_root, address send_gas_to)
		external
		onlyRoot
	{
		require(
			sync_balance_currency_root == address(0),
			MetaduesErrors.error_address_is_empty
		); // mutex
		_tmp_deploying_wallets[currency_root] = send_gas_to;
		tvm.rawReserve(
			math.max(
				MetaduesGas.FEE_PROXY_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		sync_balance_currency_root = currency_root; // critical area
		optional(balance_wallet_struct) current_balance_struct = wallets_mapping
			.fetch(currency_root);
		balance_wallet_struct current_balance_key = current_balance_struct
			.get();
		address proxy_wallet = current_balance_key.wallet;
		TIP3TokenWallet(proxy_wallet).balance{
			value: MsgFlag.SENDER_PAYS_FEES,
			flag: MsgFlag.ALL_NOT_RESERVED,
			bounce: false,
			callback: MetaduesFeeProxy.onBalanceOf
		}();
	}

	function setMTDSRootAddress(address mtds_root, address send_gas_to)
		external
		onlyRoot
	{
		tvm.rawReserve(MetaduesGas.FEE_PROXY_INITIAL_BALANCE, 2);
		mtds_root_address = mtds_root;
		send_gas_to.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	function setDexRootAddress(address dex_root, address send_gas_to)
		external
		onlyRoot
	{
		tvm.rawReserve(MetaduesGas.FEE_PROXY_INITIAL_BALANCE, 2);
		dex_root_address = dex_root;
		send_gas_to.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	function onBalanceOf(uint128 balance_) external onlyCurrencyRoot {
		require(
			_tmp_deploying_wallets.exists(msg.sender) &&
				!wallets_mapping.exists(msg.sender),
			MetaduesErrors.error_wallet_not_exist
		);
		tvm.rawReserve(MetaduesGas.FEE_PROXY_INITIAL_BALANCE, 2);
		address send_gas_to = _tmp_deploying_wallets[msg.sender];
		uint128 balance_wallet = balance_;
		optional(balance_wallet_struct) current_balance_struct = wallets_mapping
			.fetch(sync_balance_currency_root);
		balance_wallet_struct current_balance_key = current_balance_struct
			.get();
		current_balance_key.balance = balance_wallet;
		wallets_mapping[sync_balance_currency_root] = current_balance_key;
		sync_balance_currency_root = address(0); // free mutex
		send_gas_to.transfer({
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}

	function transferRevenue(address revenue_to, address send_gas_to)
		external
		onlyRoot
	{
		require(
			msg.value >= (MetaduesGas.TRANSFER_MIN_VALUE),
			MetaduesErrors.error_message_low_value
		);
		tvm.rawReserve(
			math.max(
				MetaduesGas.FEE_PROXY_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		optional(
			balance_wallet_struct
		) currency_root_wallet_opt = wallets_mapping.fetch(mtds_root_address);
		if (!currency_root_wallet_opt.hasValue()) {
			balance_wallet_struct currency_root_wallet_struct = currency_root_wallet_opt
					.get();
			TvmCell payload;
			ITokenWallet(currency_root_wallet_struct.wallet).transfer{
				value: 0,
				flag: MsgFlag.ALL_NOT_RESERVED
			}(
				currency_root_wallet_struct.balance,
				revenue_to,
				0,
				send_gas_to,
				true,
				payload
			);
		}
	}

	function onCodeUpgrade(TvmCell upgrade_data) private {
		TvmSlice s = upgrade_data.toSlice();
		(
			address root_,
			address send_gas_to,
			uint32 old_version,
			uint32 version,
			uint8 type_id_
		) = s.decode(address, address, uint32, uint32, uint8);
		if (old_version == 0) {
			tvm.resetStorage();
		}
		root = root_;
		platform_code = s.loadRef();
		platform_params = s.loadRef();
		TvmSlice contract_params = s.loadRefAsSlice();
		TvmCell current_code = s.loadRef();
		current_version = version;
		type_id = type_id_;
		address[] supportedCurrencies = contract_params.decode(address[]);
		if (old_version != 0) {
			TvmSlice old_data = s.loadRefAsSlice();
			mapping(address => balance_wallet_struct) wallets_mapping_ = old_data
					.decode(mapping(address => balance_wallet_struct));
			wallets_mapping = wallets_mapping_;
		}
		updateSupportedCurrencies(supportedCurrencies, send_gas_to);
	}

	function upgrade(
		TvmCell code,
		uint32 version,
		address send_gas_to
	) external onlyRoot {
		require(
			msg.value > MetaduesGas.UPGRADE_FEE_PROXY_MIN_VALUE,
			MetaduesErrors.error_message_low_value
		);

		tvm.rawReserve(MetaduesGas.FEE_PROXY_INITIAL_BALANCE, 2);

		TvmBuilder builder;
		TvmBuilder upgrade_params;
		builder.store(root);
		builder.store(send_gas_to);
		builder.store(current_version);
		builder.store(version);
		builder.store(type_id);
		builder.store(platform_code);
		builder.store(platform_params);
		builder.store(code);
		upgrade_params.store(wallets_mapping);
		builder.store(upgrade_params.toCell());
		tvm.setcode(code);
		tvm.setCurrentCode(code);
		onCodeUpgrade(builder.toCell());
	}

	function updateSupportedCurrencies(
		address[] currencies,
		address send_gas_to
	) private inline {
		for (address currency_root: currencies) {
			// iteration over the array
			optional(
				balance_wallet_struct
			) currency_root_wallet_opt = wallets_mapping.fetch(currency_root);
			if (!currency_root_wallet_opt.hasValue()) {
				_tmp_deploying_wallets[currency_root] = send_gas_to;
				ITokenRoot(currency_root).deployWallet{
					value: MetaduesGas.DEPLOY_EMPTY_WALLET_VALUE,
					bounce: false,
					flag: MsgFlag.SENDER_PAYS_FEES,
					callback: MetaduesFeeProxy.onDeployWallet
				}(address(this), MetaduesGas.DEPLOY_EMPTY_WALLET_GRAMS);
			}
		}
		send_gas_to.transfer({
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}

	function setSupportedCurrencies(
		TvmCell fee_proxy_contract_params,
		address send_gas_to
	) external onlyRoot {
		address[] currencies = fee_proxy_contract_params.toSlice().decode(
			address[]
		);
		require(
			msg.value >
				(MetaduesGas.DEPLOY_EMPTY_WALLET_VALUE * currencies.length),
			MetaduesErrors.error_message_low_value
		);
		tvm.rawReserve(
			math.max(
				MetaduesGas.FEE_PROXY_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		for (address currency_root: currencies) {
			// iteration over the array
			optional(
				balance_wallet_struct
			) currency_root_wallet_opt = wallets_mapping.fetch(currency_root);
			if (!currency_root_wallet_opt.hasValue()) {
				_tmp_deploying_wallets[currency_root] = send_gas_to;
				ITokenRoot(currency_root).deployWallet{
					value: MetaduesGas.DEPLOY_EMPTY_WALLET_VALUE,
					bounce: false,
					flag: MsgFlag.SENDER_PAYS_FEES,
					callback: MetaduesFeeProxy.onDeployWallet
				}(address(this), MetaduesGas.DEPLOY_EMPTY_WALLET_GRAMS);
			}
		}
		send_gas_to.transfer({
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}

	function onDeployWallet(address wallet_address) external {
		require(
			_tmp_deploying_wallets.exists(msg.sender) &&
				!wallets_mapping.exists(msg.sender),
			MetaduesErrors.error_wallet_not_exist
		);
		tvm.rawReserve(
			math.max(
				MetaduesGas.FEE_PROXY_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		address send_gas_to = _tmp_deploying_wallets[msg.sender];
		wallets_mapping[msg.sender].wallet = wallet_address;
		wallets_mapping[msg.sender].balance = 0;
		send_gas_to.transfer({
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}
}
