pragma ton-solidity >=0.56.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./EverduesFeeProxySettings.sol";

import "../../interfaces/IEverduesAccount.sol";
import "../../interfaces/IEverduesSubscription.sol";
import "../../interfaces/IDexRoot.sol";

import "../../libraries/DexOperationTypes.sol";
import "../../../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenWallet.sol";
import "../../../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenRoot.sol";

abstract contract EverduesFeeProxyBase is EverduesFeeProxySettings {
	constructor() public {
		revert();
	}

	function onAcceptTokensTransfer(
		address tokenRoot,
		uint128 amount,
		address /*sender*/,
		address /*senderWallet*/,
		address remainingGasTo,
		TvmCell /*payload*/
	) external {
		optional(BalanceWalletStruct) current_balance_struct = wallets_mapping
			.fetch(tokenRoot);
		if (current_balance_struct.hasValue()) {
			BalanceWalletStruct current_balance_key = current_balance_struct
				.get();
			require(
				msg.sender == current_balance_key.wallet,
				EverduesErrors.error_message_sender_is_not_feeproxy_wallet
			);
			current_balance_key.balance += amount;
			wallets_mapping[tokenRoot] = current_balance_key;
		}
		if (remainingGasTo != address(this)) {
			remainingGasTo.transfer({
				value: 0,
				bounce: false,
				flag: MsgFlag.REMAINING_GAS + MsgFlag.IGNORE_ERRORS
			});
		}
	}

	function swapRevenueToDUES(address currency_root, address send_gas_to)
		external
		onlyRoot
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.FEE_PROXY_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		require(
			_tmp_swap_currency_root_ == address(0),
			EverduesErrors.error_address_is_empty
		); // mutex
		_tmp_swap_currency_root_ = currency_root; // critical area
		optional(
			BalanceWalletStruct
		) current_balance_struct_opt = wallets_mapping.fetch(currency_root);
		if (current_balance_struct_opt.hasValue()) {
			BalanceWalletStruct current_balance_struct = current_balance_struct_opt
					.get();
			if (current_balance_struct.balance > 0) {
				IDexRoot(dex_root_address).getExpectedPairAddress{
					value: 0,
					flag: MsgFlag.ALL_NOT_RESERVED,
					bounce: false,
					callback: EverduesFeeProxyBase.onGetExpectedPairAddress
				}(dues_root_address, currency_root);
			}
		} else {
			send_gas_to.transfer({
				value: 0,
				bounce: false,
				flag: MsgFlag.ALL_NOT_RESERVED
			});
		}
	}

	function onGetExpectedPairAddress(address dex_pair_address)
		external
		onlyDexRoot
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.FEE_PROXY_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		require(
			wallets_mapping.exists(_tmp_swap_currency_root_),
			EverduesErrors.error_wallet_not_exist
		);
		TvmBuilder builder;
		builder.store(DexOperationTypes.EXCHANGE);
		builder.store(uint64(0));
		builder.store(uint128(0));
		builder.store(uint128(0));

		optional(BalanceWalletStruct) current_balance_struct = wallets_mapping
			.fetch(_tmp_swap_currency_root_);
		BalanceWalletStruct current_balance_key = current_balance_struct.get();
		ITokenWallet(current_balance_key.wallet).transfer{
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(
			current_balance_key.balance, // amount
			dex_pair_address, // recipient
			0, // deployWalletValue
			address(this), // remainingGasTo
			true, // notify
			builder.toCell() // payload
		);
		current_balance_key.balance = 0;
		wallets_mapping[_tmp_swap_currency_root_] = current_balance_key;
		_tmp_swap_currency_root_ = address(0); // free mutex
	}

	function executePaySubscription(
		address account_address,
		address service_address,
		uint128 value,
		address currency_root,
		address subscription_wallet,
		uint128 account_gas_balance,
		bool subscription_deploy,
		bool external_subscription,
		uint128 additional_gas
	) external view onlySubscriptionContract(account_address, service_address) {
		uint128 gas_;
		// TODO: add check that this TIP3 supported
		// TODO: restrict to allow EverDues wrapped TIP3 only if external_subscription - True
		if (account_gas_balance < account_threshold) {
			gas_ =
				account_threshold -
				account_gas_balance +
				additional_gas +
				1 ever;
		} else {
			gas_ = additional_gas + 1 ever;
		}
		IEverduesAccount(account_address).paySubscription{
			value: gas_,
			bounce: true,
			flag: 0
		}(
			value,
			currency_root,
			subscription_wallet,
			service_address,
			subscription_deploy,
			external_subscription,
			recurring_payment_gas,
			additional_gas
		);
	}

	function swapTIP3ToEver(
		uint128 amount,
		address currency_root,
		address dex_ever_pair_address,
		address tip3_to_ever_address
	) external onlyRoot {
		tvm.rawReserve(
			math.max(
				EverduesGas.FEE_PROXY_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		// SWAP_TIP3_TO_EVER_MIN_VALUE
		optional(BalanceWalletStruct) current_balance_struct = wallets_mapping
			.fetch(currency_root);
		BalanceWalletStruct current_balance_key = current_balance_struct.get();
		TvmBuilder payload;
		payload.store(uint8(2));
		payload.store(uint64(0));
		payload.store(dex_ever_pair_address);
		payload.store(uint128(0));
		uint128 balance_after_pay = current_balance_key.balance - amount;
		current_balance_key.balance = balance_after_pay;
		wallets_mapping[currency_root] = current_balance_key;
		ITokenWallet(current_balance_key.wallet).transfer{
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(
			amount,
			tip3_to_ever_address,
			0,
			address(this),
			true,
			payload.toCell()
		);
	}

	function syncBalance(address currency_root, address send_gas_to)
		external
		onlyRoot
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.FEE_PROXY_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		optional(BalanceWalletStruct) current_balance_struct = wallets_mapping
			.fetch(currency_root);
		BalanceWalletStruct current_balance_key = current_balance_struct.get();
		address proxy_wallet = current_balance_key.wallet;
		// currency root to struct
		SyncWalletBalanceStruct _tmp_sync;
		_tmp_sync.send_gas_to = send_gas_to;
		_tmp_sync.currency_root = currency_root;
		_tmp_sync_wallets[proxy_wallet] = _tmp_sync;
		TIP3TokenWallet(proxy_wallet).balance{
			value: MsgFlag.SENDER_PAYS_FEES,
			flag: MsgFlag.ALL_NOT_RESERVED,
			bounce: false,
			callback: EverduesFeeProxyBase.onBalanceOf
		}();
	}

	function onBalanceOf(uint128 balance_) external {
		require(
			_tmp_sync_wallets.exists(msg.sender),
			EverduesErrors.error_wallet_not_exist
		);
		tvm.rawReserve(
			math.max(
				EverduesGas.FEE_PROXY_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		SyncWalletBalanceStruct _tmp_sync = _tmp_sync_wallets[msg.sender];
		optional(BalanceWalletStruct) current_balance_struct = wallets_mapping
			.fetch(_tmp_sync.currency_root);
		BalanceWalletStruct current_balance_key = current_balance_struct.get();
		current_balance_key.balance = balance_;
		wallets_mapping[_tmp_sync.currency_root] = current_balance_key;
		_tmp_sync.send_gas_to.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
		delete _tmp_sync_wallets[msg.sender];
	}

	function transferRevenue(address revenue_to, address send_gas_to)
		external
		onlyRoot
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.FEE_PROXY_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		optional(BalanceWalletStruct) currency_root_wallet_opt = wallets_mapping
			.fetch(dues_root_address);
		if (currency_root_wallet_opt.hasValue()) {
			BalanceWalletStruct currency_root_wallet_struct = currency_root_wallet_opt
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
			currency_root_wallet_struct.balance = 0;
			wallets_mapping[dues_root_address] = currency_root_wallet_struct;
		}
	}

	function setSupportedCurrencies(address[] currencies, address send_gas_to)
		internal
		inline
	{
		for (address currency_root: currencies) {
			// iteration over the array
			optional(
				BalanceWalletStruct
			) currency_root_wallet_opt = wallets_mapping.fetch(currency_root);
			if (!currency_root_wallet_opt.hasValue()) {
				_tmp_deploying_wallets[currency_root] = send_gas_to;
				ITokenRoot(currency_root).deployWallet{
					value: EverduesGas.DEPLOY_EMPTY_WALLET_VALUE,
					bounce: false,
					flag: MsgFlag.SENDER_PAYS_FEES,
					callback: EverduesFeeProxyBase.onDeployWallet
				}(address(this), EverduesGas.DEPLOY_EMPTY_WALLET_GRAMS);
			}
		}
		send_gas_to.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}

	function updateSupportedCurrencies(
		TvmCell fee_proxy_contract_params,
		address send_gas_to
	) external onlyRoot {
		address[] currencies = fee_proxy_contract_params.toSlice().decode(
			address[]
		);
		require(
			msg.value >
				(EverduesGas.DEPLOY_EMPTY_WALLET_VALUE * currencies.length),
			EverduesErrors.error_message_low_value
		);
		tvm.rawReserve(
			math.max(
				EverduesGas.FEE_PROXY_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		for (address currency_root: currencies) {
			// iteration over the array
			optional(
				BalanceWalletStruct
			) currency_root_wallet_opt = wallets_mapping.fetch(currency_root);
			if (!currency_root_wallet_opt.hasValue()) {
				_tmp_deploying_wallets[currency_root] = send_gas_to;
				ITokenRoot(currency_root).deployWallet{
					value: EverduesGas.DEPLOY_EMPTY_WALLET_VALUE,
					bounce: false,
					flag: MsgFlag.SENDER_PAYS_FEES,
					callback: EverduesFeeProxyBase.onDeployWallet
				}(address(this), EverduesGas.DEPLOY_EMPTY_WALLET_GRAMS);
			}
		}
		send_gas_to.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}

	function onDeployWallet(address wallet_address) external {
		require(
			_tmp_deploying_wallets.exists(msg.sender) &&
				!wallets_mapping.exists(msg.sender),
			EverduesErrors.error_wallet_not_exist
		);
		tvm.rawReserve(
			math.max(
				EverduesGas.FEE_PROXY_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		address send_gas_to = _tmp_deploying_wallets[msg.sender];
		wallets_mapping[msg.sender].wallet = wallet_address;
		wallets_mapping[msg.sender].balance = 0;
		send_gas_to.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
		delete _tmp_deploying_wallets[msg.sender];
	}
}
