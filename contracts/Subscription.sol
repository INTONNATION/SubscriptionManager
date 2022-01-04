pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "SubscriptionIndex.sol";
import "../contracts/mTIP-3/mTONTokenWalletAbstract.sol";
import "libraries/SubscriptionErrors.sol";


interface IWallet  {
    function paySubscription (address serviceOwner, TvmCell params, TvmCell indificator) external responsible returns (uint8);
}


contract Subscription {

    address static public serviceOwner;
    address static public user_wallet;
    TvmCell static public params;
    TvmCell static public subscription_indificator;
    address static public owner_address;
    uint8 constant STATUS_ACTIVE   = 1;
    uint8 constant STATUS_NONACTIVE = 2;
    address public subscriptionIndexAddress;
    struct Payment {
        address to;
        uint128 value;
        uint32 period;
        uint32 start;
        uint8 status;
    }
    Payment public subscription;

    uint256 public debug_wallet_hash;
    uint256 public debug_wallet_hash2;
    
    constructor(
        address senderAddress, 
        TvmCell walletCode, 
        address rootAddress, 
        address subsIndexAddr
    ) 
        public 
    {
        optional(TvmCell) salt = tvm.codeSalt(tvm.code());
        require(salt.hasValue(), SubscriptionErrors.error_salt_is_empty);
        (, , uint256 wallet_hash, TvmCell Addrs) = salt.get().toSlice().decode(address, TvmCell, uint256, TvmCell);
        (, address ownerAddress, address subsmanAddr) = Addrs.toSlice().decode(address, address, address);
        require(msg.sender == subsmanAddr, SubscriptionErrors.error_message_sender_is_not_subsman);
        require(owner_address == ownerAddress &&  owner_address == senderAddress, SubscriptionErrors.error_define_owner_address_in_static_vars);
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
    }

    function cancel() public {
        require(msg.sender == subscriptionIndexAddress, SubscriptionErrors.error_message_sender_is_not_index);
        selfdestruct(user_wallet);
    }

    function executeSubscription() public {        
        if (now > (subscription.start + subscription.period)) {
            // need to add buffer and condition to avoid spam attack
            tvm.accept();
            subscription.status = STATUS_NONACTIVE;
            IWallet(user_wallet).paySubscription{
                value: 0.2 ton, 
                bounce: false, 
                flag: 0, 
                callback: Subscription.onPaySubscription
            }(
                serviceOwner, 
                params, 
                subscription_indificator
            );
        } else {
            require(subscription.status == STATUS_ACTIVE, SubscriptionErrors.error_subscription_status_already_active);
        }
    }

    function onPaySubscription(uint8 status) external {
        if (status == 0 && user_wallet == msg.sender) {
            subscription.status = STATUS_ACTIVE;
            subscription.start = uint32(now);
        }
    }
}