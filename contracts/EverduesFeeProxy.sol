pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/EverduesErrors.sol";
import "libraries/PlatformTypes.sol";
import "libraries/MsgFlag.sol";
import "libraries/EverduesGas.sol";
import "libraries/DexOperationTypes.sol";
import "./interfaces/IDexRoot.sol";
import "./interfaces/IEverduesAccount.sol";
import "./interfaces/IEverduesSubscription.sol";
import "./Platform.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenWallet.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenRoot.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/TIP3TokenWallet.sol";

contract EverduesFeeProxy {
	address public root;
	address public mtds_root_address;
	address public dex_root_address;
	uint32 public current_version;
	uint128 public account_threshold = 10 ever;
	address swap_currency_root;
	TvmCell platform_code;
	TvmCell platform_params;
	uint8 type_id;

	struct balance_wallet_struct {
		address wallet;
		uint128 balance;
		address dex_ever_pair_address;
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
			EverduesErrors.error_message_sender_is_not_root
		);
		_;
	}

	modifier onlyDexRoot() {
		require(
			msg.sender == dex_root_address,
			EverduesErrors.error_message_sender_is_not_dex_root
		);
		_;
	}

	modifier onlySubscriptionContract(
		address account_address,
		address service_address
	) {
		address subscription_contract_address = address(
			tvm.hash(
				_buildInitData(
					PlatformTypes.Subscription,
					_buildSubscriptionParams(account_address, service_address)
				)
			)
		);
		require(
			msg.sender == subscription_contract_address,
			EverduesErrors.error_message_sender_is_not_my_subscription
		);
		_;
	}

	function onAcceptTokensTransfer(
		address tokenRoot,
		uint128 amount,
		address, /*sender*/
		address, /*senderWallet*/
		address remainingGasTo,
		TvmCell /*payload*/
	) external {
		optional(balance_wallet_struct) current_balance_struct = wallets_mapping
			.fetch(tokenRoot);
		if (current_balance_struct.hasValue()) {
			balance_wallet_struct current_balance_key = current_balance_struct
				.get();
			require(
				msg.sender == current_balance_key.wallet,
				EverduesErrors.error_message_sender_is_not_feeproxy_wallet
			);
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
				EverduesGas.FEE_PROXY_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		require(
			swap_currency_root == address(0),
			EverduesErrors.error_address_is_empty
		); // mutex
		swap_currency_root = currency_root; // critical area
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
					callback: EverduesFeeProxy.onGetExpectedPairAddress
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
				EverduesGas.FEE_PROXY_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		require(
			msg.value > EverduesGas.TRANSFER_MIN_VALUE,
			EverduesErrors.error_message_low_value
		);
		require(
			_tmp_deploying_wallets.exists(swap_currency_root) &&
				!wallets_mapping.exists(swap_currency_root),
			EverduesErrors.error_wallet_not_exist
		);
		TvmBuilder builder;
		builder.store(DexOperationTypes.EXCHANGE);
		builder.store(uint64(0));
		builder.store(uint128(0));
		builder.store(uint128(0));

		optional(balance_wallet_struct) current_balance_struct = wallets_mapping
			.fetch(swap_currency_root);
		balance_wallet_struct current_balance_key = current_balance_struct
			.get();
		address send_gas_to = _tmp_deploying_wallets[swap_currency_root];
		ITokenWallet(current_balance_key.wallet).transfer{
			value: EverduesGas.TRANSFER_MIN_VALUE,
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
		wallets_mapping[swap_currency_root] = current_balance_key;
		swap_currency_root = address(0); // free mutex
		send_gas_to.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	function setAccountGasThreshold(
		uint128 account_threshold_,
		address send_gas_to
	) external onlyRoot {
		tvm.rawReserve(
			math.max(
				EverduesGas.FEE_PROXY_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		account_threshold = account_threshold_;
		send_gas_to.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	function executePaySubscription(
		address account_address,
		address service_address,
		uint128 value,
		address currency_root,
		address subscription_wallet,
		uint128 account_gas_balance,
		uint128 additional_gas
	) external view onlySubscriptionContract(account_address, service_address) {
		uint128 gas_;
		if (account_gas_balance < account_threshold) {
			gas_ =
				account_threshold -
				account_gas_balance +
				additional_gas +
				0.5 ever;
		} else {
			gas_ = additional_gas + 0.5 ever;
		}
		IEverduesAccount(account_address).paySubscription{
			value: gas_,
			bounce: true,
			flag: 0
		}(value, currency_root, subscription_wallet, additional_gas);
		IEverduesSubscription(msg.sender).replenishGas{
			value: 1 ever,
			bounce: true,
			flag: 0
		}();
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
		optional(balance_wallet_struct) current_balance_struct = wallets_mapping
			.fetch(currency_root);
		balance_wallet_struct current_balance_key = current_balance_struct
			.get();
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
		}(amount, tip3_to_ever_address, 0, root, true, payload.toCell());
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
		_tmp_deploying_wallets[currency_root] = send_gas_to;
		optional(balance_wallet_struct) current_balance_struct = wallets_mapping
			.fetch(currency_root);
		balance_wallet_struct current_balance_key = current_balance_struct
			.get();
		address proxy_wallet = current_balance_key.wallet;
		TIP3TokenWallet(proxy_wallet).balance{
			value: MsgFlag.SENDER_PAYS_FEES,
			flag: MsgFlag.ALL_NOT_RESERVED,
			bounce: false,
			callback: EverduesFeeProxy.onBalanceOf
		}();
	}

	function setMTDSRootAddress(address mtds_root, address send_gas_to)
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
		mtds_root_address = mtds_root;
		send_gas_to.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	function setDexRootAddress(address dex_root, address send_gas_to)
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
		dex_root_address = dex_root;
		send_gas_to.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	function onBalanceOf(uint128 balance_) external {
		require(
			_tmp_deploying_wallets.exists(msg.sender),
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
		uint128 balance_wallet = balance_;
		optional(balance_wallet_struct) current_balance_struct = wallets_mapping
			.fetch(msg.sender);
		balance_wallet_struct current_balance_key = current_balance_struct
			.get();
		current_balance_key.balance = balance_wallet;
		wallets_mapping[msg.sender] = current_balance_key;
		send_gas_to.transfer({
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}

	function transferRevenue(address revenue_to, address send_gas_to)
		external
		view
		onlyRoot
	{
		require(
			msg.value >= (EverduesGas.TRANSFER_MIN_VALUE),
			EverduesErrors.error_message_low_value
		);
		tvm.rawReserve(
			math.max(
				EverduesGas.FEE_PROXY_INITIAL_BALANCE,
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

	function upgrade(
		TvmCell code,
		uint32 version,
		address send_gas_to,
		TvmCell contract_params
	) external onlyRoot {
		tvm.rawReserve(EverduesGas.FEE_PROXY_INITIAL_BALANCE, 2);
		TvmCell data = abi.encode(
			root,
			send_gas_to,
			current_version,
			version,
			type_id,
			platform_code,
			platform_params,
			contract_params,
			code,
			mtds_root_address,
			dex_root_address,
			wallets_mapping
		);
		tvm.setcode(code);
		tvm.setCurrentCode(code);
		onCodeUpgrade(data);
	}

	function onCodeUpgrade(TvmCell upgrade_data) private {
		(
			address root_,
			address send_gas_to,
			uint32 old_version,
			uint32 version,
			uint8 type_id_,
			TvmCell platform_code_,
			TvmCell platform_params_,
			TvmCell contract_params, /*TvmCell code*/

		) = abi.decode(
				upgrade_data,
				(
					address,
					address,
					uint32,
					uint32,
					uint8,
					TvmCell,
					TvmCell,
					TvmCell,
					TvmCell
				)
			);
		tvm.resetStorage();
		root = root_;
		current_version = version;
		platform_code = platform_code_;
		platform_params = platform_params_;
		type_id = type_id_;
		if (old_version == 0) {
			address[] supportedCurrencies = abi.decode(
				contract_params,
				(address[])
			);
			updateSupportedCurrencies(supportedCurrencies, send_gas_to);
		} else if (old_version > 0) {
			(
				,
				,
				,
				,
				,
				,
				,
				,
				,
				address mtds_root_address_,
				address dex_root_address_,
				mapping(address => balance_wallet_struct) wallets_mapping_
			) = abi.decode(
					upgrade_data,
					(
						address,
						address,
						uint32,
						uint32,
						uint8,
						TvmCell,
						TvmCell,
						TvmCell,
						TvmCell,
						address,
						address,
						mapping(address => balance_wallet_struct)
					)
				);
			mtds_root_address = mtds_root_address_;
			dex_root_address = dex_root_address_;
			wallets_mapping = wallets_mapping_;
			send_gas_to.transfer({
				value: 0,
				flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
			});
		}
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
					value: EverduesGas.DEPLOY_EMPTY_WALLET_VALUE,
					bounce: false,
					flag: MsgFlag.SENDER_PAYS_FEES,
					callback: EverduesFeeProxy.onDeployWallet
				}(address(this), EverduesGas.DEPLOY_EMPTY_WALLET_GRAMS);
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
				balance_wallet_struct
			) currency_root_wallet_opt = wallets_mapping.fetch(currency_root);
			if (!currency_root_wallet_opt.hasValue()) {
				_tmp_deploying_wallets[currency_root] = send_gas_to;
				ITokenRoot(currency_root).deployWallet{
					value: EverduesGas.DEPLOY_EMPTY_WALLET_VALUE,
					bounce: false,
					flag: MsgFlag.SENDER_PAYS_FEES,
					callback: EverduesFeeProxy.onDeployWallet
				}(address(this), EverduesGas.DEPLOY_EMPTY_WALLET_GRAMS);
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
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}

	function _buildSubscriptionParams(
		address subscription_owner,
		address service_address
	) private inline pure returns (TvmCell) {
		TvmBuilder builder;
		builder.store(subscription_owner);
		builder.store(service_address);
		return builder.toCell();
	}

	function _buildInitData(uint8 type_id_, TvmCell params)
		private
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
