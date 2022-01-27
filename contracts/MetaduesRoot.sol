pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;


import "libraries/MetaduesRootErrors.sol";
import "libraries/Upgradable.sol";
import "./Platform.sol";
import "libraries/PlatformTypes.sol";



contract MetaduesRoot is Upgradable {
   
    TvmCell public platform_code;
    bool has_platform_code;
    TvmCell public account_code;
    TvmCell public subscription_code;
    uint32 account_version;
    uint32 subscription_version;

	onBounce(TvmSlice slice) external {
        // revert change to initial msg.sender in case of failure during deploy
        // TODO check SubsMan balance after that
		uint32 functionId = slice.decode(uint32);
        
    }

    constructor() public {
        tvm.accept();
    }

   function installPlatformOnce(TvmCell code) external onlyOwner {
        // can be installed only once
        require(!has_platform_code, 222);
        platform_code = code;
        has_platform_code = true;
    }

    // Deploy contracts
    function deployAccount(
    ) 
        public view 
    {
        //require(msg.sender != address(0), MetaduesRootErrors.error_message_sender_address_not_specified);
        tvm.accept();
        Platform platform = new Platform {
            stateInit: _buildInitData(PlatformTypes.Account, _buildAccountParams(msg.sender)),
            value: 1 ton,
            flag: 0
        }();
        platform.initialize{
            value: 1 ton,
            flag: 0
        }(
            account_code,
            account_version,
            msg.sender
        );

    }
    
    function deploySubscription(
        TvmCell service_params
    ) 
        public view 
    {
        //require(msg.sender != address(0), MetaduesRootErrors.error_message_sender_address_not_specified);
        tvm.accept();
        TvmCell subscription_code_salt = _buildSubscriptionCode(msg.sender, service_params);

        Platform platform = new Platform {
            stateInit: _buildInitData(PlatformTypes.Subscription, _buildSubscriptionParams(msg.sender, service_params)),
            value: 1 ton,
            flag: 0
        }();
        platform.initialize{
            value: 1 ton,
            flag: 0
        }(
            subscription_code_salt,
            subscription_version,
            msg.sender

        );

    }



    function installOrUpdateAccountCode(TvmCell code) external onlyOwner {
        account_code = code;
        account_version++;
    }

    function installOrUpdateSubscriptionCode(TvmCell code) external onlyOwner {
        subscription_code = code;
        subscription_version++;
    }  
      
      function _buildInitData(uint8 type_id, TvmCell params) private inline view returns (TvmCell) {
        return tvm.buildStateInit({
            contr: Platform,
            varInit: {
                root: address(this),
                type_id: type_id,
                params: params
            },
            pubkey: 0,
            code: platform_code
        });
    }

    function _buildAccountParams(address account_owner) private inline pure returns (TvmCell) {
        TvmBuilder builder;
        builder.store(account_owner);
        return builder.toCell();
    }

    function _buildSubscriptionParams(address subscription_owner, TvmCell service_params) private inline pure returns (TvmCell) {
        TvmBuilder builder;
        builder.store(subscription_owner);
        builder.store(service_params);
        return builder.toCell();
    }

    function _buildSubscriptionCode(address subscription_owner, TvmCell service_params) private view returns (TvmCell) {
        TvmBuilder saltBuilder;
        saltBuilder.store(
            subscription_owner, 
            address(this),
            service_params
        ); // Max 4 items
        TvmCell code = tvm.setCodeSalt(
            subscription_code,
            saltBuilder.toCell()
        );
        return code;
    }


    function onCodeUpgrade() internal override {
        tvm.resetStorage();
    }
    modifier onlyOwner() {
        tvm.accept();
        _;
    }


}
