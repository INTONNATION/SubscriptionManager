pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;
import "SubscriptionIndex.sol";

interface IWallet {
    function paySubscription (uint256 serviceKey, bool bounce, TvmCell params) external responsible returns (uint8);
}

contract Subscription {

    uint256 static public serviceKey;
    address static public user_wallet;
    TvmCell static public params;
    TvmCell public subscription_indificator;
    address public subscriptionIndexAddress;

    uint8 constant STATUS_ACTIVE   = 1;
    uint8 constant STATUS_NONACTIVE = 2;

    struct Payment {
        uint256 pubkey;
        address to;
        uint128 value;
        uint32 period;
        uint32 start;
        uint8 status;
    }

    Payment public subscription;
    
    constructor(TvmCell image, bytes signature, address subsAddr, TvmCell indificator, TvmCell walletCode) public {
        (address to, uint128 value, uint32 period) = params.toSlice().decode(address, uint128, uint32);
        TvmCell code = tvm.code();
        optional(TvmCell) salt = tvm.codeSalt(code);
        address wallet_from_salt;
        require(salt.hasValue(), 104);
        (, , uint256 wallet_hash) = salt.get().toSlice().decode(uint256,TvmCell,uint256);
        require(wallet_hash == tvm.hash(walletCode), 111);
        TvmCell walletStateInit = tvm.buildStateInit({
            code: walletCode,
            pubkey: tvm.pubkey()
        });
        require(address(tvm.hash(walletStateInit)) == user_wallet, 123);
        require(msg.value >= 1 ton, 100);
        require(value > 0 && period > 0, 102);
        require(tvm.checkSign(tvm.hash(image), signature.toSlice(), tvm.pubkey()), 105);
        tvm.accept();
        subscription_indificator = indificator;
        //uint32 _period = period * 3600 * 24;
        uint32 _period = period;
        uint128 _value = value * 1000000000;
        subscription = Payment(tvm.pubkey(), to, _value, _period, 0, STATUS_NONACTIVE);
        TvmCell state = tvm.buildStateInit({
            code: image,
            pubkey: tvm.pubkey(),
            varInit: { 
                params: params,
                user_wallet: user_wallet
            },
            contr: SubscriptionIndex
        });
        TvmCell stateInit = tvm.insertPubkey(state, tvm.pubkey());
        subscriptionIndexAddress = address(tvm.hash(stateInit));
        new SubscriptionIndex{value: 0.5 ton, flag: 1, bounce: true, stateInit: stateInit}(signature, subsAddr, indificator);
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
            IWallet(user_wallet).paySubscription{value: 0.2 ton, bounce: false, flag: 0, callback: Subscription.onPaySubscription}(serviceKey, false, params);
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
