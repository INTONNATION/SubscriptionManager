pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "Platform.sol";
import "EverduesRoot.sol";
import "libraries/EverduesErrors.sol";
import "libraries/PlatformTypes.sol";
import "libraries/EverduesGas.sol";
import "libraries/MsgFlag.sol";
import "libraries/DexOperationTypes.sol";
import "interfaces/IEverduesRoot.sol";
import "interfaces/IEverduesAccount.sol";
import "interfaces/IEverduesSubscription.sol";
import "interfaces/IDexRoot.sol";
import "interfaces/IDexPair.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenWallet.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenRoot.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/TIP3TokenWallet.sol";

contract EverduesAccount is IEverduesAccount {
	address public root;
	address public dex_root_address;
	address public wever_root;
	TvmCell platform_code;
	TvmCell platform_params;
	address owner;
	uint32 current_version;
	uint8 type_id;

	struct balance_wallet_struct {
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

	struct DeployServiceOperation {
		TvmCell service_params;
		TvmCell identificator;
		uint128 additional_gas;
	}

	mapping(address => balance_wallet_struct) public wallets_mapping;
	mapping(address => address) public _tmp_sync_balance;
	mapping(uint64 => GetDexPairOperation) public _tmp_get_pairs;
	mapping(uint64 => ExchangeOperation) public _tmp_exchange_operations;
	mapping(uint64 => DeployServiceOperation)
		public _tmp_deploy_service_operations;

	constructor() public {
		revert();
	}

	modifier onlyRoot() {
		require(
			msg.sender == root,
			EverduesErrors.error_message_sender_is_not_my_owner
		);
		_;
	}

	modifier onlyOwner() {
		require(
			msg.pubkey() == tvm.pubkey(),
			EverduesErrors.error_message_sender_is_not_my_owner
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

	modifier onlyFeeProxy() {
		address fee_proxy_address = address(
			tvm.hash(
				_buildInitData(
					PlatformTypes.FeeProxy,
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

	onBounce(TvmSlice slice) external pure {
		// revert change to initial msg.sender in case of failure during deploy
		// TODO: after https://github.com/tonlabs/ton-labs-node/issues/140
		//uint32 functionId = slice.decode(uint32);
		// Start decoding the message. First 32 bits store the function id.
		uint32 functionId = slice.decode(uint32);

		// Api function tvm.functionId() allows to calculate function id by function name.
		if (functionId == tvm.functionId(TIP3TokenWallet.balance)) {
			emit BalanceSynced(uint128(0));
		}
	}

	function upgradeAccount(uint128 additional_gas) public view onlyOwner {
		IEverduesRoot(root).upgradeAccount{
			value: EverduesGas.UPGRADE_ACCOUNT_MIN_VALUE +
				additional_gas +
				EverduesGas.INIT_MESSAGE_VALUE,
			bounce: true,
			flag: 0
		}(tvm.pubkey());
	}

	function upgrade(
		TvmCell code,
		uint32 version,
		TvmCell contract_params
	) external onlyRoot {
		TvmCell data = abi.encode(
			root,
			current_version,
			version,
			type_id,
			platform_code,
			platform_params,
			contract_params,
			code,
			wallets_mapping,
			dex_root_address,
			wever_root
		);
		tvm.setcode(code);
		tvm.setCurrentCode(code);
		onCodeUpgrade(data);
	}

	function onCodeUpgrade(TvmCell data) private {
		tvm.rawReserve(EverduesGas.ACCOUNT_INITIAL_BALANCE, 2);
		(
			address root_,
			uint32 old_version,
			uint32 version,
			uint8 type_id_,
			TvmCell platform_code_,
			TvmCell platform_params_,
			TvmCell contract_params, /*TvmCell code*/

		) = abi.decode(
				data,
				(
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
		platform_code = platform_code_;
		platform_params = platform_params_;
		current_version = version;
		type_id = type_id_;
		if (old_version > 0 && contract_params.toSlice().empty()) {
			(
				,
				,
				,
				,
				,
				,
				,
				,
				mapping(address => balance_wallet_struct) wallets_mapping_,
				address dex_root_address_,
				address wever_root_
			) = abi.decode(
					data,
					(
						address,
						uint32,
						uint32,
						uint8,
						TvmCell,
						TvmCell,
						TvmCell,
						TvmCell,
						mapping(address => balance_wallet_struct),
						address,
						address
					)
				);
			wallets_mapping = wallets_mapping_;
			wever_root = wever_root_;
			dex_root_address = dex_root_address_;
		} else if (old_version == 0 || !contract_params.toSlice().empty()) {
			(dex_root_address, wever_root) = abi.decode(
				contract_params,
				(address, address)
			);
		}
		emit AccountDeployed(current_version);
	}

	function getNextPaymentStatus(
		address service_address,
		uint128 value,
		address currency_root
	) external responsible override returns (uint8, uint128) {
		tvm.rawReserve(
			math.max(
				EverduesGas.ACCOUNT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		address subsciption_addr = address(
			tvm.hash(
				_buildInitData(
					PlatformTypes.Subscription,
					_buildSubscriptionParams(address(this), service_address)
				)
			)
		);
		require(
			subsciption_addr == msg.sender,
			EverduesErrors.error_message_sender_is_not_my_subscription
		);
		optional(balance_wallet_struct) current_balance_struct = wallets_mapping
			.fetch(currency_root);
		if (current_balance_struct.hasValue()) {
			balance_wallet_struct current_balance_key_value = current_balance_struct
					.get();
			uint128 current_balance = current_balance_key_value.balance;
			if (value > current_balance) {
				return
					{value: 0, flag: MsgFlag.ALL_NOT_RESERVED} (
						1,
						address(this).balance
					);
			} else {
				return
					{value: 0, flag: MsgFlag.ALL_NOT_RESERVED} (
						0,
						address(this).balance
					);
			}
		}
	}

	function paySubscription(
		uint128 value,
		address currency_root,
		address subscription_wallet,
		uint128 additional_gas
	) external override onlyFeeProxy {
		optional(balance_wallet_struct) current_balance_struct = wallets_mapping
			.fetch(currency_root);
		if (current_balance_struct.hasValue()) {
			balance_wallet_struct current_balance_key_value = current_balance_struct
					.get();
			uint128 current_balance = current_balance_key_value.balance;
			if (value > current_balance) {
				revert(1111);
			} else {
				_tmp_exchange_operations[now] = ExchangeOperation(
					currency_root,
					value,
					subscription_wallet,
					additional_gas,
					msg.sender
				);
				IDexPair(current_balance_key_value.dex_ever_pair_address)
					.expectedSpendAmount{
					value: EverduesGas.TRANSFER_MIN_VALUE,
					bounce: true,
					flag: MsgFlag.SENDER_PAYS_FEES,
					callback: EverduesAccount.onExpectedExchange
				}(msg.value, wever_root);
			}
		}
	}

	function onExpectedExchange(
		uint128 expected_amount,
		uint128 /*expected_fee*/
	) public {
		TvmCell payload = abi.encode(expected_amount);
		optional(uint64, ExchangeOperation) keyOpt = _tmp_exchange_operations
			.min();
		if (keyOpt.hasValue()) {
			(uint64 call_id, ExchangeOperation last_operation) = keyOpt.get();
			call_id;
			optional(
				balance_wallet_struct
			) current_balance_struct = wallets_mapping.fetch(
					last_operation.currency_root
				);
			balance_wallet_struct current_balance_key = current_balance_struct
				.get();
			address account_wallet = current_balance_key.wallet;
			ITokenWallet(account_wallet).transferToWallet{
				value: EverduesGas.TRANSFER_MIN_VALUE *
					2 +
					last_operation.pay_subscription_gas,
				bounce: false,
				flag: MsgFlag.SENDER_PAYS_FEES
			}(
				last_operation.value,
				last_operation.subscription_wallet,
				address(this),
				true,
				payload
			);
			uint128 balance_after_pay = current_balance_key.balance -
				last_operation.value;
			current_balance_key.balance = balance_after_pay;
			wallets_mapping[last_operation.currency_root] = current_balance_key;
			_tmp_exchange_operations.delMin();
		}
	}

	function syncBalance(address currency_root, uint128 additional_gas)
		external
		onlyOwner
	{
		tvm.rawReserve(EverduesGas.ACCOUNT_INITIAL_BALANCE, 0);
		optional(balance_wallet_struct) current_balance_struct = wallets_mapping
			.fetch(currency_root);
		if (current_balance_struct.hasValue()) {
			balance_wallet_struct current_balance_key = current_balance_struct
				.get();
			address account_wallet = current_balance_key.wallet;
			_tmp_sync_balance[account_wallet] = currency_root;
			if (current_balance_key.dex_ever_pair_address == address(0)) {
				_tmp_get_pairs[now] = GetDexPairOperation(
					currency_root,
					address(this)
				);
				IDexRoot(dex_root_address).getExpectedPairAddress{
					value: EverduesGas.INIT_MESSAGE_VALUE,
					flag: 0,
					bounce: false,
					callback: EverduesAccount.onGetExpectedPairAddress
				}(wever_root, currency_root);
			}
			TIP3TokenWallet(account_wallet).balance{
				value: EverduesGas.TRANSFER_MIN_VALUE + additional_gas,
				bounce: true,
				flag: 0,
				callback: EverduesAccount.onBalanceOf
			}();
		} else {
			ITokenRoot(currency_root).walletOf{
				value: EverduesGas.TRANSFER_MIN_VALUE + additional_gas,
				bounce: true,
				flag: 0,
				callback: EverduesAccount.onWalletOf
			}(address(this));
		}
	}

	function onWalletOf(address account_wallet) external {
		tvm.rawReserve(
			math.max(
				EverduesGas.ACCOUNT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		_tmp_sync_balance[account_wallet] = msg.sender;
		TIP3TokenWallet(account_wallet).balance{
			value: 0,
			bounce: true,
			flag: MsgFlag.ALL_NOT_RESERVED,
			callback: EverduesAccount.onBalanceOf
		}();
	}

	function upgradeSubscription(
		address service_address,
		uint128 additional_gas
	) public view onlyOwner {
		IEverduesRoot(root).upgradeSubscription{
			value: EverduesGas.UPGRADE_SUBSCRIPTION_MIN_VALUE +
				additional_gas +
				EverduesGas.INIT_MESSAGE_VALUE,
			bounce: true,
			flag: 0
		}(service_address);
	}

	function cancelSubscription(address service_address, uint128 additional_gas)
		public
		view
		onlyOwner
	{
		IEverduesRoot(root).cancelSubscription{
			value: EverduesGas.CANCEL_MIN_VALUE + additional_gas,
			bounce: true,
			flag: 0
		}(service_address);
	}

	function updateServiceIdentificator(
		string service_name,
		TvmCell identificator,
		uint128 additional_gas
	) public view onlyOwner {
		IEverduesRoot(root).updateServiceIdentificator{
			value: EverduesGas.UPDATE_INDEX_VALUE + additional_gas,
			bounce: true,
			flag: 0
		}(service_name, identificator);
	}

	function updateSubscriptionIdentificator(
		address service_address,
		TvmCell identificator,
		uint128 additional_gas
	) public view onlyOwner {
		IEverduesRoot(root).updateSubscriptionIdentificator{
			value: EverduesGas.UPDATE_INDEX_VALUE + additional_gas,
			bounce: true,
			flag: 0
		}(service_address, identificator);
	}

	function updateServiceParams(
		string service_name,
		TvmCell new_service_params,
		uint128 additional_gas
	) public view onlyOwner {
		IEverduesRoot(root).updateServiceParams{
			value: EverduesGas.UPDADE_SERVICE_PARAMS_VALUE + additional_gas,
			bounce: true,
			flag: 0
		}(service_name, new_service_params);
	}

	function cancelService(string service_name, uint128 additional_gas)
		public
		view
		onlyOwner
	{
		IEverduesRoot(root).cancelService{
			value: EverduesGas.CANCEL_MIN_VALUE + additional_gas,
			bounce: true,
			flag: 0
		}(service_name);
	}

	function deployService(
		TvmCell service_params,
		TvmCell identificator,
		uint128 additional_gas
	) public onlyOwner {
		_tmp_deploy_service_operations[now] = DeployServiceOperation(
			service_params,
			identificator,
			additional_gas
		);
		EverduesRoot(root).getDeployServiceRequirements{
			value: EverduesGas.INIT_MESSAGE_VALUE,
			bounce: true,
			flag: 0,
			callback: EverduesAccount.onGetDeployServiceRequirements
		}();
	}

	function onGetDeployServiceRequirements(TvmCell requirements)
		external
		onlyRoot
	{
		(uint128 account_threshold, uint128 deploy_service_lock_value) = abi
			.decode(requirements, (uint128, uint128));
		require(
			address(this).balance > deploy_service_lock_value,
			EverduesErrors.error_deploy_service_requirements_not_met
		);
		optional(
			uint64,
			DeployServiceOperation
		) keyOpt = _tmp_deploy_service_operations.min();
		if (keyOpt.hasValue()) {
			(uint64 call_id, DeployServiceOperation last_operation) = keyOpt
				.get();
			call_id;
			uint128 gas = address(this).balance - account_threshold;
			IEverduesRoot(root).deployService{
				value: gas,
				bounce: true,
				flag: 0
			}(
				last_operation.service_params,
				last_operation.identificator,
				last_operation.additional_gas
			);
			_tmp_deploy_service_operations.delMin();
		}
	}

	function upgradeService(
		string service_name,
		string category,
		uint128 additional_gas
	) public view onlyOwner {
		IEverduesRoot(root).upgradeService{
			value: EverduesGas.UPGRADE_SERVICE_MIN_VALUE +
				additional_gas +
				EverduesGas.INIT_MESSAGE_VALUE,
			bounce: true,
			flag: 0
		}(service_name, category);
	}

	function deploySubscription(
		address service_address,
		TvmCell identificator,
		uint128 additional_gas
	) public view onlyOwner {
		IEverduesRoot(root).deploySubscription{
			value: EverduesGas.SUBSCRIPTION_INITIAL_BALANCE +
				EverduesGas.INIT_SUBSCRIPTION_VALUE +
				EverduesGas.EXECUTE_SUBSCRIPTION_VALUE +
				EverduesGas.INDEX_INITIAL_BALANCE *
				2 +
				additional_gas +
				EverduesGas.INIT_MESSAGE_VALUE,
			bounce: true,
			flag: 0
		}(service_address, identificator, tvm.pubkey(), additional_gas);
	}

	function onBalanceOf(uint128 balance_) external {
		optional(address) _currency_root = _tmp_sync_balance.fetch(msg.sender);
		if (_currency_root.hasValue()) {
			optional(
				balance_wallet_struct
			) current_balance_struct = wallets_mapping.fetch(
					_tmp_sync_balance[msg.sender]
				);
			if (current_balance_struct.hasValue()) {
				balance_wallet_struct current_balance_key = current_balance_struct
						.get();
				if (msg.sender == current_balance_key.wallet) {
					current_balance_key.balance = balance_;
					wallets_mapping[
						_tmp_sync_balance[msg.sender]
					] = current_balance_key;
					delete _tmp_sync_balance[msg.sender];
					emit BalanceSynced(balance_);
				} else {
					delete _tmp_sync_balance[msg.sender];
					tvm.commit();
					tvm.exit1();
				}
			} else {
				balance_wallet_struct current_balance_struct_;
				current_balance_struct_.wallet = msg.sender;
				current_balance_struct_.balance = balance_;
				wallets_mapping[
					_tmp_sync_balance[msg.sender]
				] = current_balance_struct_;
				_tmp_get_pairs[now] = GetDexPairOperation(
					_tmp_sync_balance[msg.sender],
					address(this)
				);
				IDexRoot(dex_root_address).getExpectedPairAddress{
					value: EverduesGas.INIT_MESSAGE_VALUE,
					flag: 0,
					bounce: false,
					callback: EverduesAccount.onGetExpectedPairAddress
				}(wever_root, _tmp_sync_balance[msg.sender]);
				emit BalanceSynced(balance_);
			}
		}
	}

	function withdrawFunds(
		address currency_root,
		uint128 withdraw_value,
		address withdraw_to,
		uint128 additional_gas
	) external onlyOwner {
		optional(balance_wallet_struct) current_balance_struct = wallets_mapping
			.fetch(currency_root);
		balance_wallet_struct current_balance_key = current_balance_struct
			.get();
		address account_wallet = current_balance_key.wallet;
		TvmCell payload;
		current_balance_key.balance =
			current_balance_key.balance -
			withdraw_value;
		wallets_mapping[currency_root] = current_balance_key;
		emit Withdraw(msg.sender, withdraw_value);
		ITokenWallet(account_wallet).transfer{
			value: EverduesGas.TRANSFER_MIN_VALUE + additional_gas,
			bounce: false,
			flag: 0
		}(withdraw_value, withdraw_to, 0, address(this), true, payload);
	}

	function destroyAccount(address send_gas_to)
		public
		onlyOwner /*onlyRoot*/
	{
		selfdestruct(send_gas_to);
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
				EverduesErrors.error_message_sender_is_not_account_wallet
			);
			current_balance_key.balance += amount;
			wallets_mapping[tokenRoot] = current_balance_key;
			if (current_balance_key.dex_ever_pair_address == address(0)) {
				_tmp_get_pairs[now] = GetDexPairOperation(
					tokenRoot,
					remainingGasTo
				);
				IDexRoot(dex_root_address).getExpectedPairAddress{
					value: EverduesGas.INIT_MESSAGE_VALUE,
					flag: 0,
					bounce: false,
					callback: EverduesAccount.onGetExpectedPairAddress
				}(wever_root, tokenRoot);
			}
			remainingGasTo.transfer({
				value: 0,
				flag: MsgFlag.REMAINING_GAS + MsgFlag.IGNORE_ERRORS
			});
		} else {
			balance_wallet_struct current_balance_struct_;
			current_balance_struct_.wallet = msg.sender;
			current_balance_struct_.balance = amount;
			wallets_mapping[tokenRoot] = current_balance_struct_;
		}
		emit Deposit(msg.sender, amount);
	}

	function onGetExpectedPairAddress(address dex_pair_address)
		external
		onlyDexRoot
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.ACCOUNT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		optional(uint64, GetDexPairOperation) keyOpt = _tmp_get_pairs.min();
		if (keyOpt.hasValue()) {
			(, GetDexPairOperation dex_operation) = keyOpt.get();
			balance_wallet_struct current_balance_key = wallets_mapping[
				dex_operation.currency_root
			];
			current_balance_key.dex_ever_pair_address = dex_pair_address;
			wallets_mapping[dex_operation.currency_root] = current_balance_key;
			_tmp_get_pairs.delMin();
			if (dex_operation.send_gas_to != address(this)) {
				dex_operation.send_gas_to.transfer({
					value: 0,
					flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
				});
			}
		}
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

	function _buildPlatformParamsOwnerAddress(address account_owner)
		private
		inline
		pure
		returns (TvmCell)
	{
		TvmBuilder builder;
		builder.store(account_owner);
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
