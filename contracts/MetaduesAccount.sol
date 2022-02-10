pragma ton-solidity >= 0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;


import "libraries/MetaduesRootErrors.sol";
import "./Platform.sol";
import "libraries/PlatformTypes.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenWallet.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenRoot.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/TIP3TokenWallet.sol";


contract MetaduesAccount {
   
    mapping(address => balance_wallet_struct) public balance_map;
    address public root;
    TvmCell platform_code;
    TvmCell platform_params;
    uint32 current_version;
    uint8 type_id;
    address account_owner;
    uint128 withdraw_value;

    constructor() public { revert(); }

    struct balance_wallet_struct {
        address wallet;
        uint128 balance;

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
        account_owner = platform_params.toSlice().decode(address);
  
        //send_gas_to.transfer({ value: 0, flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS });
    }


    function paySubscription(TvmCell params, address account_wallet, address subscription_wallet, address service_address) 
        external
        responsible
        returns (uint8) {
        ( , uint128 tokens) = params.toSlice().decode(address, uint128);
        address subsciption_addr = address(tvm.hash(_buildInitData(PlatformTypes.Subscription, _buildSubscriptionParams(account_owner, service_address)))); 
//        require(subsciption_addr == msg.sender, 333);
        TvmCell payload;
        //check balance if enouph return 0 if not return 1
        address currency_root;
        uint128 value;
        TvmCell next_cell;
        (,value,,next_cell) = params.toSlice().decode(address, uint128, uint32, TvmCell);
        (,,,next_cell) = next_cell.toSlice().decode(string, string, string,TvmCell);
        (currency_root,) = next_cell.toSlice().decode(address, string);
        
        optional(balance_wallet_struct) current_balance_struct = balance_map.fetch(currency_root);
        
        if (current_balance_struct.hasValue()){         
            balance_wallet_struct current_balance_key_value = current_balance_struct.get();
            uint128 current_balance = current_balance_key_value.balance;
            if (value > current_balance){
                return { value: 0, flag: 128, bounce: false } 1;
            }
            else{
                ITokenWallet(account_wallet).transferToWallet{value: 0.5 ton}(tokens,subscription_wallet, subscription_wallet, true, payload);
                uint128 balance_after_pay = current_balance - value;
                current_balance_key_value.balance = balance_after_pay;
                balance_map[currency_root] = current_balance_key_value;
                return { value: 0, flag: 128, bounce: false } 0;
            }
        }
        else {return { value: 0, flag: 128, bounce: false } 1;}
        }

          


     function syncBalance(address currency_root) external {
        optional(balance_wallet_struct) current_balance_struct = balance_map.fetch(currency_root);
        balance_wallet_struct current_balance_key  = current_balance_struct.get();
        address account_wallet = current_balance_key.wallet;
        TIP3TokenWallet(account_wallet).balance{
             value: 0.1 ton, 
             bounce: true,
             flag: 0,
             callback: MetaduesAccount.onBalanceOf
        }();
    }

     function onBalanceOf(uint128 balance_) external {
        uint128 balance_wallet = balance_;
        optional(balance_wallet_struct) current_balance_struct = balance_map.fetch(msg.sender);
        balance_wallet_struct current_balance_key  = current_balance_struct.get();
        current_balance_key.balance = balance_wallet;
        balance_map[msg.sender] = current_balance_key;
    }

    function withdrawFunds(uint128 currency_root, uint128 withdraw_value_) external onlyOwner { 
        withdraw_value = withdraw_value_;
        ITokenRoot(currency_root).walletOf{
             value: 0.1 ton, 
             bounce: true,
             flag: 0,
             callback: MetaduesAccount.onWalleOfWithdraw
        }(account_owner);
    }        

    function onWalleOfWithdraw(address withdraw_owner_wallet) external {
        optional(balance_wallet_struct) current_balance_struct = balance_map.fetch(msg.sender);
        balance_wallet_struct current_balance_key  = current_balance_struct.get();
        address account_wallet = current_balance_key.wallet;
        TvmCell payload;
        ITokenWallet(account_wallet).transferToWallet{value: 0.5 ton}(withdraw_value,withdraw_owner_wallet,withdraw_owner_wallet, true, payload);
        withdraw_value = 0;
    }



    function destroyAccount()
        public
        onlyOwner
    {
     selfdestruct(msg.sender);    
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
        optional(balance_wallet_struct) current_balance_struct = balance_map.fetch(tokenRoot);
        if (current_balance_struct.hasValue()) {   
            balance_wallet_struct current_balance_key  = current_balance_struct.get();
            current_balance_key.balance += amount;    
            balance_map[tokenRoot] = current_balance_key;
        } else {
            balance_wallet_struct current_balance_struct;
            current_balance_struct.wallet = senderWallet;
            current_balance_struct.balance = amount;  
            balance_map[tokenRoot] = current_balance_struct;
        }
        
    }

    function _buildSubscriptionParams(address subscription_owner, address service_address) private inline pure returns (TvmCell) {
        TvmBuilder builder;
        builder.store(subscription_owner);
        builder.store(service_address);
        return builder.toCell();
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
   modifier onlyOwner() {
        tvm.accept();
        _;
    }

}
