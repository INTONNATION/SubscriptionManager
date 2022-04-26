pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "SubscriptionIndex.sol";
import "./Platform.sol";
import "interfaces/IEverduesAccount.sol";
import "interfaces/IEverduesIndex.sol";
import "interfaces/IEverduesSubscriptionService.sol";
import "interfaces/IEverduesSubscription.sol";
import "libraries/EverduesErrors.sol";
import "libraries/EverduesGas.sol";
import "libraries/MsgFlag.sol";
import "libraries/PlatformTypes.sol";
import "libraries/EverduesSubscriptionStatus.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenWallet.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenRoot.sol";

contract Subscription is IEverduesSubscription {
	TvmCell public service_params;
	address public root;
	address public address_fee_proxy;
	address public account_address;
	address public subscription_index_address;
	address public subscription_index_identificator_address;
	uint8   public service_fee;
	uint8   public subscription_fee;
	TvmCell platform_code;
	TvmCell platform_params;
	TvmCell contract_params;
	address subscription_wallet;
	address service_address;
	uint32 current_version;
	uint32 preprocessing_window;
	uint32 execute_subscription_cooldown = 3600;
	uint8 type_id;

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
		uint128 gas;
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

	function upgrade(
		TvmCell code,
		uint32 version,
		address send_gas_to
	) external onlyRoot {
		require(msg.value > EverduesGas.UPGRADE_SUBSCRIPTION_MIN_VALUE, 1111);
		TvmBuilder builder;
		builder.store(root);
		builder.store(send_gas_to);
		builder.store(current_version);
		builder.store(version);
		builder.store(type_id);
		builder.store(platform_code);
		builder.store(platform_params);
		builder.store(contract_params);
		builder.store(subscription);
		tvm.setcode(code);
		tvm.setCurrentCode(code);
		onCodeUpgrade(builder.toCell());
	}

	function subscriptionStatus() public override returns (uint8) {
		if (
			(subscription.status == EverduesSubscriptionStatus.STATUS_ACTIVE) &&
			(now < (subscription.payment_timestamp + svcparams.period))
		) {
			return EverduesSubscriptionStatus.STATUS_ACTIVE;
		} else if (
			(now > (subscription.payment_timestamp + svcparams.period)) &&
			(subscription.status != EverduesSubscriptionStatus.STATUS_PROCESSING)
		) {
			return EverduesSubscriptionStatus.STATUS_NONACTIVE;
		} else {
			return EverduesSubscriptionStatus.STATUS_PROCESSING;
		}
	}

	function executeSubscription(uint128 paySubscriptionGas) public override {
		if (
			now >
			(subscription.payment_timestamp +
				svcparams.period -
				preprocessing_window)
		) {
			if (
				(now > (subscription.execution_timestamp + execute_subscription_cooldown)) ||
				(subscription.status != EverduesSubscriptionStatus.STATUS_PROCESSING)
			) {
				tvm.accept();
				subscription.gas = paySubscriptionGas;
				subscription.execution_timestamp = uint32(now);
				IEverduesSubscriptionService(service_address).getInfo{
					value: EverduesGas.EXECUTE_SUBSCRIPTION_VALUE +
						subscription.gas,
					bounce: true,
					flag: 0,
					callback: Subscription.onGetInfo
				}();
			} else {
				revert(1000);
			}
		} else {
			require(
				subscription.status == EverduesSubscriptionStatus.STATUS_ACTIVE,
				EverduesErrors.error_subscription_status_already_active
			);
		}
	}

	function onGetInfo(TvmCell svc_info) external onlyService {
		tvm.rawReserve(
			math.max(
				EverduesGas.SUBSCRIPTION_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		uint8 status = svc_info.toSlice().decode(uint8);
		if (status == 0) {
			IEverduesAccount(account_address).paySubscription{
				value: 0,
				bounce: true,
				flag: MsgFlag.ALL_NOT_RESERVED,
				callback: Subscription.onPaySubscription
			}(
				svcparams.subscription_value,
				svcparams.currency_root,
				subscription_wallet,
				service_address,
				subscription.gas
			);
		} else {
			revert(EverduesErrors.error_subscription_status_already_active);
		}
	}

	function executeSubscription_() private inline {
		subscription.execution_timestamp = uint32(now);
		subscription.status = EverduesSubscriptionStatus.STATUS_PROCESSING;
		IEverduesAccount(account_address).paySubscription{
			value: EverduesGas.EXECUTE_SUBSCRIPTION_VALUE,
			bounce: true,
			flag: MsgFlag.SENDER_PAYS_FEES,
			callback: Subscription.onPaySubscription
		}(
			svcparams.subscription_value,
			svcparams.currency_root,
			subscription_wallet,
			service_address,
			subscription.gas
		);
		account_address.transfer({
			value: 0,
			flag: MsgFlag.REMAINING_GAS + MsgFlag.IGNORE_ERRORS
		});
	}

	function onAcceptTokensTransfer(
		address tokenRoot,
		uint128 amount,
		address sender,
		address senderWallet,
		address remainingGasTo,
		TvmCell payload
	) public {
		require(
			amount >= svcparams.service_value,
			EverduesErrors.error_not_enough_balance_in_message
		);
		uint128 service_value_percentage = svcparams.service_value / 100;
		uint128 service_fee_value = service_value_percentage * service_fee;
		uint128 protocol_fee = (svcparams.subscription_value -
			svcparams.service_value +
			service_fee_value);
		uint128 pay_value = svcparams.subscription_value - protocol_fee;
		if (subscription.payment_timestamp != 0) {
			subscription.payment_timestamp =
				subscription.payment_timestamp +
				subscription.period;
		} else {
			subscription.payment_timestamp = uint32(now);
		}
		subscription.status = EverduesSubscriptionStatus.STATUS_ACTIVE;
		ITokenWallet(msg.sender).transfer{
			value: EverduesGas.TRANSFER_MIN_VALUE,
			flag: MsgFlag.SENDER_PAYS_FEES
		}(protocol_fee, address_fee_proxy, 0, account_address, true, payload);
		ITokenWallet(msg.sender).transfer{
			value: 0,
			flag: MsgFlag.REMAINING_GAS
		}(pay_value, svcparams.to, 0, account_address, false, payload);
	}

	function onPaySubscription(uint8 status) external onlyAccount {
		if (status == 1) {
			subscription.status = EverduesSubscriptionStatus.STATUS_NONACTIVE;
		} else if (status == 0) {
			subscription.status = EverduesSubscriptionStatus.STATUS_PROCESSING;
		}
	}

	function onCodeUpgrade(TvmCell upgrade_data) private {
		tvm.rawReserve(EverduesGas.SUBSCRIPTION_INITIAL_BALANCE, 0);
		tvm.resetStorage();
		TvmSlice s = upgrade_data.toSlice();
		(
			address root_,
			address send_gas_to,
			uint32 old_version,
			uint32 version,
			uint8 type_id_
		) = s.decode(address, address, uint32, uint32, uint8);

		root = root_;
		current_version = version;
		type_id = type_id_;
		platform_code = s.loadRef();

		platform_params = s.loadRef();
		contract_params = s.loadRef();
		TvmCell nextCell;
		(service_address, account_address, nextCell) = contract_params
			.toSlice()
			.decode(address, address, TvmCell);
		(
			subscription_index_address,
			subscription_index_identificator_address,
			nextCell
		) = nextCell.toSlice().decode(address, address, TvmCell);
		(address_fee_proxy, service_fee, subscription_fee) = nextCell
			.toSlice()
			.decode(address, uint8, uint8);
		IEverduesSubscriptionService(service_address).getParams{
			value: 0,
			bounce: true,
			flag: MsgFlag.ALL_NOT_RESERVED,
			callback: Subscription.onGetParams
		}();
	}

	function onGetParams(TvmCell service_params_) external onlyService {
		TvmCell next_cell;
		service_params = service_params_;
		(
			svcparams.to,
			svcparams.service_value,
			svcparams.period,
			next_cell
		) = service_params.toSlice().decode(address, uint128, uint32, TvmCell);
		(
			svcparams.name,
			svcparams.description,
			svcparams.image,
			next_cell
		) = next_cell.toSlice().decode(string, string, string, TvmCell);
		(svcparams.currency_root, svcparams.category) = next_cell
			.toSlice()
			.decode(address, string);
		uint128 service_value_percentage = svcparams.service_value / 100;
		uint128 subscription_fee_value = service_value_percentage *
			subscription_fee;
		svcparams.subscription_value =
			svcparams.service_value +
			subscription_fee_value;
		preprocessing_window = (svcparams.period / 100) * 30;
		emit paramsRecieved(service_params_);
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
				flag: MsgFlag.REMAINING_GAS + MsgFlag.IGNORE_ERRORS
			});
		}
	}

	function cancel() external onlyRoot {
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

	function updateIdentificator(TvmCell code, address send_gas_to)
		external
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
		}(code, send_gas_to);
	}
}
