pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "SubscriptionIndex.sol";
import "./Platform.sol";
import "libraries/MetaduesErrors.sol";
import "libraries/MetaduesGas.sol";
import "libraries/MsgFlag.sol";
import "libraries/PlatformTypes.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenWallet.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenRoot.sol";

interface IMetaduesAccount {
    function paySubscription(
        uint128 value,
        address currency_root,
        address account_wallet,
        address subscription_wallet,
        address service_address,
        uint128 pay_subscription_gas
    ) external responsible returns (uint8);
}

interface ISubscriptionService {
    function getParams() external view responsible returns (TvmCell);
    function getInfo() external view responsible returns (TvmCell);
}

interface ISubscriptionIndexContract {
    function cancel() external;
}

interface ISubscriptionIdentificatorIndexContract {
    function upgrade(TvmCell code, address send_gas_to) external;
}

contract Subscription {
    address public root;
    address public owner_address;
    TvmCell platform_code;
    TvmCell platform_params;
    uint32 current_version;
    uint8 type_id;
    TvmCell public service_params;
    address subscription_wallet;
    address account_wallet;
    address account_address;
    uint8 constant STATUS_ACTIVE = 1;
    uint8 constant STATUS_NONACTIVE = 2;
    uint8 constant STATUS_PROCESSING = 3;
    address service_address;
    address public subscription_index_address;
    address public subscription_index_identificator_address;
    uint32 cooldown = 3600;
    uint8 public service_fee;
    uint8 public subscription_fee;
    address public address_fee_proxy;
    TvmCell contract_params;
    uint32 preprocessing_window;

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

    event paramsRecieved(TvmCell service_params_);

    modifier onlyRoot() {
        require(msg.sender == root, MetaduesErrors.error_message_sender_is_not_metadues_root);
        _;
    }

    modifier onlyOwner() {
        //require(msg.sender == owner_address, MetaduesErrors.error_message_sender_is_not_owner); // need fix | is 0:00000 now
        _;
    }

    modifier onlyService() {
        _;
    }

    modifier onlyCurrencyRoot() {
        require(msg.sender == svcparams.currency_root, MetaduesErrors.error_message_sender_is_not_currency_root);
        _;
    }

    function upgrade(
        TvmCell code,
        uint32 version,
        address send_gas_to
    ) external onlyRoot {
        require(msg.value > MetaduesGas.UPGRADE_SUBSCRIPTION_MIN_VALUE, 1111);

        tvm.rawReserve(MetaduesGas.SUBSCRIPTION_INITIAL_BALANCE, 2);
        TvmBuilder builder;
        TvmBuilder upgrade_params;
        builder.store(root);
        builder.store(send_gas_to);
        builder.store(current_version);
        builder.store(version);
        builder.store(type_id);
        builder.store(platform_code);
        builder.store(platform_params);
        builder.store(code);
        upgrade_params.store(contract_params);
        upgrade_params.store(subscription);
        builder.store(upgrade_params.toCell());

        tvm.setcode(code);
        tvm.setCurrentCode(code);
        onCodeUpgrade(builder.toCell());
    }

    function subscriptionStatus() public returns (uint8) {
        if (
            (subscription.status == STATUS_ACTIVE) &&
            (now < (subscription.payment_timestamp + svcparams.period))
        ) {
            return STATUS_ACTIVE;
        } else if (
            (now > (subscription.payment_timestamp + svcparams.period)) &&
            (subscription.status != STATUS_PROCESSING)
        ) {
            return STATUS_NONACTIVE;
        } else {
            return STATUS_PROCESSING;
        }
    }

    function executeSubscription(uint128 paySubscriptionGas) public {
        if (
            now >
            (subscription.payment_timestamp +
                svcparams.period -
                preprocessing_window)
        ) {
            if (
                (now > (subscription.execution_timestamp + cooldown)) ||
                (subscription.status != STATUS_PROCESSING)
            ) {
                tvm.accept();
                subscription.gas = paySubscriptionGas;
                subscription.execution_timestamp = uint32(now);
                ISubscriptionService(service_address).getInfo{
                    value: MetaduesGas.EXECUTE_SUBSCRIPTION_VALUE + subscription.gas,
                    bounce: true, // need to handle
                    flag: 0,
                    callback: Subscription.onGetInfo           
                }();
            } else {
                revert(1000);
            }
        } else {
            require(
                subscription.status == STATUS_ACTIVE,
                MetaduesErrors.error_subscription_status_already_active
            );
        }
    }

    function onGetInfo(TvmCell svc_info) external onlyService {
        tvm.rawReserve(
            math.max(
                MetaduesGas.SUBSCRIPTION_INITIAL_BALANCE,
                address(this).balance - msg.value
            ),
            2
        );
        uint8 status = svc_info.toSlice().decode(uint8);
        if (status == 0){
            IMetaduesAccount(account_address).paySubscription{
                value: 0,
                bounce: true,
                flag: MsgFlag.ALL_NOT_RESERVED,
                callback: Subscription.onPaySubscription
            }(
                svcparams.subscription_value,
                svcparams.currency_root,
                account_wallet,
                subscription_wallet,
                service_address,
                subscription.gas
            );
        } else {
            revert(MetaduesErrors.error_subscription_status_already_active);
        }
    }

    function executeSubscriptionInline() private inline {
        subscription.execution_timestamp = uint32(now);
        subscription.status = STATUS_PROCESSING;
        IMetaduesAccount(account_address).paySubscription{
            value: 0,
            bounce: true,
            flag: MsgFlag.ALL_NOT_RESERVED,
            callback: Subscription.onPaySubscription
        }(
            svcparams.subscription_value,
            svcparams.currency_root,
            account_wallet,
            subscription_wallet,
            service_address,
            subscription.gas
        );
    }

    function onAcceptTokensTransfer(
        address tokenRoot,
        uint128 amount,
        address sender,
        address senderWallet,
        address remainingGasTo,
        TvmCell payload
    ) public {
        tvm.rawReserve(
            math.max(
                MetaduesGas.SUBSCRIPTION_INITIAL_BALANCE,
                address(this).balance - msg.value
            ),
            2
        );
        require(amount >= svcparams.service_value, MetaduesErrors.error_not_enough_balance_in_message);
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
        subscription.status = STATUS_ACTIVE;
        ITokenWallet(msg.sender).transfer{
            value: MetaduesGas.TRANSFER_MIN_VALUE,
            flag: MsgFlag.SENDER_PAYS_FEES
        }(
            protocol_fee,
            address_fee_proxy,
            0,
            account_address,
            true,
            payload
        );
        ITokenWallet(msg.sender).transfer{
            value: 0,
            flag: MsgFlag.ALL_NOT_RESERVED
        }(
            pay_value,
            svcparams.to,
            0,
            account_address,
            false,
            payload
        );
    }

    function onPaySubscription(uint8 status) external {
        require(msg.sender == account_address, MetaduesErrors.error_message_sender_is_not_my_owner);
        // allow onlylAccount
        if (status == 1) {
            subscription.status = STATUS_NONACTIVE;
        } else if (status == 0) {
            subscription.status = STATUS_PROCESSING;
        }
    }

    function onCodeUpgrade(TvmCell upgrade_data) private {
        tvm.rawReserve(MetaduesGas.SUBSCRIPTION_INITIAL_BALANCE, 0);
        tvm.resetStorage();
        TvmSlice s = upgrade_data.toSlice();
        (
            address root_,
            address send_gas_to,
            uint32 old_version,
            uint32 version,
            uint8 type_id_
        ) = s.decode(address, address, uint32, uint32, uint8);
        owner_address = send_gas_to;


        root = root_;
        current_version = version;
        type_id = type_id_;
        platform_code = s.loadRef();

        TvmSlice platform_params = s.loadRefAsSlice();
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
        ISubscriptionService(service_address).getParams{
            value: 0,
            bounce: true,
            flag: MsgFlag.ALL_NOT_RESERVED,
            callback: Subscription.onGetParams
        }();
    }

    function onGetParams(TvmCell service_params_) external onlyService {
        tvm.rawReserve(MetaduesGas.SUBSCRIPTION_INITIAL_BALANCE, 0);
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
        subscription = paymentStatus(svcparams.period, 0, 0, STATUS_NONACTIVE, 0);
        ITokenRoot(svcparams.currency_root).deployWallet{
            value: 0,
            bounce: false,
            flag: MsgFlag.ALL_NOT_RESERVED,
            callback: Subscription.onDeployWallet
        }(address(this), MetaduesGas.DEPLOY_EMPTY_WALLET_GRAMS);
    }

    function onDeployWallet(address subscription_wallet_) external onlyCurrencyRoot {
        tvm.rawReserve(MetaduesGas.SUBSCRIPTION_INITIAL_BALANCE, 0);
        subscription_wallet = subscription_wallet_;
        ITokenRoot(svcparams.currency_root).walletOf{
            value: 0,
            bounce: false,
            flag: MsgFlag.ALL_NOT_RESERVED,
            callback: Subscription.onWalletOf
        }(account_address);
    }

    function onWalletOf(address account_wallet_) external onlyCurrencyRoot {
        tvm.rawReserve(MetaduesGas.SUBSCRIPTION_INITIAL_BALANCE, 0);
        account_wallet = account_wallet_;
        if (subscription.payment_timestamp == 0) {
            executeSubscriptionInline();
        } else {
            owner_address.transfer({ value: 0, flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS });
        }
    }

    function cancel(uint128 grams) external onlyOwner {
        ISubscriptionIndexContract(subscription_index_address).cancel{
            value: grams,
            flag: MsgFlag.SENDER_PAYS_FEES
        }();
        ISubscriptionIndexContract(subscription_index_identificator_address).cancel{
            value: grams,
            flag: MsgFlag.SENDER_PAYS_FEES
        }();
        selfdestruct(owner_address);
    }

    function upgradeIdentificatorIndex(TvmCell code, address send_gas_to)
        public
        onlyOwner
    {
        tvm.rawReserve(
            math.max(
                MetaduesGas.SUBSCRIPTION_INITIAL_BALANCE,
                address(this).balance - msg.value
            ),
            2
        );
        ISubscriptionIdentificatorIndexContract(
            subscription_index_identificator_address
        ).upgrade{
            value: 0,
            bounce: true, // handle
            flag: MsgFlag.ALL_NOT_RESERVED       
        }(code, send_gas_to);
    }
}
