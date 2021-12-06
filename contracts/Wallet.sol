pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;
import "Subscription.sol";

contract Wallet {

    TvmCell public subscr_Image;
    address public myaddress;
   
    constructor(TvmCell image, bytes signature) public {
        require(tvm.pubkey() != 0, 100);
        require(tvm.checkSign(tvm.hash(tvm.code()), signature.toSlice(), tvm.pubkey()), 102);
        tvm.accept();
        subscr_Image = image;
        TvmCell wImage = tvm.buildStateInit({
            code: tvm.code(),
            pubkey: tvm.pubkey()
        });
        myaddress = address(tvm.hash(wImage));
    }

    function sendTransaction(uint128 value, address dest, bool bounce) public view {
        require(msg.pubkey() == tvm.pubkey(), 103);
        tvm.accept();
        dest.transfer(value, bounce, 0);
    }

    function buildSubscriptionState(uint256 serviceKey, TvmCell params, TvmCell indificator) private view returns (TvmCell) {
        TvmBuilder saltBuilder;
        saltBuilder.store(serviceKey, params, tvm.hash(tvm.code()));
        TvmCell code = tvm.setCodeSalt(
            subscr_Image.toSlice().loadRef(),
            saltBuilder.toCell()
        );
        TvmCell newImage = tvm.buildStateInit({
            code: code,
            pubkey: tvm.pubkey(),
            varInit: {
                serviceKey: serviceKey,
                user_wallet: myaddress,
                params: params,
                subscription_indificator: indificator
            },
            contr: Subscription
        });
        return newImage;
    }

    function paySubscription(uint256 serviceKey, bool bounce, TvmCell params, TvmCell indificator) public responsible returns (uint8) {
        require(msg.value >= 0.1 ton, 105);
        (address to, uint128 value) = params.toSlice().decode(address, uint128);
        address subsAddr = address(tvm.hash(buildSubscriptionState(serviceKey,params,indificator)));
        require(msg.sender == subsAddr, 111);
        to.transfer(value * 1000000000, bounce, 0);
        return{value: 0, bounce: false, flag: 64} 0;  
    }
}
