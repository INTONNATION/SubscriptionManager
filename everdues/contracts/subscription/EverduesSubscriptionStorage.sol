pragma ton-solidity >=0.56.0;

import "../../libraries/EverduesSubscriptionStatus.sol";
import "../../interfaces/IEverduesSubscription.sol";

abstract contract EverduesSubscriptionStorage is IEverduesSubscription {
	address public root;
	address public address_fee_proxy;
	address public account_address;
	uint256 public owner_pubkey;
	uint256 public service_pubkey;
	address public subscription_index_address;
	address public subscription_index_identificator_address;
	uint8 public service_fee;
	uint8 public subscription_fee;
	uint8 public subscription_plan;
	TvmCell public subscription_params;
	TvmCell public service_params;
	TvmCell public identificator;
	TvmCell platform_code;
	TvmCell platform_params;
	address subscription_wallet;
	address service_address;
	uint256 root_pubkey;
	uint32 current_version;
	uint32 preprocessing_window;
	uint8 type_id;
	bool compensate_subscription_deploy;

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

	struct paymentStatus {
		uint32 period;
		uint32 payment_timestamp;
		uint32 execution_timestamp;
		uint8 status;
		uint128 pay_subscription_gas;
	}

	serviceParams public svcparams;
	paymentStatus public subscription;

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
}
