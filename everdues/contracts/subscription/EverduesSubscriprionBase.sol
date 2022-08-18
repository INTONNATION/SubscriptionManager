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

	function executeSubscription_(uint128 additional_gas) private {
		subscription.pay_subscription_gas = additional_gas;
		subscription.execution_timestamp = uint32(now);
		IEverduesService(service_address).getInfo{
			value: EverduesGas.EXECUTE_SUBSCRIPTION_VALUE + additional_gas,
			bounce: true,
			flag: 0,
			callback: EverduesSubscriprionBase.onGetInfo
		}();
	}

	function executeSubscription(uint128 additional_gas)
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
		if (subscription.period != 0) {
			if (
				now >
				(subscription.payment_timestamp +
					svcparams.period -
					preprocessing_window)
			) {
				tvm.accept();
				uint8 subcr_status = subscriptionStatus();
				require(
					subcr_status !=
						EverduesSubscriptionStatus.STATUS_PROCESSING &&
						subcr_status !=
						EverduesSubscriptionStatus.STATUS_ACTIVE,
					EverduesErrors.error_subscription_already_executed
				); // optinal(add processing timeout (e.q few hours))
				executeSubscription_(additional_gas);
			} else {
				revert(EverduesErrors.error_subscription_status_already_active);
			}
		} else {
			if (
				subscription.status == EverduesSubscriptionStatus.STATUS_ACTIVE
			) {
				revert(EverduesErrors.error_subscription_status_already_active);
			} else if (
				subscription.status ==
				EverduesSubscriptionStatus.STATUS_PROCESSING
			) {
				revert(EverduesErrors.error_subscription_already_executed); // optinal(add processing timeout (e.q 1 day))
			} else {
				tvm.accept();
				executeSubscription_(additional_gas);
			}
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

	function executeSubscriptionOnDeploy() private inline {
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
			amount >= svcparams.subscription_value,
			EverduesErrors.error_message_low_value
		);
		require(
			msg.sender == subscription_wallet,
			EverduesErrors.error_message_sender_is_not_subscription_wallet
		);
		tvm.rawReserve(
			math.max(
				EverduesGas.ACCOUNT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		tvm.rawReserve(EverduesGas.SUBSCRIPTION_INITIAL_BALANCE, 2);
		uint128 account_compensation_fee = abi.decode(payload, (uint128));
		uint128 service_value_percentage = svcparams.service_value / 100;
		uint128 service_fee_value = service_value_percentage * service_fee;
		uint128 protocol_fee = ((svcparams.subscription_value -
			svcparams.service_value) +
			(amount - svcparams.subscription_value) +
			service_fee_value +
			account_compensation_fee);
		if (protocol_fee > amount) {
			ITokenWallet(msg.sender).transfer{
				value: EverduesGas.TRANSFER_MIN_VALUE,
				flag: MsgFlag.SENDER_PAYS_FEES
			}(amount, address_fee_proxy, 0, address_fee_proxy, true, payload);
		} else {
			uint128 pay_value = svcparams.subscription_value - protocol_fee;
			ITokenWallet(msg.sender).transfer{
				value: EverduesGas.TRANSFER_MIN_VALUE,
				flag: MsgFlag.SENDER_PAYS_FEES
			}(
				protocol_fee,
				address_fee_proxy,
				0,
				address_fee_proxy,
				true,
				payload
			);
			ITokenWallet(msg.sender).transfer{
				value: 0,
				flag: MsgFlag.ALL_NOT_RESERVED
			}(
				pay_value,
				svcparams.to,
				0, // TODO: add EverduesGas.DEPLOY_EMPTY_WALLET_GRAMS or fix in case multicurrencies support
				address_fee_proxy,
				true,
				payload
			);
		}
		subscription.payment_timestamp = uint32(now) + subscription.period;
		subscription.status = EverduesSubscriptionStatus.STATUS_ACTIVE;
		compensate_subscription_deploy = false;
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
				compensate_subscription_deploy,
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
			svcparams.category,

		) = abi.decode(
			service_params,
			(address, string, string, string, string, uint256)
		);
		(
			svcparams.service_value,
			svcparams.period,
			svcparams.currency_root,

		) = abi.decode(subscription_params, (uint128, uint32, address, string));
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
			executeSubscriptionOnDeploy();
		} else {
			account_address.transfer({
				value: 0,
				bounce: false,
				flag: MsgFlag.REMAINING_GAS + MsgFlag.IGNORE_ERRORS
			});
		}
	}
}
