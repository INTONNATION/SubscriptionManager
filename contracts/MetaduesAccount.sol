pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;


import "libraries/MetaduesRootErrors.sol";
import "./Platform.sol";
import "libraries/PlatformTypes.sol";



contract MetaduesAccount {
   
    address public root;
    TvmCell platform_code;
    TvmCell platform_params;
    uint32 current_version;
    uint8 type_id;

    constructor() public { revert(); }
    
    function buildPlatformState(TvmCell params) public returns (TvmCell){
        TvmBuilder saltBuilder;
        saltBuilder.store(params);
        TvmCell codeSalt = tvm.setCodeSalt(
            platform_code,
            saltBuilder.toCell()
        );
        TvmCell newImage = tvm.buildStateInit({
            code: codeSalt,
            pubkey: 0,
            varInit: {
                     root: root,
                     type_id: type_id,
                     params: platform_params
            },
            contr: Platform
        });
        return newImage;
    }

    function onCodeUpgrade(TvmCell upgrade_data) private {
        TvmSlice s = upgrade_data.toSlice();
        (address root_, address send_gas_to, uint32 old_version, uint32 version, uint8 type_id_ ) =
        s.decode(address,address,uint32,uint32,uint8);

        if (old_version == 0) {
            tvm.resetStorage();
        }

        root = root_;
        platform_code = s.loadRef();
        platform_params = s.loadRef();   
        current_version = version;  
        type_id = type_id_;
  
        //send_gas_to.transfer({ value: 0, flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS });
    }


    function paySubscription(TvmCell params) public {
        (address service_owner_address, uint128 value) = params.toSlice().decode(address, uint128);
        bool senderIsSubscription;
        address subsAddr;
        subsAddr = address(tvm.hash(buildPlatformState(
            params
            )));
        
        require(subsAddr == msg.sender, 333);

        }
    


   


}
