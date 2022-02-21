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
import "./interfaces/IDexRoot.sol";
import "./libraries/DexOperationTypes.sol";


contract MetaduesFeeProxy {
   
    address public root;
    TvmCell platform_code;
    TvmCell platform_params;
    uint32 current_version;
    uint8 type_id;
    address mtds_root_address;
    address sync_balance_currency_root; // mutex
    address dex_root_address;

    mapping(address => balance_wallet_struct) public wallets_mapping;

    struct balance_wallet_struct {
        address wallet;
        uint128 balance;
    }

    constructor() public { revert(); }

    modifier onlyRoot() {
        require(msg.sender == root, 111);
        _;
    }
    
    modifier onlyDexRoot() {
        require(msg.sender == dex_root_address, 222);
        _;
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
        optional(balance_wallet_struct) current_balance_struct = wallets_mapping.fetch(tokenRoot);
        if (current_balance_struct.hasValue()) {   
            balance_wallet_struct current_balance_key  = current_balance_struct.get();
            current_balance_key.balance += amount;    
            wallets_mapping[tokenRoot] = current_balance_key;
        }
    }

    function swapRevenueToMTDS(address currency_root) external onlyRoot {
        require(sync_balance_currency_root == address(0), 335); // mutex
        sync_balance_currency_root = currency_root; // critical area
        optional(balance_wallet_struct) current_balance_struct_opt = wallets_mapping.fetch(currency_root); 
        if (current_balance_struct_opt.hasValue()){
            balance_wallet_struct current_balance_struct  = current_balance_struct_opt.get();
            if (current_balance_struct.balance > 0) {
                IDexRoot(dex_root_address).getExpectedPairAddress{
                    value: 0.1 ton, 
                    bounce: true,
                    flag: 0,
                    callback: MetaduesFeeProxy.onGetExpectedPairAddress
                }(mtds_root_address,currency_root);
            }
        } else {
            tvm.exit1();
        }
    }
    
    function onGetExpectedPairAddress(address dex_pair_address) external onlyDexRoot {
        TvmBuilder builder;
        builder.store(DexOperationTypes.EXCHANGE);
        builder.store(uint64(0));
        builder.store(uint128(0));
        builder.store(uint128(0));

        optional(balance_wallet_struct) current_balance_struct = wallets_mapping.fetch(sync_balance_currency_root);
        balance_wallet_struct current_balance_key = current_balance_struct.get();
        ITokenWallet(current_balance_key.wallet).transfer{
            value:  2.5 ton,
            flag: 0
        }(
            current_balance_key.balance, // amount
            dex_pair_address,            // recipient
            0,                           // deployWalletValue
            root,                        // remainingGasTo
            true,                        // notify
            builder.toCell()             // payload
        );
        current_balance_key.balance = 0;
        wallets_mapping[sync_balance_currency_root] = current_balance_key;
        sync_balance_currency_root = address(0); // free mutex
    }

    function syncBalance(address currency_root) external onlyRoot {
        require(sync_balance_currency_root == address(0), 335); // mutex
        sync_balance_currency_root = currency_root; // critical area
        optional(balance_wallet_struct) current_balance_struct = wallets_mapping.fetch(currency_root);
        balance_wallet_struct current_balance_key  = current_balance_struct.get();
        address account_wallet = current_balance_key.wallet;
        TIP3TokenWallet(account_wallet).balance{
             value: 0.1 ton, 
             bounce: true,
             flag: 0,
             callback: MetaduesFeeProxy.onBalanceOf
        }();
    }

    function setMTDSRootAddress(address mtds_root) external onlyRoot {
        mtds_root_address = mtds_root;
    }

    function setDexRootAddress(address dex_root) external onlyRoot {
        dex_root_address = dex_root;
    }

    function onBalanceOf(uint128 balance_) external {
        uint128 balance_wallet = balance_;
        optional(balance_wallet_struct) current_balance_struct = wallets_mapping.fetch(sync_balance_currency_root);
        balance_wallet_struct current_balance_key  = current_balance_struct.get();
        current_balance_key.balance = balance_wallet;
        wallets_mapping[sync_balance_currency_root] = current_balance_key;
        sync_balance_currency_root = address(0); // free mutex
    }

    function transferRevenue(address revenue_to) external onlyRoot {
        optional(balance_wallet_struct) currency_root_wallet_opt = wallets_mapping.fetch(mtds_root_address);
        if (!currency_root_wallet_opt.hasValue()){
            balance_wallet_struct currency_root_wallet_struct = currency_root_wallet_opt.get();
            TvmCell payload;
            ITokenWallet(currency_root_wallet_struct.wallet).transfer{value: 0.5 ton}(
                currency_root_wallet_struct.balance,
                revenue_to,
                0,
                root,
                true,
                payload
            );
        }
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
            mapping(address => balance_wallet_struct) wallets_mapping_ = old_data.decode(mapping(address => balance_wallet_struct));
            wallets_mapping = wallets_mapping_;
        }
        //send_gas_to.transfer({ value: 0, flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS });
       updateSupportedCurrencies(supportedCurrencies);
    }

    function upgrade(TvmCell code,  uint32 version, address send_gas_to) external onlyRoot {
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
            optional(balance_wallet_struct) currency_root_wallet_opt = wallets_mapping.fetch(currency_root);
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

    
    function setSupportedCurrencies(TvmCell fee_proxy_contract_params) external onlyRoot {
        (address[] currencies) = fee_proxy_contract_params.toSlice().decode(address[]);
        for (address currency_root : currencies) { // iteration over the array
            optional(balance_wallet_struct) currency_root_wallet_opt = wallets_mapping.fetch(currency_root);
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
        wallets_mapping[msg.sender].wallet = wallet_address;
        wallets_mapping[msg.sender].balance = 0;
    }
}
