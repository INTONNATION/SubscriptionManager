pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "SubscriptionIndex.sol";
import "Platform.sol";
import "libraries/EverduesErrors.sol";
import "libraries/EverduesGas.sol";
import "libraries/MsgFlag.sol";
import "libraries/PlatformTypes.sol";
import "libraries/EverduesSubscriptionStatus.sol";
import "interfaces/IEverduesAccount.sol";
import "interfaces/IEverduesIndex.sol";
import "interfaces/IEverduesFeeProxy.sol";
import "interfaces/IEverduesService.sol";
import "interfaces/IEverduesSubscription.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenWallet.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenRoot.sol";

contract Subscription is IEverduesSubscription {
	address public root;
	address public address_fee_proxy;
	address public account_address;
	uint256 public owner_pubkey;
	address public subscription_index_address;
	address public subscription_index_identificator_address;
	uint8 public service_fee;
	uint8 public subscription_fee;
	uint8 public subscription_plan;
	TvmCell public subscription_params;
	TvmCell public service_params;
	TvmCell platform_code;
	TvmCell platform_params;
	address subscription_wallet;
	address service_address;
	uint256 root_pubkey;
	uint32 current_version;
	uint32 preprocessing_window;
	uint8 type_id;
	uint8 debug;

	struct serviceParams {
		address to;
		uint128 subscription_value;
		uint128 service_value;
		uint32 period;
		string name;
		string description;
		string image;
		address currency_root;
		string category;
	}

	serviceParams public svcparams;

	struct paymentStatus {
		uint32 period;
		uint32 payment_timestamp;
		uint32 execution_timestamp;
		uint8 status;
		uint128 pay_subscription_gas;
	}

	paymentStatus public subscription;

	constructor() public {
		revert();
	}

	modifier onlyRoot() {
		require(
			msg.sender == root,
			EverduesErrors.error_message_sender_is_not_everdues_root
		);
		_;
	}

	modifier onlyService() {
		require(
			msg.sender == service_address,
			EverduesErrors.error_message_sender_is_not_service_address
		);
		_;
	}

	modifier onlyAccount() {
		require(
			msg.sender == account_address,
			EverduesErrors.error_message_sender_is_not_account_address
		);
		_;
	}

	modifier onlyCurrencyRoot() {
		require(
			msg.sender == svcparams.currency_root,
			EverduesErrors.error_message_sender_is_not_currency_root
		);
		_;
	}

	modifier onlyRootOrOwner() {
		require(
			(msg.pubkey() == root_pubkey || msg.pubkey() == owner_pubkey),
			1000
		);
		_;
	}

	function upgrade(
		TvmCell code,
		uint32 version,
		address send_gas_to,
		TvmCell contract_params_
	) external onlyRoot {
		require(
			msg.value > EverduesGas.UPGRADE_SUBSCRIPTION_MIN_VALUE,
			EverduesErrors.error_message_low_value
		);
		TvmCell data = abi.encode(
			root,
			send_gas_to,
			current_version,
			version,
			type_id,
			platform_code,
			platform_params,
			contract_params_,
			code,
			subscription,
			address_fee_proxy,
			account_address,
			subscription_index_address,
			subscription_index_identificator_address,
			service_fee,
			subscription_fee,
			svcparams,
			preprocessing_window,
			subscription_wallet,
			service_address,
			owner_pubkey,
			subscription_plan
		);
		tvm.setcode(code);
		tvm.setCurrentCode(code);
		onCodeUpgrade(data);
	}

	function onCodeUpgrade(TvmCell upgrade_data) private {
		tvm.rawReserve(EverduesGas.SUBSCRIPTION_INITIAL_BALANCE, 0);
		tvm.resetStorage();
		address send_gas_to;
		uint32 old_version;
		TvmCell contract_params;
		(
			root,
			send_gas_to,
			old_version,
			current_version,
			type_id,
			platform_code,
			platform_params,
			contract_params,
			/*TvmCell code*/

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

		if (old_version == 0) {
			(
				address_fee_proxy,
				service_fee,
				subscription_fee,
				root_pubkey,
				subscription_index_address,
				subscription_index_identificator_address,
				service_address,
				account_address,
				owner_pubkey,
				subscription_plan
			) = abi.decode(
				contract_params,
				(
					address,
					uint8,
					uint8,
					uint256,
					address,
					address,
					address,
					address,
					uint256,
					uint8
				)
			);
			IEverduesService(service_address).getParams{
				value: 0,
				bounce: true,
				flag: MsgFlag.ALL_NOT_RESERVED,
				callback: Subscription.onGetParams
			}(subscription_plan);
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
				subscription,
				address_fee_proxy,
				account_address,
				subscription_index_address,
				subscription_index_identificator_address,
				service_fee,
				subscription_fee,
				svcparams,
				preprocessing_window,
				subscription_wallet,
				service_address,
				owner_pubkey,
				subscription_plan
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
					Subscription.paymentStatus,
					address,
					address,
					address,
					address,
					uint8,
					uint8,
					Subscription.serviceParams,
					uint32,
					address,
					address,
					uint256,
					uint8
				)
			);
			send_gas_to.transfer({
				value: 0,
				flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
			});
		}
	}

	function upgradeSubscriptionPlan(uint8 new_subscription_plan)
		external
		onlyAccount
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.SUBSCRIPTION_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		subscription_plan = new_subscription_plan;
		IEverduesService(service_address).getParams{
			value: 0,
			bounce: true,
			flag: MsgFlag.ALL_NOT_RESERVED,
			callback: Subscription.onGetParams
		}(new_subscription_plan);
	}

	function subscriptionStatus() public override returns (uint8) {
		if (
			now < (subscription.payment_timestamp + svcparams.period) ||
			(subscription.period == 0 &&
				subscription.status == EverduesSubscriptionStatus.STATUS_ACTIVE)
		) {
			return EverduesSubscriptionStatus.STATUS_ACTIVE;
		} else if (
			(now > (subscription.payment_timestamp + svcparams.period)) &&
			(subscription.status !=
				EverduesSubscriptionStatus.STATUS_PROCESSING)
		) {
			return EverduesSubscriptionStatus.STATUS_NONACTIVE;
		} else {
			return EverduesSubscriptionStatus.STATUS_PROCESSING;
		}
	}

	function executeSubscription(uint128 paySubscriptionGas)
		public
		override
		onlyRootOrOwner // TODO: add serviceOwner
	{
		// TODO: Add check that service_params exist
		require(
			subscription.status != EverduesSubscriptionStatus.STATUS_STOPPED,
			EverduesErrors.error_subscription_is_stopped
		);
		if (
			subscription.period != 0 &&
			subscription.status != EverduesSubscriptionStatus.STATUS_ACTIVE
		) {
			if (
				now >
				(subscription.payment_timestamp +
					svcparams.period -
					preprocessing_window)
			) {
				uint8 subcr_status = subscriptionStatus();
				require(
					subcr_status !=
						EverduesSubscriptionStatus.STATUS_PROCESSING &&
						subcr_status !=
						EverduesSubscriptionStatus.STATUS_ACTIVE,
					EverduesErrors.error_subscription_already_executed
				);
				tvm.accept();
				subscription.pay_subscription_gas = paySubscriptionGas;
				subscription.execution_timestamp = uint32(now);
				IEverduesService(service_address).getInfo{
					value: EverduesGas.EXECUTE_SUBSCRIPTION_VALUE +
						subscription.pay_subscription_gas,
					bounce: true,
					flag: 0,
					callback: Subscription.onGetInfo
				}();
			} else {
				revert(EverduesErrors.error_subscription_status_already_active);
			}
		} else {
			revert(EverduesErrors.error_subscription_status_already_active);
		}
	}

	function onGetInfo(TvmCell svc_info) external onlyService {
		uint8 status = svc_info.toSlice().decode(uint8);
		require(
			subscription.status != EverduesSubscriptionStatus.STATUS_PROCESSING,
			1000
		);
		if (status == 0) {
			subscription.status = EverduesSubscriptionStatus.STATUS_PROCESSING;
			IEverduesAccount(account_address).getNextPaymentStatus{
				value: 0,
				bounce: true,
				flag: MsgFlag.REMAINING_GAS,
				callback: Subscription.onGetNextPaymentStatus
			}(
				service_address,
				svcparams.subscription_value,
				svcparams.currency_root
			);
		} else {
			revert(EverduesErrors.error_service_is_not_active);
		}
	}

	function executeSubscription_() private inline {
		tvm.rawReserve(EverduesGas.SUBSCRIPTION_INITIAL_BALANCE, 0);
		subscription.execution_timestamp = uint32(now);
		subscription.status = EverduesSubscriptionStatus.STATUS_PROCESSING;
		IEverduesAccount(account_address).getNextPaymentStatus{
			value: EverduesGas.EXECUTE_SUBSCRIPTION_VALUE,
			bounce: true,
			flag: MsgFlag.SENDER_PAYS_FEES,
			callback: Subscription.onGetNextPaymentStatus
		}(
			service_address,
			svcparams.subscription_value,
			svcparams.currency_root
		);
		account_address.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}

	function onAcceptTokensTransfer(
		address, /*tokenRoot*/
		uint128 amount,
		address, /*sender*/
		address, /*senderWallet*/
		address, /*remainingGasTo*/
		TvmCell payload
	) public {
		require(
			amount >= svcparams.service_value,
			EverduesErrors.error_not_enough_balance_in_message
		);
		require(
			msg.sender == subscription_wallet,
			EverduesErrors.error_message_sender_is_not_subscription_wallet
		);
		tvm.rawReserve(
			math.max(
				EverduesGas.SUBSCRIPTION_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		uint128 account_compensation_fee = abi.decode(payload, (uint128));
		uint128 service_value_percentage = svcparams.service_value / 100;
		uint128 service_fee_value = service_value_percentage * service_fee;
		uint128 protocol_fee = (svcparams.subscription_value -
			svcparams.service_value +
			service_fee_value +
			account_compensation_fee);
		uint128 pay_value = svcparams.subscription_value - protocol_fee;
		subscription.payment_timestamp = uint32(now) + subscription.period;
		subscription.status = EverduesSubscriptionStatus.STATUS_ACTIVE;
		ITokenWallet(msg.sender).transfer{
			value: EverduesGas.TRANSFER_MIN_VALUE,
			flag: MsgFlag.SENDER_PAYS_FEES
		}(protocol_fee, address_fee_proxy, 0, address(this), true, payload);
		ITokenWallet(msg.sender).transfer{
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(
			pay_value,
			svcparams.to,
			EverduesGas.DEPLOY_EMPTY_WALLET_GRAMS,
			account_address,
			true,
			payload
		);
	}

	function replenishGas() external override {
		tvm.rawReserve(EverduesGas.SUBSCRIPTION_INITIAL_BALANCE, 0);
		TvmCell body;
		msg.sender.transfer(0, false, MsgFlag.REMAINING_GAS, body);
	}

	function onGetNextPaymentStatus(
		uint8 next_payment_status,
		uint128 account_gas_balance
	) external onlyAccount {
		if (next_payment_status == 1) {
			subscription.status = EverduesSubscriptionStatus.STATUS_NONACTIVE;
		} else if (next_payment_status == 0) {
			subscription.status = EverduesSubscriptionStatus.STATUS_PROCESSING;
			IEverduesFeeProxy(address_fee_proxy).executePaySubscription{
				value: 0,
				bounce: true,
				flag: MsgFlag.REMAINING_GAS
			}(
				account_address,
				service_address,
				svcparams.service_value,
				svcparams.currency_root,
				subscription_wallet,
				account_gas_balance,
				subscription.pay_subscription_gas
			);
		}
	}

	function onGetParams(TvmCell service_params_) external onlyService {
		// TODO: validate service params
		(service_params, subscription_params) = abi.decode(
			service_params_,
			(TvmCell, TvmCell)
		);
		(
			svcparams.to,
			svcparams.name,
			svcparams.description,
			svcparams.image,
			svcparams.category
		) = abi.decode(
			service_params,
			(address, string, string, string, string)
		);
		(
			svcparams.service_value,
			svcparams.period,
			svcparams.currency_root
		) = abi.decode(subscription_params, (uint128, uint32, address));
		uint128 service_value_percentage = svcparams.service_value / 100;
		uint128 subscription_fee_value = service_value_percentage *
			subscription_fee;
		svcparams.subscription_value =
			svcparams.service_value +
			subscription_fee_value;
		preprocessing_window = (svcparams.period / 100) * 30;
		emit paramsRecieved(service_params);
		subscription = paymentStatus(
			svcparams.period,
			0,
			0,
			EverduesSubscriptionStatus.STATUS_NONACTIVE,
			0
		);
		ITokenRoot(svcparams.currency_root).deployWallet{
			value: 0,
			bounce: false,
			flag: MsgFlag.REMAINING_GAS,
			callback: Subscription.onDeployWallet
		}(address(this), EverduesGas.DEPLOY_EMPTY_WALLET_GRAMS);
	}

	function onDeployWallet(address subscription_wallet_)
		external
		onlyCurrencyRoot
	{
		subscription_wallet = subscription_wallet_;
		if (subscription.payment_timestamp == 0) {
			executeSubscription_();
		} else {
			account_address.transfer({
				value: 0,
				bounce: false,
				flag: MsgFlag.REMAINING_GAS + MsgFlag.IGNORE_ERRORS
			});
		}
	}

	function stopSubscribtion() public onlyRootOrOwner {
		tvm.accept();
		subscription.status = EverduesSubscriptionStatus.STATUS_STOPPED;
	}

	function resumeSubscribtion() public onlyRootOrOwner {
		tvm.accept();
		subscription.status = EverduesSubscriptionStatus.STATUS_NONACTIVE;
	}

	function cancel() public onlyRootOrOwner {
		IEverduesIndex(subscription_index_address).cancel{
			value: EverduesGas.CANCEL_MIN_VALUE,
			flag: MsgFlag.SENDER_PAYS_FEES
		}();
		IEverduesIndex(subscription_index_identificator_address).cancel{
			value: EverduesGas.CANCEL_MIN_VALUE,
			flag: MsgFlag.SENDER_PAYS_FEES
		}();
		selfdestruct(account_address);
	}

	function updateIdentificator(TvmCell identificator_, address send_gas_to)
		external
		view
		onlyRoot
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.SUBSCRIPTION_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		IEverduesIndex(subscription_index_identificator_address)
			.updateIdentificator{
			value: 0,
			bounce: true,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(identificator_, send_gas_to);
	}
}
