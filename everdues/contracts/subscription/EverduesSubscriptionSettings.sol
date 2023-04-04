pragma ton-solidity >=0.56.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./EverduesSubscriptionStorage.sol";

import "../../interfaces/IEverduesIndex.sol";

import "../../libraries/EverduesErrors.sol";
import "../../libraries/EverduesGas.sol";
import "../../libraries/MsgFlag.sol";
import "../../interfaces/IEverduesSubscription.sol";

abstract contract EverduesSubscriptionSettings is EverduesSubscriptionStorage {
	event paramsRecieved(TvmCell service_params_);
	event SubscriptionDeleted();
	event SubscriptionExecuted();
	event SubscriptionStopped();
	
	modifier onlyRoot() {
		require(
			msg.sender == root,
			EverduesErrors.error_message_sender_is_not_everdues_root
		);
		_;
	}

	modifier onlyRootKey() {
		require(
			msg.pubkey() == root_pubkey,
			EverduesErrors.error_message_sender_is_not_everdues_root
		);
		tvm.accept();
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
			(msg.sender == root ||
				msg.pubkey() == owner_pubkey),
			EverduesErrors.error_message_sender_is_not_owner
		);
		_;
	}

	modifier onlyRootOrServiceOrOwner() {
		require(
			(msg.pubkey() == root_pubkey ||
				msg.pubkey() == owner_pubkey ||
				msg.pubkey() == service_pubkey),
			EverduesErrors.error_message_sender_is_not_owner
		);
		_;
	}

	modifier onlyOwner() {
		require(
			msg.pubkey() == owner_pubkey,
			EverduesErrors.error_message_sender_is_not_owner
		);
		_;
	}

	function stopSubscription(address send_gas_to) external onlyRoot {
		tvm.rawReserve(
			math.max(
				EverduesGas.SUBSCRIPTION_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		subscription.status = EverduesSubscriptionStatus.STATUS_STOPPED;
		emit SubscriptionStopped();
		send_gas_to.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function resumeSubscription() external onlyOwner {
		tvm.accept();
		subscription.status = subscriptionStatus();
	}

	function updateIdentificator(TvmCell index_data) external view onlyOwner {
		tvm.accept();
		IEverduesIndex(subscription_index_identificator_address)
			.updateIndexData{
			value: EverduesGas.MESSAGE_MIN_VALUE,
			bounce: true,
			flag: 0
		}(index_data, address(this));
	}
}
