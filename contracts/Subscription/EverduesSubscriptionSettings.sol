pragma ton-solidity >=0.56.0;

import "./EverduesSubscriptionStorage.sol";

import "../interfaces/IEverduesService.sol";
import "../interfaces/IEverduesIndex.sol";

import "../libraries/EverduesErrors.sol";
import "../libraries/EverduesGas.sol";
import "../libraries/MsgFlag.sol";

abstract contract EverduesSubscriptionSettings is EverduesSubscriptionStorage {
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
		require(msg.pubkey() == owner_pubkey, EverduesErrors.error_message_sender_is_not_owner);
		_;
	}

	function stopSubscription() external onlyOwner {
		tvm.accept();
		subscription.status = EverduesSubscriptionStatus.STATUS_STOPPED;
	}

	function resumeSubscription() external onlyOwner {
		tvm.accept();
		subscription.status = EverduesSubscriptionStatus.STATUS_NONACTIVE;
	}

	function cancel() external onlyOwner {
		tvm.accept();
		emit SubscriptionDeleted();
		IEverduesIndex(subscription_index_address).cancel{
			value: EverduesGas.MESSAGE_MIN_VALUE,
			flag: MsgFlag.SENDER_PAYS_FEES
		}();
		IEverduesIndex(subscription_index_identificator_address).cancel{
			value: EverduesGas.MESSAGE_MIN_VALUE,
			flag: MsgFlag.SENDER_PAYS_FEES
		}();
		selfdestruct(account_address);
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
