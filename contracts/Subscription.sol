pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "SubscriptionIndex.sol";
import "../contracts/mTIP-3/mTONTokenWalletAbstract.sol";
import "libraries/SubscriptionErrors.sol";

interface IWallet  {
    function paySubscription (address serviceOwner, TvmCell params, TvmCell indificator) external;
}

interface ISubscriptionIndexContract {
    function cancel () external;
}

contract Subscription {

    address static serviceOwner;
    address static user_wallet;
    TvmCell static params;
    TvmCell static subscription_indificator;
    address static owner_address;
    uint8 constant STATUS_ACTIVE   = 1;
    uint8 constant STATUS_NONACTIVE = 2;
    address subscriptionIndexAddress;
    address subsIndificatorIndexAddr;
    uint32 cooldown = 0;

    struct ServiceParams {
        address to;
        uint128 value;
        uint32 period;
        string name;
        string description;
        TvmCell subscription_indificator;
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

    constructor(
        address senderAddress, 
        TvmCell walletCode, 
        address rootAddress, 
        address subsIndexAddr,
        address subsIndificatorIndexAddrINPUT
    ) 
        public 
    {
        optional(TvmCell) salt = tvm.codeSalt(tvm.code());
        require(salt.hasValue(), SubscriptionErrors.error_salt_is_empty);
        (address ownerAddress, address subsmanAddr, uint256 wallet_hash) = salt.get().toSlice().decode(address, address, uint256);
        require(msg.sender == subsmanAddr, SubscriptionErrors.error_message_sender_is_not_subsman);
        require(owner_address == ownerAddress && owner_address == senderAddress, SubscriptionErrors.error_define_owner_address_in_static_vars);
        require(wallet_hash == tvm.hash(walletCode), SubscriptionErrors.error_define_wallet_hash_in_salt);
        TvmCell walletStateInit = tvm.buildStateInit({
            code: walletCode,
            pubkey: 0,
            contr: TONTokenWalletAbstract,
            varInit: {
                root_address: rootAddress,
                code: walletCode,
                wallet_public_key: 0,
                owner_address: ownerAddress
            }
        });
        require(address(tvm.hash(walletStateInit)) == user_wallet, SubscriptionErrors.error_define_wallet_address_in_static_vars);
        require(msg.value >= 1 ton, SubscriptionErrors.error_not_enough_balance_in_message);
        (address to, uint128 value, uint32 period) = params.toSlice().decode(address, uint128, uint32);
        require(value > 0 && period > 0, SubscriptionErrors.error_incorrect_service_params);
        uint32 _period = period * 3600 * 24;
        subscription = Payment(to, value, _period, 0, STATUS_NONACTIVE);
        subscriptionIndexAddress = subsIndexAddr;
        subsIndificatorIndexAddr = subsIndificatorIndexAddrINPUT;
        svcparams.subscription_indificator = subscription_indificator;
        TvmCell nextCell;
        (
            svcparams.to, 
            svcparams.value, 
            svcparams.period, 
            nextCell
        ) = params.toSlice().decode(
            address, 
            uint128, 
            uint32, 
            TvmCell
        );
        TvmCell nextCell2;
        (
            svcparams.name, 
            svcparams.description, 
            svcparams.image, 
            nextCell2
        ) = nextCell.toSlice().decode(
            string, 
            string, 
            string, 
            TvmCell
        );
        (svcparams.currency, svcparams.category) = nextCell2.toSlice().decode(string, string);
        executeSubscriptionConstructor();
    }

    function executeSubscription() external {        
        if (now > (subscription.start + subscription.period)) {
            if ( now > (cooldown + 3600)) {
                tvm.accept();
                cooldown = uint32(now);
                subscription.status = STATUS_NONACTIVE;
                IWallet(user_wallet).paySubscription{
                    value: 0.5 ton, 
                    bounce: true, 
                    flag: 0
                }(
                    serviceOwner, 
                    params, 
                    subscription_indificator
                );
            }
        } else {
            require(subscription.status == STATUS_ACTIVE, SubscriptionErrors.error_subscription_status_already_active);
        }
    }

    function executeSubscriptionConstructor() private inline {        
        cooldown = uint32(now);
        subscription.status = STATUS_NONACTIVE;
        IWallet(user_wallet).paySubscription{
            value: 0.5 ton, 
            bounce: true, 
            flag: 0
        }(
            serviceOwner, 
            params, 
            subscription_indificator
        );
    }

    function onPaySubscription(uint8 status) external {
        if (status == 0 && user_wallet == msg.sender) {
            subscription.status = STATUS_ACTIVE;
            subscription.start = uint32(now);
        }
    }

    function cancel() public {
        require(msg.sender == owner_address, SubscriptionErrors.error_message_sender_is_not_index);
        ISubscriptionIndexContract(subscriptionIndexAddress).cancel();
        ISubscriptionIndexContract(subsIndificatorIndexAddr).cancel();
        selfdestruct(owner_address);
    }
}