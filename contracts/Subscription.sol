pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "SubscriptionIndex.sol";
import "libraries/SubscriptionErrors.sol";

import "./Platform.sol";
import "libraries/PlatformTypes.sol";
import "TIP3/interfaces/ITokenWallet.sol";


interface IMetaduesAccount  {
    function paySubscription (TvmCell params, address account_wallet, address subscription_wallet) external;
}

interface ISubscriptionIndexContract {
    function cancel () external;
}

contract Subscription {

    address public root;
    TvmCell platform_code;
    TvmCell platform_params;
    uint32 current_version;
    uint8 type_id;
    TvmCell service_params;
    
    address static serviceOwner;
    address static user_wallet;
    
    TvmCell static subscription_identificator;
    TvmCell public Tvm_code;
    optional(TvmCell) public Tvm_code_salt;
    address static owner_address;
    uint8 constant STATUS_ACTIVE = 1;
    uint8 constant STATUS_NONACTIVE = 2;
    address subscriptionIndexAddress;
    address subsidentificatorIndexAddr;
    uint32 cooldown = 0;

    struct ServiceParams {
        address to;
        uint128 value;
        uint32 period;
        string name;
        string description;
        TvmCell subscription_identificator;
        string image;
        string currency;
        string category;
    }
    ServiceParams public svcparams;
    struct Payment {
        address to;
        uint128 value;
        uint32 period;
        uint32 start;
        uint8 status;
    }
    Payment public subscription;

    constructor() public { revert(); }
 


    function executeSubscription() external {        
        if (now > (subscription.start + subscription.period)) {
            if ( now > (cooldown + 3600)) {
                tvm.accept();
                cooldown = uint32(now);
                subscription.status = STATUS_NONACTIVE;
                // ITokenWallet(user_wallet).paySubscription{
                //     value: 0.2 ton, 
                //     bounce: true, 
                //     flag: 0
                // }(
                //     serviceOwner, 
                //     svcparams, 
                //     subscription_identificator
                // );
            }
        } else {
            require(subscription.status == STATUS_ACTIVE, SubscriptionErrors.error_subscription_status_already_active);
        }
    }

    function executeSubscriptionConstructor() private inline {        
        cooldown = uint32(now);
        subscription.status = STATUS_NONACTIVE;
        // ITokenWallet(user_wallet).paySubscription{
        //     value: 0.2 ton, 
        //     bounce: true, 
        //     flag: 0
        // }(
        //     serviceOwner, 
        //     svcparams, 
        //     subscription_identificator
        // );
    }

    function onPaySubscription(uint8 status) external {
        if (status == 0 && user_wallet == msg.sender) {
            subscription.status = STATUS_ACTIVE;
            subscription.start = uint32(now);
        }
    }
    
    function onCodeUpgrade(TvmCell upgrade_data) private {
        
        TvmSlice s = upgrade_data.toSlice();
        (address root_, address send_gas_to, uint32 old_version, uint32 version, uint8 type_id_ ) =
        s.decode(address,address,uint32,uint32,uint8);

        if (old_version == 0) {
            tvm.resetStorage();
        }

        root = root_;
        platform_code = s.loadRef();
        platform_params = s.loadRef();   
        current_version = version;  
        type_id = type_id_;
        TvmCell subscription_code = s.loadRef();
        optional(TvmCell) salt = tvm.codeSalt(subscription_code);
       
       Tvm_code_salt = salt;
       Tvm_code = subscription_code;
    //    require(salt.hasValue(), SubscriptionErrors.error_salt_is_empty);
    //    (service_params) = salt.get().toSlice().decode(TvmCell);
    //    TvmCell nextCell;
    //     (
    //         svcparams.to, 
    //         svcparams.value, 
    //         svcparams.period, 
    //         nextCell
    //     ) = service_params.toSlice().decode(
    //         address, 
    //         uint128, 
    //         uint32, 
    //         TvmCell
    //     );
    //     TvmCell nextCell2;
    //     (
    //         svcparams.name, 
    //         svcparams.description, 
    //         svcparams.image, 
    //         nextCell2
    //     ) = nextCell.toSlice().decode(
    //         string, 
    //         string, 
    //         string, 
    //         TvmCell
    //     );
    //     (svcparams.currency, svcparams.category) = nextCell2.toSlice().decode(string, string);
    //     uint32 _period = svcparams.period * 3600 * 24;
    //     subscription = Payment(svcparams.to, svcparams.value, _period, 0, STATUS_NONACTIVE);
    //  subscriptionIndexAddress = subsIndexAddr;
    //  subsidentificatorIndexAddr = subsidentificatorIndexAddrINPUT;
    //  svcparams.subscription_identificator = subscription_identificator;
        executeSubscriptionConstructor();
  
        send_gas_to.transfer({ value: 0, flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS });
    }
    function cancel() public {
        require(msg.sender == owner_address, SubscriptionErrors.error_message_sender_is_not_index);
        ISubscriptionIndexContract(subscriptionIndexAddress).cancel();
        ISubscriptionIndexContract(subsidentificatorIndexAddr).cancel();
        selfdestruct(owner_address);
    }
}