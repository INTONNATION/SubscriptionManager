pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "Platform.sol";
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
	address public tip3_to_ever_address;
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

	struct ExchangeOperation {
		address currency_root;
		uint128 value;
		address subscription_wallet;
		uint128 pay_subscription_gas;
		address subscription_contract;
	}

	struct GetDexPairOperation {
		address currency_root;
		address send_gas_to;
	}

	mapping(address => balance_wallet_struct) public wallets_mapping;
	mapping(address => address) public _tmp_sync_balance;

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

	function upgrade(TvmCell code, uint32 version, TvmCell contract_params) external onlyRoot {
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
			wever_root,
			tip3_to_ever_address
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
			TvmCell contract_params,
			/*TvmCell code*/
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
				address wever_root_,
				address tip3_to_ever_address_
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
						address,
						address					)
				);
			wallets_mapping = wallets_mapping_;
			wever_root = wever_root_;
			tip3_to_ever_address = tip3_to_ever_address_;
			dex_root_address = dex_root_address_;
		} else if (old_version == 0 && !contract_params.toSlice().empty()) {
			(dex_root_address, wever_root, tip3_to_ever_address) = abi.decode(
				contract_params,
				(address, address, address)
			);			
		}
		emit AccountDeployed(current_version);
	}

	function getNextPaymentStatus(address service_address, uint128 value, address currency_root) external override responsible returns (uint8, uint128) {
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
		optional(balance_wallet_struct) current_balance_struct = wallets_mapping.fetch(currency_root);
		if (current_balance_struct.hasValue()) {
			balance_wallet_struct current_balance_key_value = current_balance_struct
					.get();
			uint128 current_balance = current_balance_key_value.balance;
			if (value > current_balance) {
				return {value: 0, flag: MsgFlag.ALL_NOT_RESERVED} (1, address(this).balance);
			} else {
				return {value: 0, flag: MsgFlag.ALL_NOT_RESERVED} (0, address(this).balance);
			}
		}
	}

	function paySubscription(
		uint128 value,
		address currency_root,
		address subscription_wallet,
		uint128 additional_gas
	) external override {
		optional(balance_wallet_struct) current_balance_struct = wallets_mapping
			.fetch(currency_root);
		if (current_balance_struct.hasValue()) {
			balance_wallet_struct current_balance_key_value = current_balance_struct
					.get();
			uint128 current_balance = current_balance_key_value.balance;
			if (value > current_balance) {
				revert(1111);
			} else {
				TvmCell payload;
				address account_wallet = current_balance_key_value.wallet;
				ITokenWallet(account_wallet).transferToWallet{
					value: EverduesGas.TRANSFER_MIN_VALUE *
						2 +
						additional_gas,
					bounce: false,
					flag: MsgFlag.SENDER_PAYS_FEES
				}(value, subscription_wallet, address(this), true, payload);
				uint128 balance_after_pay = current_balance - value;
				current_balance_key_value.balance = balance_after_pay;
				wallets_mapping[currency_root] = current_balance_key_value;
			}
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
	) public view onlyOwner {
		IEverduesRoot(root).deployService{
			value: EverduesGas.SERVICE_INITIAL_BALANCE +
				EverduesGas.INDEX_INITIAL_BALANCE *
				2 +
				EverduesGas.INIT_MESSAGE_VALUE *
				4 +
				EverduesGas.SET_SERVICE_INDEXES_VALUE +
				additional_gas +
				EverduesGas.INIT_MESSAGE_VALUE,
			bounce: true,
			flag: 0
		}(service_params, identificator, additional_gas);
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
				delete _tmp_sync_balance[msg.sender];
				emit BalanceSynced(balance_);
			}
		}
	}

	function withdrawGas(uint128 withdraw_value, address withdraw_to)
		external
		pure
		onlyOwner
	{
		withdraw_to.transfer({value: withdraw_value, flag: 0});
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

	function destroyAccount(address send_gas_to) public onlyOwner {
		selfdestruct(send_gas_to);
	}

	function onAcceptTokensTransfer(
		address tokenRoot,
		uint128 amount,
		address /*sender*/,
		address /*senderWallet*/,
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
