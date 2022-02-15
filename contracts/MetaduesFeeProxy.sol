pragma ton-solidity >= 0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;


import "libraries/MetaduesFeeErrors.sol";
import "./Platform.sol";
import "libraries/PlatformTypes.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenWallet.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenRoot.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/TIP3TokenWallet.sol";


contract MetaduesFeeProxy {
   
    address public root;
    TvmCell platform_code;
    TvmCell platform_params;
    uint32 current_version;
    uint8 type_id;
    
    mapping(address => address) public wallets_mapping;

    constructor() public { revert(); }

    modifier onlyRoot() {
        require(msg.sender == root, 111);
        _;
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
        TvmSlice contract_params = s.loadRefAsSlice();  
        TvmCell current_code = s.loadRef();
        current_version = version;  
        type_id = type_id_;
        (address[] supportedCurrencies) = contract_params.decode(address[]);
        if (old_version != 0) {
            TvmSlice old_data = s.loadRefAsSlice();
            mapping(address => address) wallets_mapping_ = old_data.decode(mapping(address => address));
            wallets_mapping = wallets_mapping_;
        }
        //send_gas_to.transfer({ value: 0, flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS });
        updateSupportedCurrencies(supportedCurrencies);
    }

    function upgrade(TvmCell code, TvmCell contract_params, uint32 version, address send_gas_to) external onlyRoot {

        TvmBuilder builder;
        TvmBuilder upgrade_params;
        builder.store(root);
        builder.store(send_gas_to);
        builder.store(current_version); 
        builder.store(version);
        builder.store(type_id);
        builder.store(platform_code);
        builder.store(platform_params);
        builder.store(code);
        upgrade_params.store(wallets_mapping);
        builder.store(upgrade_params.toCell());
        tvm.setcode(code);
        tvm.setCurrentCode(code);

        onCodeUpgrade(builder.toCell());
    }

    function updateSupportedCurrencies(address[] currencies) private {
        for (address currency_root : currencies) { // iteration over the array
            optional(address) currency_root_wallet_opt = wallets_mapping.fetch(currency_root);
            if (!currency_root_wallet_opt.hasValue()){
                ITokenRoot(currency_root).deployWallet{
                    value: 0.2 ton,
                    bounce: true,
                    flag: 0,
                    callback: MetaduesFeeProxy.onDeployWallet
                }(
                    address(this),
                    0.1 ton
                );
            }
        }
    }

    function onDeployWallet(address wallet_address) external {
        //require only from root
        wallets_mapping[msg.sender] = wallet_address;
    }
}
