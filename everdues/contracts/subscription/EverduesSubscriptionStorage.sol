pragma ton-solidity >=0.56.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

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
	uint256 public abi_hash;
	uint256 public root_pubkey;
	TvmCell platform_code;
	TvmCell platform_params;
	address subscription_wallet;
	address service_address;
	uint32 current_version;
	uint32 preprocessing_window;
	uint8 type_id;
	bool compensate_subscription_deploy;
	bool external_subscription;
	uint8 chain_id;
	string external_account_address;
	string external_token_address;
	string external_payee;
	address cross_chain_token;

	uint32 constant payment_processing_timeout = 3600;

	struct serviceParams {
		address from,
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
		uint128 account_gas_balance;
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
		} else if (
			now >
			(subscription.payment_timestamp +
				svcparams.period -
				preprocessing_window) &&
			(subscription.status !=
				EverduesSubscriptionStatus.STATUS_PROCESSING)
		) {
			return EverduesSubscriptionStatus.STATUS_EXECUTE;
		} else {
			return EverduesSubscriptionStatus.STATUS_PROCESSING;
		}
	}
}
