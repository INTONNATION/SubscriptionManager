pragma ton-solidity >=0.56.0;

import "./EverduesAccountSettings.sol";
import "../../libraries/EverduesGas.sol";
import "../../interfaces/IEverduesService.sol";

// external interfaces
// Broxus Flatqube
import "../../interfaces/IDexRoot.sol";
import "../../interfaces/IDexPair.sol";
import "../../libraries/DexOperationTypes.sol";

// TIP3 by Broxus
import "../../../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenWallet.sol";
import "../../../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenRoot.sol";
import "../../../ton-eth-bridge-token-contracts/contracts/interfaces/TIP3TokenWallet.sol";

abstract contract EverduesAccountBase is
	IEverduesAccount,
	EverduesAccountSettings
{
	constructor() public {
		revert();
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

	function upgradeAccount(uint128 additional_gas) external view onlyOwner {
		IEverduesRoot(root).upgradeAccount{
			value: EverduesGas.UPGRADE_MIN_VALUE +
				additional_gas +
				EverduesGas.MESSAGE_MIN_VALUE,
			bounce: true,
			flag: 0
		}(tvm.pubkey());
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
					ContractTypes.Subscription,
					_buildSubscriptionParams(address(this), service_address)
				)
			)
		);
		require(
			subsciption_addr == msg.sender,
			EverduesErrors.error_message_sender_is_not_my_subscription
		);
		optional(BalanceWalletStruct) current_balance_struct = wallets_mapping
			.fetch(currency_root);
		if (current_balance_struct.hasValue()) {
			BalanceWalletStruct current_balance_key_value = current_balance_struct
					.get();
			uint128 current_balance = current_balance_key_value.balance;
			if (value > current_balance) {
				return
					{value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false} (
						1,
						address(this).balance - msg.value
					);
			} else {
				return
					{value: 0, flag: MsgFlag.ALL_NOT_RESERVED, bounce: false} (
						0,
						address(this).balance - msg.value
					);
			}
		}
	}

	function paySubscription(
		uint128 value,
		address currency_root,
		address subscription_wallet,
		address service_address,
		bool subscription_deploy,
		uint128 additional_gas
	) external override onlyFeeProxy {
		tvm.rawReserve(
			math.max(
				EverduesGas.ACCOUNT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		optional(BalanceWalletStruct) current_balance_struct = wallets_mapping
			.fetch(currency_root);
		if (current_balance_struct.hasValue()) {
			BalanceWalletStruct current_balance_key_value = current_balance_struct
					.get();
			uint128 current_balance = current_balance_key_value.balance;
			if (value > current_balance) {
				revert(EverduesErrors.error_tip3_low_value);
			} else {
				_tmp_subscription_operations[now] = SubscriptionOperation(
					currency_root,
					value,
					subscription_wallet,
					additional_gas,
					msg.sender,
					msg.value,
					subscription_deploy,
					0,
					0
				);
				if (subscription_deploy) {
					IEverduesService(service_address).getGasCompenstationProportion{
						value: 0,
						bounce: true,
						flag: MsgFlag.ALL_NOT_RESERVED,
						callback: EverduesAccountBase
							.onGetGasCompenstationProportion
					}();
				} else {
					IDexPair(current_balance_key_value.dex_ever_pair_address)
						.expectedSpendAmount{
						value: 0,
						bounce: true,
						flag: MsgFlag.ALL_NOT_RESERVED,
						callback: EverduesAccountBase.onExpectedExchange
					}(msg.value, wever_root);
				}
			}
		}
	}

	function onGetGasCompenstationProportion(
		uint8 service_gas_compenstation,
		uint8 subscription_gas_compenstation
	) external view onlyRoot {
		optional(
			uint64,
			SubscriptionOperation
		) keyOpt = _tmp_subscription_operations.min();
		if (keyOpt.hasValue()) {
			(uint64 call_id, SubscriptionOperation last_operation) = keyOpt
				.get();
			call_id;
			last_operation
				.service_gas_compenstation = service_gas_compenstation;
			last_operation
				.subscription_gas_compenstation = subscription_gas_compenstation;
			optional(
				BalanceWalletStruct
			) current_balance_struct = wallets_mapping.fetch(
					last_operation.currency_root
				);
			BalanceWalletStruct current_balance_key = current_balance_struct
				.get();
			IDexPair(current_balance_key.dex_ever_pair_address)
				.expectedSpendAmount{
				value: 0,
				bounce: true,
				flag: MsgFlag.ALL_NOT_RESERVED,
				callback: EverduesAccountBase.onExpectedExchange
			}(last_operation.gas_value, wever_root);
		}
	}

	function onExpectedExchange(
		uint128 expected_amount,
		uint128 /*expected_fee*/
	) external {
		tvm.rawReserve(
			math.max(
				EverduesGas.ACCOUNT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		optional(
			uint64,
			SubscriptionOperation
		) keyOpt = _tmp_subscription_operations.min();
		if (keyOpt.hasValue()) {
			(uint64 call_id, SubscriptionOperation last_operation) = keyOpt
				.get();
			call_id;
			optional(
				BalanceWalletStruct
			) current_balance_struct = wallets_mapping.fetch(
					last_operation.currency_root
				);
			BalanceWalletStruct current_balance_key = current_balance_struct
				.get();
			require(
				msg.sender == current_balance_key.dex_ever_pair_address,
				EverduesErrors.error_message_sender_is_not_dex_pair
			);
			address account_wallet = current_balance_key.wallet;
			TvmCell payload;
			uint128 value_gas_compensation;
			if (last_operation.subscription_deploy) {
				if (last_operation.service_gas_compenstation == 0) {
					payload = abi.encode(uint128(0));
					value_gas_compensation = expected_amount;
				} else {
					payload = abi.encode(
						(expected_amount * 100) /
							last_operation.service_gas_compenstation
					);
					value_gas_compensation =
						(expected_amount * 100) /
						last_operation.subscription_gas_compenstation;
				}
				if (last_operation.subscription_gas_compenstation == 0) {
					payload = abi.encode(expected_amount);
					expected_amount = 0;
				} else {
					payload = abi.encode(
						(expected_amount * 100) /
							last_operation.service_gas_compenstation
					);
					value_gas_compensation =
						(expected_amount * 100) /
						last_operation.subscription_gas_compenstation;
				}
			} else {
				payload = abi.encode(expected_amount);
			}

			ITokenWallet(account_wallet).transferToWallet{
				value: 0,
				bounce: false,
				flag: MsgFlag.ALL_NOT_RESERVED
			}(
				last_operation.value + value_gas_compensation,
				last_operation.subscription_wallet,
				address(this),
				true,
				payload
			);
			uint128 balance_after_pay = current_balance_key.balance -
				last_operation.value;
			current_balance_key.balance = balance_after_pay;
			wallets_mapping[last_operation.currency_root] = current_balance_key;
			_tmp_subscription_operations.delMin();
		}
	}

	function onAcceptTokensWalletOf(address account_wallet) external {
		tvm.rawReserve(
			math.max(
				EverduesGas.ACCOUNT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		DepositTokens deposit = tmp_deposit_tokens[msg.sender];
		if (deposit.wallet != account_wallet) {
			delete tmp_deposit_tokens[msg.sender];
			tvm.commit();
			revert(EverduesErrors.error_message_sender_is_not_account_wallet);
		} else {
			BalanceWalletStruct current_balance_struct_;
			current_balance_struct_.wallet = account_wallet;
			current_balance_struct_.balance = deposit.amount;
			wallets_mapping[msg.sender] = current_balance_struct_;
			_tmp_get_pairs[now] = GetDexPairOperation(
				msg.sender,
				address(this)
			);
			IDexRoot(dex_root_address).getExpectedPairAddress{
				value: EverduesGas.MESSAGE_MIN_VALUE,
				flag: 0,
				bounce: false,
				callback: EverduesAccountBase.onGetExpectedPairAddress
			}(wever_root, msg.sender);
			emit Deposit(msg.sender, deposit.amount);
			delete tmp_deposit_tokens[msg.sender];
		}
	}

	function syncBalance(address currency_root, uint128 additional_gas)
		external
		onlyOwner
	{
		tvm.rawReserve(EverduesGas.ACCOUNT_INITIAL_BALANCE, 0);
		optional(BalanceWalletStruct) current_balance_struct = wallets_mapping
			.fetch(currency_root);
		if (current_balance_struct.hasValue()) {
			BalanceWalletStruct current_balance_key = current_balance_struct
				.get();
			address account_wallet = current_balance_key.wallet;
			_tmp_sync_balance[account_wallet] = currency_root;
			if (current_balance_key.dex_ever_pair_address == address(0)) {
				_tmp_get_pairs[now] = GetDexPairOperation(
					currency_root,
					address(this)
				);
				IDexRoot(dex_root_address).getExpectedPairAddress{
					value: EverduesGas.MESSAGE_MIN_VALUE,
					flag: 0,
					bounce: false,
					callback: EverduesAccountBase.onGetExpectedPairAddress
				}(wever_root, currency_root);
			}
			TIP3TokenWallet(account_wallet).balance{
				value: EverduesGas.MESSAGE_MIN_VALUE + additional_gas,
				bounce: true,
				flag: 0,
				callback: EverduesAccountBase.onBalanceOf
			}();
		} else {
			_tmp_sync_balance[currency_root] = address(0);
			ITokenRoot(currency_root).walletOf{
				value: EverduesGas.MESSAGE_MIN_VALUE + additional_gas,
				bounce: true,
				flag: 0,
				callback: EverduesAccountBase.onWalletOf
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
		require(
			_tmp_sync_balance.exists(msg.sender),
			EverduesErrors.error_message_sender_is_not_currency_root
		);
		delete _tmp_sync_balance[msg.sender];
		_tmp_sync_balance[account_wallet] = msg.sender;
		TIP3TokenWallet(account_wallet).balance{
			value: 0,
			bounce: true,
			flag: MsgFlag.ALL_NOT_RESERVED,
			callback: EverduesAccountBase.onBalanceOf
		}();
	}

	function deployService(
		address currency_root,
		uint128 deploy_value,
		TvmCell service_params,
		TvmCell identificator,
		bool publish_to_catalog,
		uint128 additional_gas
	) external onlyOwner {
		optional(BalanceWalletStruct) current_balance_struct = wallets_mapping
			.fetch(currency_root);
		if (current_balance_struct.hasValue()) {
			BalanceWalletStruct current_balance_key = current_balance_struct
				.get();
			address account_wallet = current_balance_key.wallet;
			TvmCell payload = abi.encode(
				service_params,
				identificator,
				tvm.pubkey(),
				publish_to_catalog,
				additional_gas
			);
			current_balance_key.balance -= deploy_value;
			wallets_mapping[currency_root] = current_balance_key;
			ITokenWallet(account_wallet).transfer{
				value: EverduesGas.DEPLOY_SERVICE_VALUE_ACCOUNT +
					additional_gas,
				bounce: true,
				flag: 0
			}(deploy_value, root, 0, address(this), true, payload);
		} else {
			revert(EverduesErrors.error_wallet_not_exist);
		}
	}

	function upgradeService(
		string service_name,
		string category,
		uint128 additional_gas
	) external view onlyOwner {
		IEverduesRoot(root).upgradeService{
			value: EverduesGas.UPGRADE_MIN_VALUE +
				additional_gas +
				EverduesGas.MESSAGE_MIN_VALUE,
			bounce: true,
			flag: 0
		}(service_name, category, tvm.pubkey());
	}

	function upgradeSubscription(
		address service_address,
		uint128 additional_gas
	) external view onlyOwner {
		IEverduesRoot(root).upgradeSubscription{
			value: EverduesGas.UPGRADE_MIN_VALUE +
				additional_gas +
				EverduesGas.MESSAGE_MIN_VALUE,
			bounce: true,
			flag: 0
		}(service_address, tvm.pubkey());
	}

	function upgradeSubscriptionPlan(
		uint8 new_subscription_plan,
		address service_address,
		uint128 additional_gas
	) external view onlyOwner {
		IEverduesRoot(root).upgradeSubscriptionPlan{
			value: EverduesGas.MESSAGE_MIN_VALUE +
				additional_gas +
				EverduesGas.MESSAGE_MIN_VALUE,
			bounce: true,
			flag: 0
		}(service_address, new_subscription_plan, tvm.pubkey());
	}

	function deploySubscription(
		address service_address,
		TvmCell identificator,
		uint8 subscription_plan,
		uint128 additional_gas
	) external view onlyOwner {
		IEverduesRoot(root).deploySubscription{
			value: EverduesGas.SUBSCRIPTION_INITIAL_BALANCE +
				EverduesGas.DEPLOY_SUBSCRIPTION_VALUE +
				EverduesGas.EXECUTE_SUBSCRIPTION_VALUE +
				EverduesGas.MESSAGE_MIN_VALUE *
				3 +
				additional_gas,
			bounce: true,
			flag: 0
		}(
			service_address,
			identificator,
			tvm.pubkey(),
			subscription_plan,
			additional_gas
		);
	}

	function onBalanceOf(uint128 balance_) external {
		optional(address) _currency_root = _tmp_sync_balance.fetch(msg.sender);
		if (_currency_root.hasValue()) {
			optional(
				BalanceWalletStruct
			) current_balance_struct = wallets_mapping.fetch(
					_tmp_sync_balance[msg.sender]
				);
			if (current_balance_struct.hasValue()) {
				BalanceWalletStruct current_balance_key = current_balance_struct
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
				BalanceWalletStruct current_balance_struct_;
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
					value: EverduesGas.MESSAGE_MIN_VALUE,
					flag: 0,
					bounce: false,
					callback: EverduesAccountBase.onGetExpectedPairAddress
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
		optional(BalanceWalletStruct) current_balance_struct = wallets_mapping
			.fetch(currency_root);
		BalanceWalletStruct current_balance_key = current_balance_struct.get();
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

	function onAcceptTokensTransfer(
		address tokenRoot,
		uint128 amount,
		address, /*sender*/
		address, /*senderWallet*/
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
					value: EverduesGas.MESSAGE_MIN_VALUE,
					flag: 0,
					bounce: false,
					callback: EverduesAccountBase.onGetExpectedPairAddress
				}(wever_root, tokenRoot);
			}
			emit Deposit(msg.sender, amount);
			if (remainingGasTo != address(this)) {
				remainingGasTo.transfer({
					value: 0,
					bounce: false,
					flag: MsgFlag.REMAINING_GAS + MsgFlag.IGNORE_ERRORS
				});
			}
		} else {
			tmp_deposit_tokens[tokenRoot] = DepositTokens(msg.sender, amount);
			ITokenRoot(tokenRoot).walletOf{
				value: EverduesGas.MESSAGE_MIN_VALUE,
				bounce: true,
				flag: 0,
				callback: EverduesAccountBase.onAcceptTokensWalletOf
			}(address(this));
			if (remainingGasTo != address(this)) {
				remainingGasTo.transfer({
					value: 0,
					bounce: false,
					flag: MsgFlag.REMAINING_GAS + MsgFlag.IGNORE_ERRORS
				});
			}
		}
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
			BalanceWalletStruct current_balance_key = wallets_mapping[
				dex_operation.currency_root
			];
			current_balance_key.dex_ever_pair_address = dex_pair_address;
			wallets_mapping[dex_operation.currency_root] = current_balance_key;
			_tmp_get_pairs.delMin();
			if (dex_operation.send_gas_to != address(this)) {
				dex_operation.send_gas_to.transfer({
					value: 0,
					bounce: false,
					flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
				});
			}
		}
	}
}
