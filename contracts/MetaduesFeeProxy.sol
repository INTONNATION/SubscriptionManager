pragma ton-solidity >= 0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;


import "libraries/MetaduesRootErrors.sol";
import "./Platform.sol";
import "libraries/PlatformTypes.sol";
import "TIP3/interfaces/ITokenWallet.sol";


contract MetaduesFeeProxy {
   
    mapping(address => uint128) balance_map;
    address public root;
    TvmCell platform_code;
    TvmCell platform_params;
    uint32 current_version;
    uint8 type_id;

    constructor() public { revert(); }
    
    function fee(TvmCell params) public returns (TvmCell){
}
