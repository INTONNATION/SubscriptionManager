pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "../contracts/Subscription.sol";
import "../contracts/SubscriptionService.sol";
import "../contracts/SubscriptionServiceIndex.sol";
import "../contracts/SubscriptionIndificatorIndex.sol";
import "../contracts/mTIP-3/mTONTokenWallet.sol";
import "libraries/SubsManErrors.sol";
import "libraries/Upgradable.sol";


struct VersionsTvcParams {
    TvmCell tvcSubscriptionService;
    TvmCell tvcSubscription;
    TvmCell tvcSubscriptionServiceIndex;
    TvmCell tvcSubscriptionIndex;
    TvmCell tvcSubscriptionIndificatorIndex;
}


interface ISubsMan {
    function getTvcsLatestResponsible() external responsible returns(VersionsTvcParams);
}


contract SubsMan is Upgradable {
   
    TvmCell public m_subscriptionBaseImage;
    TvmCell public s_subscriptionServiceImage;
    TvmCell public m_subscriptionIndexImage;
    TvmCell public s_subscriptionServiceIndexImage;
    TvmCell public m_subscriptionIndificatorIndexImage;
    address public configVersionsAddr;

	onBounce(TvmSlice slice) external {
        // revert change to initial msg.sender in case of failure during deploy
        // TODO check SubsMan balance after that
		uint32 functionId = slice.decode(uint32);
		if (functionId == tvm.functionId(Subscription)) {
			(address senderAddress,,,,) = slice.decodeFunctionParams(Subscription);
            senderAddress.transfer(msg.value);
		} else if (functionId == tvm.functionId(SubscriptionService)) {
            (, address senderAddress) = slice.decodeFunctionParams(SubscriptionService);
            senderAddress.transfer(msg.value);
		}
        else if (functionId == tvm.functionId(SubscriptionServiceIndex)) {
			(, address senderAddress) = slice.decodeFunctionParams(SubscriptionServiceIndex);
            senderAddress.transfer(msg.value);
		}        
        else if (functionId == tvm.functionId(SubscriptionIndificatorIndex)) {
			(, address senderAddress) = slice.decodeFunctionParams(SubscriptionIndificatorIndex);
            senderAddress.transfer(msg.value);	
        }
        else if (functionId == tvm.functionId(SubscriptionIndex)) {
			(, address senderAddress) = slice.decodeFunctionParams(SubscriptionIndex);
            senderAddress.transfer(msg.value);
        }
    }

    constructor(address configVersionsAddrINPUT) public {
        tvm.accept();
        configVersionsAddr = configVersionsAddrINPUT;
        ISubsMan(configVersionsAddr).getTvcsLatestResponsible{value: 0.2 ton, callback: SubsMan.setTVCs}();
    }

    function setTVCs(VersionsTvcParams tvcs) external {
        require(msg.sender == configVersionsAddr);
        m_subscriptionBaseImage = tvcs.tvcSubscription;
        s_subscriptionServiceImage = tvcs.tvcSubscriptionService;
        m_subscriptionIndexImage = tvcs.tvcSubscriptionIndex;
        s_subscriptionServiceIndexImage = tvcs.tvcSubscriptionServiceIndex;
        m_subscriptionIndificatorIndexImage = tvcs.tvcSubscriptionIndificatorIndex;
    }

    // Deploy contracts
    function deployAccount(
        address serviceOwner,
        TvmCell params, 
        TvmCell indificator, 
        TvmCell accountWallet, 
        address walletRootAddress
    ) 
        public view 
    {
        require(msg.value >= 1 ton, SubsManErrors.error_not_enough_balance_in_message);
        require(msg.sender != address(0), SubsManErrors.error_message_sender_address_not_specified);
        require(accountWallet.toSlice().empty() != true, SubsManErrors.error_wrong_wallet_tvc);
        TvmCell subscriptionStateInit = buildAccount(
            serviceOwner, 
            params, 
            indificator, 
            accountWallet, 
            walletRootAddress,
            msg.sender
        );
        address subsAddr = address(tvm.hash(subscriptionStateInit));
        TvmCell subsIndexStateInit = buildAccountIndex(
            serviceOwner, 
            params, 
            indificator
        );
        TvmCell subsIndexIndificatorStateInit = buildAccountIndificatorIndex(
            params, 
            indificator
        );
        address subscriptionIndexAddress = address(tvm.hash(subsIndexStateInit));
        address subsIndexIndificatorAddress = address(tvm.hash(subsIndexIndificatorStateInit));
        new Subscription{
            value: 0.5 ton, 
            flag: 1, 
            bounce: true, 
            stateInit: subscriptionStateInit
            }(
                msg.sender, 
                accountWallet.toSlice().loadRef(), 
                walletRootAddress, 
                subscriptionIndexAddress,
                subsIndexIndificatorAddress
            );
        new SubscriptionIndex{
            value: 0.02 ton, 
            flag: 1,
            bounce: true, 
            stateInit: subsIndexStateInit
            }(
                subsAddr,
                msg.sender
            );
        
        (string indificatorStr) = indificator.toSlice().decode(string);
        if (indificatorStr != 'empty') {
            new SubscriptionIndificatorIndex{
                value: 0.02 ton, 
                flag: 1, 
                bounce: true, 
                stateInit: subsIndexIndificatorStateInit
                }(
                    subsAddr,
                    msg.sender
                );
        }
    }
 
    function deployService(TvmCell params, string serviceCategory) public view {
        require(msg.value >= 0.05 ton, SubsManErrors.error_not_enough_balance_in_message);
        require(msg.sender != address(0), SubsManErrors.error_message_sender_address_not_specified);
        TvmCell serviceStateInit = buildService(
            msg.sender,
            params,
            serviceCategory
        );
        TvmCell serviceIndexStateInit = buildServiceIndex(msg.sender, params, serviceCategory);
        address serviceIndexAddress = address(tvm.hash(serviceIndexStateInit));
        address serviceAddr = new SubscriptionService{
            value: 0.02 ton, 
            flag: 1, 
            bounce: true, 
            stateInit: serviceStateInit
            }(
                serviceIndexAddress,
                msg.sender
            );
        new SubscriptionServiceIndex{
            value: 0.02 ton, 
            flag: 1, 
            bounce: true, 
            stateInit: serviceIndexStateInit
            }(
                serviceAddr,
                msg.sender
            );
    }
    // Build States
    function buildAccount(
        address serviceOwner, 
        TvmCell params, 
        TvmCell indificator, 
        TvmCell accountWallet, 
        address rootAddress,
        address ownerAddress
    ) private view returns (TvmCell image)
    {
        TvmCell walletCode = accountWallet.toSlice().loadRef();
        TvmCell code = buildAccountHelper(
            ownerAddress,
            params, 
            tvm.hash(walletCode) 
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
                serviceOwner: serviceOwner,
                user_wallet: _userWallet,
                params: params,
                subscription_indificator: indificator,
                owner_address: ownerAddress
            },
            contr: Subscription
        });
        image = newImage;
    }

    function buildAccountHelper(address ownerAddress, TvmCell params, uint256 userWallet) private view returns (TvmCell) {
        TvmBuilder saltBuilder;
        saltBuilder.store(
            ownerAddress, 
            address(this),
            userWallet
        ); // Max 4 items
        TvmCell code = tvm.setCodeSalt(
            m_subscriptionBaseImage.toSlice().loadRef(),
            saltBuilder.toCell()
        );
        return code;
    }

    function buildAccountIndex(
        address serviceOwner, 
        TvmCell params, 
        TvmCell indificator
    ) private view returns (TvmCell) 
    {
        TvmBuilder saltBuilder;
        saltBuilder.store(
            serviceOwner,
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
                subscription_indificator: indificator
            },
            contr: SubscriptionIndex
        });
        return stateInit;             
    }

    function buildAccountIndificatorIndex(
        TvmCell params, 
        TvmCell indificator
    ) private view returns (TvmCell) 
    {
        TvmBuilder saltBuilder;
        saltBuilder.store(
            indificator,
            address(this)
        );
        TvmCell code = tvm.setCodeSalt(
            m_subscriptionIndificatorIndexImage.toSlice().loadRef(),
            saltBuilder.toCell()
        );
        TvmCell stateInit = tvm.buildStateInit({
            code: code,
            pubkey: 0,
            varInit: { 
                params: params,
                subscription_indificator: indificator
            },
            contr: SubscriptionIndificatorIndex
        });
        return stateInit;             
    }

    function buildService(address serviceOwner, TvmCell params, string serviceCategory) private view returns (TvmCell image) {
        TvmCell code = buildServiceHelper(
            serviceCategory
        );
        TvmCell state = tvm.buildStateInit({
            code: code,
            pubkey: 0,
            varInit: {
                serviceOwner: serviceOwner,
                serviceCategory: serviceCategory,
                params: params
            },
            contr: SubscriptionService
        });
        return state;
    }

    function buildServiceHelper(string serviceCategory) private view returns (TvmCell) {
        TvmBuilder saltBuilder;
        saltBuilder.store(serviceCategory,address(this));
        TvmCell code = tvm.setCodeSalt(
            s_subscriptionServiceImage.toSlice().loadRef(),
            saltBuilder.toCell()
        );
        return code;
    }
    
    function buildServiceIndex(address serviceOwner, TvmCell params, string serviceCategory) private view returns (TvmCell) {
        TvmCell code = buildServiceIndexHelper(
            serviceOwner
        );
        TvmCell state = tvm.buildStateInit({
            code: code,
            pubkey: 0,
            varInit: { 
                params: params,
                serviceCategory: serviceCategory
            },
            contr: SubscriptionServiceIndex
        });
        return state;
    }

    function buildServiceIndexHelper(address serviceOwner) private view returns (TvmCell) {
        TvmBuilder saltBuilder;
        saltBuilder.store(serviceOwner,address(this));
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

    function onCodeUpgrade() internal override {
        tvm.resetStorage();
    }

}
