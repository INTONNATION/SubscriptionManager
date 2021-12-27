pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;
import "SubscriptionIndex.sol";
import "../contracts/mTIP-3/mTONTokenWallet2.sol";

interface IWallet  {
    function paySubscription (uint256 serviceKey, TvmCell params, TvmCell indificator) external responsible returns (uint8);
}

contract Subscription {

    uint256 static public serviceKey;
    address static public user_wallet;
    TvmCell static public params;
    TvmCell static public subscription_indificator;
    address static public owner_address;
    address public subscriptionIndexAddress;

    uint8 constant STATUS_ACTIVE   = 1;
    uint8 constant STATUS_NONACTIVE = 2;

    struct Payment {
        uint256 to;
        uint128 value;
        uint32 period;
        uint32 start;
        uint8 status;
    }

    Payment public subscription;
    
    constructor(address ownerAddress, TvmCell walletCode, address rootAddress, address subsIndexAddr) public {
        (uint256 to, uint128 value, uint32 period) = params.toSlice().decode(uint256, uint128, uint32);
        TvmCell code = tvm.code();
        optional(TvmCell) salt = tvm.codeSalt(code);
        address wallet_from_salt;
        require(salt.hasValue(), 104);
        (, , uint256 wallet_hash, address subsmanAddr) = salt.get().toSlice().decode(uint256,TvmCell,uint256,address);
        require(msg.sender == subsmanAddr,333);
        require(owner_address == ownerAddress,444);
        require(wallet_hash == tvm.hash(walletCode), 111);
        TvmCell walletStateInit = tvm.buildStateInit({
            code: walletCode,
            pubkey: 0,
            contr: TONTokenWallet2,
            varInit: {
                root_address: rootAddress,
                code: walletCode,
                wallet_public_key: uint256(0),
                owner_address: ownerAddress
            }
        });
        require(address(tvm.hash(walletStateInit)) == user_wallet, 123);
        require(msg.value >= 1 ton, 100);
        require(value > 0 && period > 0, 102);
        //uint32 _period = period * 3600 * 24;
        uint32 _period = period;
        uint128 _value = value * 1000000000;
        subscription = Payment(to, _value, _period, 0, STATUS_NONACTIVE);
        subscriptionIndexAddress = subsIndexAddr;
    }

    function cancel() public {
        require(msg.sender == subscriptionIndexAddress, 106);
        selfdestruct(user_wallet);
    }

    function executeSubscription() public {        
        if (now > (subscription.start + subscription.period)) {
            // need to add buffer and condition
            tvm.accept();
            subscription.status = STATUS_NONACTIVE;
            IWallet(user_wallet).paySubscription{value: 0.2 ton, bounce: false, flag: 0, callback: Subscription.onPaySubscription}(serviceKey, params, subscription_indificator);
        } else {
            require(subscription.status == STATUS_ACTIVE, 103);
        }
    }

    function onPaySubscription(uint8 status) external {
        if (status == 0 && user_wallet == msg.sender) {
            subscription.status = STATUS_ACTIVE;
            subscription.start = uint32(now);
        }
    }
}