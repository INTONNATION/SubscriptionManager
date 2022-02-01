pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/SubscriptionServiceErrors.sol";


contract SubscriptionService {

    struct ServiceParams {
        address to;
        uint128 value;
        uint32 period;
        string name;
        string description;
        string image;
        address currency_root;
        string category;
    }
    address public root;
    address public owner_address;
    TvmCell platform_code;
    TvmCell platform_params;
    TvmCell code;
    uint32 current_version;
    uint8 type_id;
    TvmCell public service_params;

    ServiceParams public svcparams;

    constructor() public { revert(); }

    function selfdelete() public {
        selfdestruct(msg.sender);
    }

    
    function getParams() public view responsible returns (TvmCell) {
        return{value: 0, bounce: false, flag: 64} service_params;
    }

    function getStatus() public view responsible returns (uint8){
        return{value: 0, bounce: false, flag: 64} 0;  
    }


    function onCodeUpgrade(TvmCell upgrade_data) private {
        TvmSlice s = upgrade_data.toSlice();
        (address root_, address send_gas_to, uint32 old_version, uint32 version, uint8 type_id_ ) =
        s.decode(address,address,uint32,uint32,uint8);

        if (old_version == 0) {
            tvm.resetStorage();
        }

        root = root_;
        current_version = version;  
        type_id = type_id_;
        TvmCell nextCell;
        address service_owner;
        platform_code = s.loadRef();
        platform_params = s.loadRef();
        (service_owner, svcparams.name) = platform_params.toSlice().decode(address, string);
        service_params = s.loadRef();
        (
            svcparams.to, 
            svcparams.value, 
            svcparams.period, 
            nextCell
        ) = service_params.toSlice().decode(
            address,
            uint128,
            uint32,
            TvmCell
        );
        TvmCell nextCell2;
        (
            , 
            svcparams.description, 
            svcparams.image, 
            nextCell2
        ) = nextCell.toSlice().decode(
            string, 
            string, 
            string, 
            TvmCell
        );
        (svcparams.currency_root, svcparams.category) = nextCell2.toSlice().decode(address, string);
      //  subscriptionServiceIndexAddress = subscriptionServiceIndexAddress_;
    }
     
     function updateServiceParams(TvmCell new_service_params) public onlyOwner{
        TvmCell nextCell;
        (
            svcparams.to, 
            svcparams.value, 
            svcparams.period, 
            nextCell
        ) = new_service_params.toSlice().decode(
            address,
            uint128,
            uint32,
            TvmCell
        );
        TvmCell nextCell2;
        (
            , 
            svcparams.description, 
            svcparams.image, 
            nextCell2
        ) = nextCell.toSlice().decode(
            string, 
            string, 
            string, 
            TvmCell
        );
        (svcparams.currency_root, svcparams.category) = nextCell2.toSlice().decode(address, string);           


     }

     modifier onlyOwner() {
        tvm.accept();
        _;
    }

}
