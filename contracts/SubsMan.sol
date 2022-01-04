pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "../contracts/Subscription.sol";
import "../contracts/SubscriptionService.sol";
import "../contracts/mTIP-3/mTONTokenWallet.sol";


contract SubsMan {
   
    uint128 constant DEPLOY_FEE = 1 ton;
    
    TvmCell m_subscriptionBaseImage;
    TvmCell s_subscriptionServiceImage;
    TvmCell m_subscriptionWalletImage_mUSDT;
    TvmCell m_subscriptionWalletImage_mEUPI;
    TvmCell m_subscriptionIndexImage;
    TvmCell s_subscriptionServiceIndexImage;

    modifier onlyOwner() {
        require(msg.pubkey() == tvm.pubkey(), 101);
        tvm.accept();
        _;
    }

    // Set images (TODO: Move to version contract)
    function setSubscriptionBase(TvmCell image) public onlyOwner {
        m_subscriptionBaseImage = image;
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

    // Deploy contracts
    function deployAccountHelper(
        uint256 serviceKey, 
        TvmCell params, 
        TvmCell indificator, 
        TvmCell accountWallet, 
        address walletRootAddress
    ) 
        public view 
    {
        require(msg.value >= 1 ton, 102);
        require(accountWallet.toSlice().empty() != true, 111);
        TvmCell state = buildAccount(
            serviceKey, 
            params, 
            indificator, 
            accountWallet, 
            walletRootAddress, 
            msg.sender
        );
        address subsAddr = address(tvm.hash(state));
        TvmCell subsIndexStateInit = buildAccountIndex(
            msg.sender, 
            params, 
            indificator, 
            accountWallet, 
            walletRootAddress
        );
        address subscriptionIndexAddress = address(tvm.hash(subsIndexStateInit));
        new Subscription{
            value: 1 ton, 
            flag: 1, 
            bounce: true, 
            stateInit: state
            }(
                msg.sender, 
                accountWallet.toSlice().loadRef(), 
                walletRootAddress, 
                subscriptionIndexAddress
            );
        new SubscriptionIndex{
            value: 0.5 ton, 
            flag: 1, 
            bounce: true, 
            stateInit: subsIndexStateInit
            }(
                subsAddr, 
                msg.sender
            );
    }
 
    function deployServiceHelper(uint256 serviceKey, TvmCell params, bytes signature, string serviceCategory) public view {
        require(msg.value >= 1 ton, 102);
        TvmCell state = buildService(
            serviceKey,
            params,
            serviceCategory
        );
        TvmCell serviceIndexCode = buildServiceIndex(
            serviceKey
        );
        new SubscriptionService{
            value: 1 ton, 
            flag: 1, 
            bounce: true, 
            stateInit: state
            }(
                serviceIndexCode, 
                signature
            );
    }
    // Build States
    function buildAccount(
        uint256 serviceKey, 
        TvmCell params, 
        TvmCell indificator, 
        TvmCell accountWallet, 
        address rootAddress, 
        address ownerAddress
    ) private view returns (TvmCell image)
    {
        TvmCell walletCode = accountWallet.toSlice().loadRef();
        TvmCell code = buildAccountHelper(
            serviceKey, 
            params, 
            tvm.hash(walletCode), 
            ownerAddress
        );
        address _userWallet = address(tvm.hash(buildWallet(
            walletCode, 
            rootAddress, 
            ownerAddress
        )));
        TvmCell newImage = tvm.buildStateInit({
            code: code,
            pubkey: 0,
            varInit: { 
                serviceKey: serviceKey,
                user_wallet: _userWallet,
                params: params,
                subscription_indificator: indificator,
                owner_address: ownerAddress
            },
            contr: Subscription
        });
        image = newImage;
    }

    function buildAccountHelper(uint256 serviceKey, TvmCell params, uint256 userWallet, address ownerAddress) private view returns (TvmCell) {
        TvmBuilder saltBuilder;
        TvmBuilder addrsBuilder;
        addrsBuilder.store(
            ownerAddress, 
            address(this)
        );
        saltBuilder.store(
            serviceKey, 
            params, 
            userWallet, 
            addrsBuilder.toCell()
        ); // Max 4 items
        TvmCell code = tvm.setCodeSalt(
            m_subscriptionBaseImage.toSlice().loadRef(),
            saltBuilder.toCell()
        );
        return code;
    }

    function buildAccountIndex(
        address ownerAddress, 
        TvmCell params, 
        TvmCell indificator, 
        TvmCell accountWallet, 
        address walletRootAddress
    ) private view returns (TvmCell) 
    {
        TvmBuilder saltBuilder;
        TvmCell walletCode = accountWallet.toSlice().loadRef();
        address userWallet = address(tvm.hash(buildWallet(
            walletCode,
            walletRootAddress,
            msg.sender
        )));
        saltBuilder.store(
            ownerAddress, 
            address(this)
        );
        TvmCell code = tvm.setCodeSalt(
            m_subscriptionIndexImage.toSlice().loadRef(),
            saltBuilder.toCell()
        );
        TvmCell stateInit = tvm.buildStateInit({
            code: code,
            pubkey: 0,
            varInit: { 
                params: params,
                user_wallet: userWallet,
                subscription_indificator: indificator
            },
            contr: SubscriptionIndex
        });
        return stateInit;             
    }

    function buildService(uint256 serviceKey, TvmCell params, string serviceCategory) private view returns (TvmCell image) {
        TvmCell code = buildServiceHelper(
            serviceCategory
        );
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
        image = tvm.insertPubkey(
            state, 
            serviceKey
        );
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

    function buildWallet(TvmCell accountWallet, address rootAddress, address ownerAddress) private view returns (TvmCell image) {
        TvmCell newImage = tvm.buildStateInit({
            code: accountWallet,
            pubkey: 0,
            contr: TONTokenWallet,
            varInit: {
                root_address: rootAddress,
                code: accountWallet,
                wallet_public_key: 0,
                owner_address: ownerAddress
            }
        });
        image = newImage;
    }
}