pragma ton-solidity >=0.56.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../../libraries/EverduesSubscriptionStatus.sol";
import "../../interfaces/IEverduesSubscription.sol";

abstract contract EverduesSubscriptionStorage {
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
	uint32 public preprocessing_window;
	uint8 type_id;
	bool compensate_subscription_deploy;
	bool external_subscription;
	uint32 chain_id;
	string external_account_address;
	string external_token_address;
	string external_payee;
	address cross_chain_token;
	bool notify;
	string ipfs_hash;

	uint32 constant public payment_processing_timeout = 3600 * 24;

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
		uint32 registation_timestamp;
	}

	struct paymentStatusOld {
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
		uint32 chain_id;
		TvmCell identificator;
		address account_address;
		bool notify;
		uint256 owner_pubkey;
		uint8 subscriptionStatus;
		string ipfs_hash;
	}
			
	serviceParams public svcparams;
	paymentStatus public subscription;

	function getMetadata()
		external
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
		returned_data.identificator = identificator;
		returned_data.account_address = account_address;
		returned_data.notify = notify;
		returned_data.owner_pubkey = owner_pubkey;
		returned_data.subscriptionStatus = subscriptionStatus();
		returned_data.ipfs_hash = ipfs_hash;
		return returned_data;
	}

	function subscriptionStatus() public returns (uint8) {
		if (subscription.status !=
			EverduesSubscriptionStatus.STATUS_STOPPED) {
			if (subscription.payment_timestamp != 0 && subscription.period == 0) {
				return EverduesSubscriptionStatus.STATUS_ACTIVE;
			} else if (
				(now < (subscription.payment_timestamp)) &&
				(subscription.status !=
					EverduesSubscriptionStatus.STATUS_PROCESSING)
			) {
				if (
					now > (subscription.payment_timestamp - preprocessing_window) &&
					(subscription.status !=
						EverduesSubscriptionStatus.STATUS_PROCESSING)
					) {
						return EverduesSubscriptionStatus.STATUS_EXECUTE;
				} else {
					return EverduesSubscriptionStatus.STATUS_ACTIVE;
				}
			} else if (
				(now > (subscription.payment_timestamp)) &&
				(subscription.status !=
					EverduesSubscriptionStatus.STATUS_PROCESSING)
			) {
				return EverduesSubscriptionStatus.STATUS_NONACTIVE;
			} else if (
				(now - subscription.execution_timestamp) <
				payment_processing_timeout
			) {
				return EverduesSubscriptionStatus.STATUS_PROCESSING;
			} else {
				return EverduesSubscriptionStatus.STATUS_NONACTIVE;
			}
		} else if (now > (subscription.payment_timestamp)) {
			return EverduesSubscriptionStatus.STATUS_STOPPED;
		} else {
			return EverduesSubscriptionStatus.STATUS_ACTIVE;
		}
	}
}