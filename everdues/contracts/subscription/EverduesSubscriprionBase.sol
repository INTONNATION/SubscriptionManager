pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "./EverduesSubscriptionSettings.sol";

import "../../interfaces/IEverduesAccount.sol";
import "../../interfaces/IEverduesFeeProxy.sol";
import "../../interfaces/IEverduesService.sol";
import "../../interfaces/IEverduesSubscription.sol";

import "../../../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenWallet.sol";
import "../../../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenRoot.sol";

abstract contract EverduesSubscriprionBase is
	IEverduesSubscription,
	EverduesSubscriptionSettings
{
	constructor() public {
		revert();
	}

	function upgradeSubscriptionPlan(uint8 new_subscription_plan)
		external
		override
		onlyOwner
	{
		tvm.accept();
		subscription_plan = new_subscription_plan;
		IEverduesService(service_address).getParams{
			value: EverduesGas.MESSAGE_MIN_VALUE,
			bounce: true,
			flag: 0,
			callback: EverduesSubscriprionBase.onGetParams
		}(new_subscription_plan);
	}

	function executeSubscription(uint128 paySubscriptionGas)
		external
		override
		onlyRootOrServiceOrOwner
	{
		require(
			!service_params.toSlice().empty(),
			EverduesErrors.error_subscription_has_no_service_params
		);
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
					callback: EverduesSubscriprionBase.onGetInfo
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
			EverduesErrors.error_subscription_status_is_not_processed
		);
		if (status == 0) {
			subscription.status = EverduesSubscriptionStatus.STATUS_PROCESSING;
			IEverduesAccount(account_address).getNextPaymentStatus{
				value: 0,
				bounce: true,
				flag: MsgFlag.REMAINING_GAS,
				callback: EverduesSubscriprionBase.onGetNextPaymentStatus
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
			callback: EverduesSubscriprionBase.onGetNextPaymentStatus
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
	) external {
		require(
			amount >= svcparams.service_value,
			EverduesErrors.error_message_low_value
		); // TODO: send back ??
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
		require(
			!service_params_.toSlice().empty(),
			EverduesErrors.error_subscription_has_no_service_params
		);
		(service_params, subscription_params, service_pubkey) = abi.decode(
			service_params_,
			(TvmCell, TvmCell, uint256)
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
			callback: EverduesSubscriprionBase.onDeployWallet
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
}