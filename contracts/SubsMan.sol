pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "../contracts/Subscription.sol";
import "../contracts/Wallet.sol";
import "../contracts/SubscriptionService.sol";

contract SubsMan {
   
    uint128 constant DEPLOY_FEE = 1 ton;
    
    TvmCell m_subscriptionBaseImage;
    TvmCell s_subscriptionServiceImage;
    TvmCell m_subscriptionWalletImage;
    TvmCell m_subscriptionIndexImage;
    TvmCell s_subscriptionServiceIndexImage;

    modifier onlyOwner() {
        tvm.accept();
        _;
    }

    // Set images

    function setSubscriptionBase(TvmCell image) public onlyOwner {
        m_subscriptionBaseImage = image;
    }
 
    function setSubscriptionWalletCode(TvmCell image) public onlyOwner {
        m_subscriptionWalletImage = image;
    }

    function setSubscriptionIndexCode(TvmCell image) public onlyOwner {
        m_subscriptionIndexImage = image;
    }

    function setSubscriptionService(TvmCell image) public onlyOwner {
        s_subscriptionServiceImage = image;
    }

    function setSubscriptionServiceIndex(TvmCell image) public onlyOwner {
        s_subscriptionServiceIndexImage = image;
    }

    // Build States

    function buildAccount(uint256 ownerKey, uint256 serviceKey, TvmCell params, TvmCell indificator) private view returns (TvmCell image) {
        TvmCell walletCode = m_subscriptionWalletImage.toSlice().loadRef();
        TvmCell code = buildAccountHelper(serviceKey, params, tvm.hash(walletCode));
        TvmCell newImage = tvm.buildStateInit({
            code: code,
            pubkey: ownerKey,
            varInit: { 
                serviceKey: serviceKey,
                user_wallet: address(tvm.hash(buildWallet(ownerKey))),
                params: params,
                subscription_indificator: indificator
            },
            contr: Subscription
        });
        image = newImage;
    }

    function buildAccountHelper(uint256 serviceKey, TvmCell params, uint256 userWallet) private view returns (TvmCell) {
        TvmBuilder saltBuilder;
        saltBuilder.store(serviceKey,params,userWallet);
        TvmCell code = tvm.setCodeSalt(
            m_subscriptionBaseImage.toSlice().loadRef(),
            saltBuilder.toCell()
        );
        return code;
    }

    function buildAccountIndex(uint256 ownerKey) public view returns (TvmCell) {
        TvmBuilder saltBuilder;
        saltBuilder.store(ownerKey);
        TvmCell code = tvm.setCodeSalt(
            m_subscriptionIndexImage.toSlice().loadRef(),
            saltBuilder.toCell()
        );
        return code;             
    }

    function buildService(uint256 serviceKey, TvmCell params, string serviceCategory) private view returns (TvmCell image) {
        TvmCell code = buildServiceHelper(serviceCategory);
        TvmCell state = tvm.buildStateInit({
            code: code,
            pubkey: serviceKey,
            varInit: {
                serviceKey: serviceKey,
                serviceCategory: serviceCategory,
                params: params
            },
            contr: SubscriptionService
        });
        image = tvm.insertPubkey(state, serviceKey);
    }

    function buildServiceHelper(string serviceCategory) private view returns (TvmCell) {
        TvmBuilder saltBuilder;
        saltBuilder.store(serviceCategory);
        TvmCell code = tvm.setCodeSalt(
            s_subscriptionServiceImage.toSlice().loadRef(),
            saltBuilder.toCell()
        );
        return code;
    }

    function buildServiceIndex(uint256 serviceKey) private view returns (TvmCell) {
        TvmBuilder saltBuilder;
        saltBuilder.store(serviceKey);
        TvmCell code = tvm.setCodeSalt(
            s_subscriptionServiceIndexImage.toSlice().loadRef(),
            saltBuilder.toCell()
        );
        return code;
    }

    function buildWallet(uint256 ownerKey) private view returns (TvmCell image) {
        TvmCell code = m_subscriptionWalletImage.toSlice().loadRef();
        TvmCell newImage = tvm.buildStateInit({
            code: code,
            pubkey: ownerKey
        });
        image = newImage;
    }

    // Deploy contracts

    function deployAccountHelper(uint256 ownerKey, uint256 serviceKey, TvmCell params, bytes signature, TvmCell indificator ) public view {
        require(msg.value >= 1 ton, 102);
        TvmCell state = buildAccount(ownerKey,serviceKey,params, indificator);
        address subsAddr = address(tvm.hash(state));
        new Subscription{value: 1 ton, flag: 1, bounce: true, stateInit: state}(buildAccountIndex(ownerKey), signature, subsAddr, m_subscriptionWalletImage.toSlice().loadRef());
    }
 
    function deployServiceHelper(uint256 serviceKey, TvmCell params, bytes signature, string serviceCategory) public view {
        require(msg.value >= 1 ton, 102);
        TvmCell state = buildService(serviceKey,params,serviceCategory);
        TvmCell serviceIndexCode = buildServiceIndex(serviceKey);
        new SubscriptionService{value: 1 ton, flag: 1, bounce: true, stateInit: state}(serviceIndexCode, signature);
    }
    
}
