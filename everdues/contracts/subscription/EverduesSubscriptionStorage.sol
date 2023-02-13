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
	uint128 public totalPaid;
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
	bool notify;

	uint32 constant payment_processing_timeout = 3600 * 24;

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

	struct MetadataStruct {
		TvmCell subscription_params;
		serviceParams svcparams;
		address service_address;
		uint128 totalPaid;
		paymentStatus subscription;
		bool external_subscription;
		string external_token_address;
		string external_account_address;
		uint8 chain_id;
	}
			
	serviceParams public svcparams;
	paymentStatus public subscription;

	function getMetadata()
		external
		view
		returns (MetadataStruct
		)
	{
		MetadataStruct returned_data;

		returned_data.subscription_params = subscription_params;
		returned_data.svcparams = svcparams;
		returned_data.service_address = service_address;
		returned_data.totalPaid = totalPaid;
		returned_data.subscription = subscription;
		returned_data.external_subscription = external_subscription;
		returned_data.external_token_address = external_token_address;
		returned_data.external_account_address = external_account_address;
		returned_data.chain_id = chain_id;
		return returned_data;
	}

	function subscriptionStatus() public override returns (uint8) {
		if (subscription.payment_timestamp != 0 && subscription.period == 0) {
			return EverduesSubscriptionStatus.STATUS_ACTIVE;
		} else if (
			(now < (subscription.payment_timestamp)) &&
			(subscription.status !=
				EverduesSubscriptionStatus.STATUS_PROCESSING)
		) {
			return EverduesSubscriptionStatus.STATUS_ACTIVE;
		} else if (
			(now > (subscription.payment_timestamp)) &&
			(subscription.status !=
				EverduesSubscriptionStatus.STATUS_PROCESSING)
		) {
			return EverduesSubscriptionStatus.STATUS_NONACTIVE;
		} else if (
			now > (subscription.payment_timestamp - preprocessing_window) &&
			(subscription.status !=
				EverduesSubscriptionStatus.STATUS_PROCESSING)
		) {
			return EverduesSubscriptionStatus.STATUS_EXECUTE;
		} else if (
			(now - subscription.execution_timestamp) <
			payment_processing_timeout
		) {
			return EverduesSubscriptionStatus.STATUS_PROCESSING;
		} else {
			return EverduesSubscriptionStatus.STATUS_NONACTIVE;
		}
	}
}
