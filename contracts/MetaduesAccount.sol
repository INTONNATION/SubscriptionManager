pragma ton-solidity ^ 0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;


import "libraries/MetaduesRootErrors.sol";
import "./Platform.sol";
import "libraries/PlatformTypes.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenWallet.sol";


contract MetaduesAccount {
   
    mapping(address => uint128) balance_map;
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
                     platform_params: platform_params
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


    function paySubscription(TvmCell params, address account_wallet, address subscription_wallet) 
        external
        responsible
        returns (uint8) {
        ( , uint128 tokens) = params.toSlice().decode(address, uint128);
        address subsciption_addr = address(tvm.hash(buildPlatformState(
            params
            )));
        require(subsciption_addr == msg.sender, 333);
        TvmCell payload;
        //check balance if enouph return 0 if not return 1
        address currency_root;
        uint128 value;
        TvmCell next_cell;
        (,value,,next_cell) = params.toSlice().decode(address, uint128, uint32, TvmCell);
        (,,,next_cell) = next_cell.toSlice().decode(string, string, string,TvmCell);
        (currency_root,) = next_cell.toSlice().decode(address, string);
        
        optional(uint128) current_balance_key_value = balance_map.fetch(currency_root);
        if (current_balance_key_value.hasValue()){
            uint128 current_balance = current_balance_key_value.get();
            
            if (value > current_balance){
                return { value: 0, flag: 128, bounce: false } 1;
            }
            else{
                ITokenWallet(account_wallet).transferToWallet{value: 0.5 ton}(tokens,subscription_wallet, subscription_wallet, true, payload);
                return { value: 0, flag: 128, bounce: false } 0;
            }
        }
        else {return { value: 0, flag: 128, bounce: false } 1;}
        }

    function onAcceptTokensTransfer(
        address tokenRoot,
        uint128 amount,
        address sender,
        address senderWallet,
        address remainingGasTo,
        TvmCell payload
    ) external
    {
        optional(uint128) current_balance = balance_map.fetch(tokenRoot);
        if (current_balance.hasValue()) {
            uint128 new_balance = current_balance.get() + amount;
            balance_map[tokenRoot] = new_balance;
        } else {
            balance_map[tokenRoot] = amount;
        }
        
    }

   


}
