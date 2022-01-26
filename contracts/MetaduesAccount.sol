pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;


import "libraries/MetaduesRootErrors.sol";
import "./Platform.sol";
import "libraries/PlatformTypes.sol";
import "TIP3/interfaces/ITokenWallet.sol";


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


    function paySubscription(TvmCell params, address account_wallet, address subscription_wallet) external {
        ( , uint128 tokens) = params.toSlice().decode(address, uint128);
        address subsciption_addr = address(tvm.hash(buildPlatformState(
            params
            )));
        require(subsciption_addr == msg.sender, 333);
        TvmCell payload; 
        ITokenWallet(account_wallet).transferToWallet{value: 0.5 ton}(tokens,subscription_wallet, subscription_wallet, true, payload );
        }



   


}
