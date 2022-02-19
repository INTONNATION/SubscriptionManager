pragma ton-solidity >= 0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "SubscriptionIndex.sol";
import "libraries/SubscriptionErrors.sol";

import "./Platform.sol";
import "libraries/PlatformTypes.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenWallet.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenRoot.sol";


interface IMetaduesAccount  {
    function paySubscription (TvmCell params, address account_wallet, address subscription_wallet, address service_address) external responsible returns (uint8);
}

interface ISubscriptionService  {
    function getParams() external view responsible returns (TvmCell);
}



interface ISubscriptionIndexContract {
    function cancel () external;
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
    address subscription_index_address;
    address subscription_index_identificator_address;
    uint32 cooldown = 0;
    uint128 public service_fee;
    uint128 public subscription_fee;
    address public address_fee_proxy;
    TvmCell contract_params;

    struct serviceParams {
        address to;
        uint128 value;
        uint32 period;
        string name;
        string description;
        TvmCell subscription_identificator;
        string image;
        address currency_root;
        string category;
    }
    serviceParams public svcparams;

    struct paymentStatus {
        uint32 period;
        uint32 start;
        uint8 status;
    }
    paymentStatus public subscription;

    constructor() public { revert(); }

    event paramsRecieved(TvmCell service_params_);

    modifier onlyRoot() {
        require(msg.sender == root, 111);
        _;
    }

    function upgrade(TvmCell code, uint32 version, address send_gas_to) external onlyRoot {
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
    
    
    
    
    function executeSubscription() external {        
        if (now > (subscription.start + svcparams.period)) {
            if ( now > (cooldown + 3600)) {
                tvm.accept();
                cooldown = uint32(now);
                subscription.status = STATUS_NONACTIVE;
                IMetaduesAccount(account_address).paySubscription{
                    value: 0.2 ton, 
                    bounce: true,
                    flag: 0,
                    callback: Subscription.onPaySubscription
                }(
                    service_params,
                    account_wallet,
                    subscription_wallet,
                    service_address
                );
            }
        } else {
            require(subscription.status == STATUS_ACTIVE, SubscriptionErrors.error_subscription_status_already_active);
        }
    }

    function executeSubscriptionInline() private inline {        
        cooldown = uint32(now);
        subscription.status = STATUS_NONACTIVE;
        IMetaduesAccount(account_address).paySubscription{
            value: 0.2 ton, 
            bounce: true, 
            flag: 0,
            callback: Subscription.onPaySubscription
        }(
            service_params, 
            account_wallet, 
            subscription_wallet,
            service_address
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
        if (subscription.status == STATUS_PROCESSING){
          uint128 protocol_fee = svcparams.value * (service_fee + subscription_fee) / 100;
          ITokenWallet(msg.sender).transferToWallet{value: 0.5 ton}(
            protocol_fee,
            address_fee_proxy,
            address_fee_proxy,  
            true, 
            payload
            );   
          uint128 pay_value = svcparams.value - protocol_fee;
          ITokenWallet(msg.sender).transfer{value: 0.5 ton}(
            //add fee for proxy TIP-3
            pay_value,
            svcparams.to, // can be service owner TIP3 Wallet
            0,
            address(this),
            true,
            payload
            );
            subscription.status = STATUS_ACTIVE;
            }
    }
    
    function onPaySubscription(uint8 status) external {
        if (status == 0) {
            subscription.status = STATUS_PROCESSING;
        } else if (status == 1) {
            subscription.status = STATUS_NONACTIVE;
        }
    }
    
    function onCodeUpgrade(TvmCell upgrade_data) private {
        TvmSlice s = upgrade_data.toSlice();
        (address root_, address send_gas_to, uint32 old_version, uint32 version, uint8 type_id_ ) =
        s.decode(address,address,uint32,uint32,uint8);
        owner_address = send_gas_to;

        if (old_version == 0) {
            tvm.resetStorage();
        }

        root = root_;
        current_version = version;  
        type_id = type_id_;
        platform_code = s.loadRef();

        TvmSlice platform_params = s.loadRefAsSlice();
        contract_params = s.loadRef();
        TvmCell nextCell;
        (service_address, account_address, nextCell) = contract_params.toSlice().decode(address,address,TvmCell);
        (subscription_index_address,subscription_index_identificator_address, nextCell) = nextCell.toSlice().decode(address,address,TvmCell);
        (address_fee_proxy,service_fee,subscription_fee ) = nextCell.toSlice().decode(address,uint128,uint128);
        ISubscriptionService(service_address).getParams{
            value: 0.2 ton, 
            bounce: true, 
            flag: 0,
            callback: Subscription.onGetParams
        }(
        );
         //send_gas_to.transfer({ value: 0, flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS });
    }

    function onGetParams(TvmCell service_params_) external {
        TvmCell next_cell;
        service_params=service_params_;
        (
            svcparams.to, 
            svcparams.value, //add percentage for user fee
            svcparams.period,
            next_cell
        ) = service_params.toSlice().decode(
            address, 
            uint128, 
            uint32,
            TvmCell
        );
 
        (
            svcparams.name, 
            svcparams.description, 
            svcparams.image,
            next_cell
        ) = next_cell.toSlice().decode(
            string, 
            string, 
            string,
            TvmCell
        );
        (svcparams.currency_root, svcparams.category) = next_cell.toSlice().decode(address, string);
        svcparams.value = svcparams.value + subscription_fee;
        uint32 _period = svcparams.period * 3600 * 24;
        emit paramsRecieved(service_params_);
        subscription = paymentStatus(_period, 0, STATUS_NONACTIVE);
        ITokenRoot(svcparams.currency_root).deployWallet{
            value: 0.2 ton, 
            bounce: true, 
            flag: 0,
            callback: Subscription.onDeployWallet
        }(
            address(this),
            0.1 ton
        );
    }

    function onDeployWallet(address subscription_wallet_) external {
        subscription_wallet = subscription_wallet_;
        ITokenRoot(svcparams.currency_root).walletOf{
             value: 0.1 ton, 
             bounce: true,
             flag: 0,
             callback: Subscription.onWalletOf
        }(account_address);
    }

    function onWalletOf(address account_wallet_) external {
        account_wallet = account_wallet_;
        executeSubscriptionInline();
    }

    function cancel() public {
        //require(msg.sender == owner_address, SubscriptionErrors.error_message_sender_is_not_owner); // need fix | is 0:00000 now
        ISubscriptionIndexContract(subscription_index_address).cancel();
        ISubscriptionIndexContract(subscription_index_identificator_address).cancel();
        selfdestruct(owner_address);
    }
}