pragma ton-solidity ^ 0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;


import "libraries/MetaduesRootErrors.sol";
import "./Platform.sol";
import "libraries/PlatformTypes.sol";
import "../contracts/SubscriptionIndex.sol";
import "../contracts/SubscriptionIdentificatorIndex.sol";
import "../contracts/SubscriptionServiceIndex.sol";



contract MetaduesRoot {
   
    TvmCell public platform_code;
    TvmCell public account_code;
    TvmCell public subscription_code;
    TvmCell public subscription_index_code;
    TvmCell public subscription_index_identificator_code;
    TvmCell public service_code;
    TvmCell public service_index_code;
    bool has_platform_code;
    uint32 service_version;
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

    modifier onlyOwner() {
        tvm.accept();
        _;
    }

    function installPlatformOnce(TvmCell code) external onlyOwner {
        // can be installed only once
        require(!has_platform_code, 222);
        platform_code = code;
        has_platform_code = true;
    }

    function installOrUpdateAccountCode(TvmCell code) external onlyOwner {
        account_code = code;
        account_version++;
    }

    function installOrUpdateSubscriptionCode(TvmCell code) external onlyOwner {
        subscription_code = code;
        subscription_version++;
    }  

    function installOrUpdateSubscriptionIndexCode(TvmCell code) external onlyOwner {
        subscription_index_code = code;
    }  
    
    function installOrUpdateSubscriptionIndexIdentificatorCode(TvmCell code) external onlyOwner {
        subscription_index_identificator_code = code;
    }  

    function installOrUpdateServiceCode(TvmCell code) external onlyOwner {
        service_code = code;
        service_version++;
    }  

    function installOrUpdateServiceIndexCode(TvmCell code) external onlyOwner {
        service_index_code = code;
    }

    // Deploy contracts
    function deployAccount() external view {
        //require(msg.sender != address(0), MetaduesRootErrors.error_message_sender_address_not_specified);
        TvmCell account_params;
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
            account_params,
            account_version,
            msg.sender
        );

    }
    
    function deploySubscription(
        address service_address,
        TvmCell identificator
    ) 
        public view 
    {
        //require(msg.sender != address(0), MetaduesRootErrors.error_message_sender_address_not_specified);
        tvm.accept();  
        TvmCell subsIndexStateInit = _buildSubscriptionIndex(
            service_address
        );
        TvmCell subsIndexIdentificatorStateInit = _buildSubscriptionIdentificatorIndex(
            service_address, 
            identificator
        );
        TvmCell subscription_code_salt = _buildSubscriptionCode(msg.sender);
        TvmBuilder service_params;
        TvmBuilder index_addreses;
        address owner_account_address = address(tvm.hash(_buildInitData(PlatformTypes.Account, _buildAccountParams(msg.sender))));
        address subs_index = address(tvm.hash(subsIndexStateInit));
        address subs_index_identificator = address(tvm.hash(subsIndexIdentificatorStateInit));
        index_addreses.store(subs_index, subs_index_identificator);
        service_params.store(service_address,owner_account_address,index_addreses.toCell());

        // service_params.store(owner_account_address);
        Platform platform = new Platform {
            stateInit: _buildInitData(PlatformTypes.Subscription, _buildSubscriptionParams(msg.sender, service_address)),
            value: 1 ton,
            flag: 0
        }();
        platform.initialize{
            value: 1 ton,
            flag: 0
        }(
            subscription_code_salt,
            service_params.toCell(),
            subscription_version,
            msg.sender

        );

        new SubscriptionIndex{
            value: 0.02 ton, 
            flag: 0,
            bounce: true, 
            stateInit: subsIndexStateInit
            }(
                address(platform),
                msg.sender
            );
        
        new SubscriptionidentificatorIndex{
            value: 0.02 ton, 
            flag: 0, 
            bounce: true, 
            stateInit: subsIndexIdentificatorStateInit
            }(
                address(platform),
                msg.sender
            );
    }

    function deployService(
          TvmCell service_params
    ) 
        public view 
    {
        //require(msg.sender != address(0), MetaduesRootErrors.error_message_sender_address_not_specified);
        tvm.accept();
        TvmCell next_cell;
        string category;
        string service_name;
        (,,,next_cell) = service_params.toSlice().decode(address, uint128, uint32, TvmCell);
        (service_name,,,next_cell) = next_cell.toSlice().decode(string, string, string,TvmCell);
        (,category) = next_cell.toSlice().decode(address, string);
        TvmCell service_code_salt = _buildServiceCode(category);
        Platform platform = new Platform {
            stateInit: _buildInitData(PlatformTypes.Service, _buildServiceParams(msg.sender, service_name)),
            value: 1 ton,
            flag: 0
        }();
        platform.initialize{
            value: 1 ton,
            flag: 0
        }(
            service_code_salt,
            service_params,
            service_version,
            msg.sender
        );
        TvmCell serviceIndexStateInit = _buildServiceIndex(msg.sender);
        new SubscriptionServiceIndex{
            value: 1 ton, 
            flag: 1, 
            bounce: true, 
            stateInit: serviceIndexStateInit
            }(
                address(platform),
                msg.sender
            );
    } 

    function _buildSubscriptionCode(address subscription_owner) private view returns (TvmCell) {
        TvmBuilder saltBuilder;
        saltBuilder.store(
            subscription_owner, 
            address(this)
        ); // Max 4 items
        TvmCell code = tvm.setCodeSalt(
            subscription_code,
            saltBuilder.toCell()
        );
        return code;
    }

    function _buildServiceCode(string category) private view returns (TvmCell) {
        TvmBuilder saltBuilder;
        saltBuilder.store(
            category, 
            address(this)
        ); // Max 4 items
        TvmCell code = tvm.setCodeSalt(
            service_code,
            saltBuilder.toCell()
        );
        return code;
    }

    function _buildSubscriptionIdentificatorIndex(
        address service_address, 
        TvmCell identificator
    ) private view returns (TvmCell) 
    {
        TvmBuilder saltBuilder;
        saltBuilder.store(
            service_address,
            identificator,
            address(this)
        );
        TvmCell code = tvm.setCodeSalt(
            subscription_index_identificator_code,
            saltBuilder.toCell()
        );
        TvmCell stateInit = tvm.buildStateInit({
            code: code,
            pubkey: 0,
            varInit: { 
            },
            contr: SubscriptionidentificatorIndex
        });
        return stateInit;             
    }

    function _buildSubscriptionIndex(
        address service_address
    ) private view returns (TvmCell) 
    {
        TvmBuilder saltBuilder;
        saltBuilder.store(
            service_address,
            address(this)
        );
        TvmCell code = tvm.setCodeSalt(
            subscription_index_code,
            saltBuilder.toCell()
        );
        TvmCell stateInit = tvm.buildStateInit({
            code: code,
            pubkey: 0,
            varInit: { 
            },
            contr: SubscriptionIndex
        });
        return stateInit;             
    }

    function _buildServiceIndex(
        address serviceOwner
    ) private view returns (TvmCell) {
        TvmBuilder saltBuilder;
        saltBuilder.store(serviceOwner,address(this));
        TvmCell code = tvm.setCodeSalt(
            service_index_code,
            saltBuilder.toCell()
        );
        TvmCell state = tvm.buildStateInit({
            code: code,
            pubkey: 0,
            varInit: { 
            },
            contr: SubscriptionServiceIndex
        });
        return state;
    }

    function _buildInitData(uint8 type_id, TvmCell params) private inline view returns (TvmCell) {
        return tvm.buildStateInit({
            contr: Platform,
            varInit: {
                root: address(this),
                type_id: type_id,
                platform_params: params
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

    function _buildSubscriptionParams(address subscription_owner, address service_address) private inline pure returns (TvmCell) {
        TvmBuilder builder;
        builder.store(subscription_owner);
        builder.store(service_address);
        return builder.toCell();
    }

    function _buildServiceParams(address service_owner, string service_name) private inline pure returns (TvmCell) {
        TvmBuilder builder;
        builder.store(service_owner);
        builder.store(service_name);
        return builder.toCell();
    }
}