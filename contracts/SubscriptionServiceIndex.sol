pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/SubscriptionServiceErrors.sol";
import "libraries/Upgradable.sol";


interface ISubscriptionServiceContract {
    function selfdelete () external;
}


contract SubscriptionServiceIndex is Upgradable {

    struct ServiceParams {
        address to;
        uint128 value;
        uint32 period;
        string name;
        string description;
        string image;
        string currency;
        string category;
    }
    ServiceParams public svcparams;
    TvmCell static public params;
    string static public serviceCategory;
    address public serviceAddress;
    address public serviceOwner;

    modifier onlyOwner {
		require(msg.sender == serviceOwner, SubscriptionServiceErrors.error_message_sender_is_not_service_owner);
		_;
    }

    constructor(address serviceAddress_, address senderAddress) public {
        optional(TvmCell) salt = tvm.codeSalt(tvm.code());
        require(salt.hasValue(), SubscriptionServiceErrors.error_salt_is_empty);
        (address ownerAddress, address subsmanAddr) = salt.get().toSlice().decode(address, address);
        require(msg.sender == subsmanAddr, SubscriptionServiceErrors.error_message_sender_is_not_subsman);
        require(ownerAddress == senderAddress, SubscriptionServiceErrors.error_define_owner_in_salt);
        TvmCell nextCell;
        (
            svcparams.to, 
            svcparams.value, 
            svcparams.period, 
            nextCell
        ) = params.toSlice().decode(
            address, 
            uint128, 
            uint32, 
            TvmCell
        );
        TvmCell nextCell2;
        (
            svcparams.name, 
            svcparams.description, 
            svcparams.image, 
            nextCell2
        ) = nextCell.toSlice().decode(
            string, 
            string, 
            string, 
            TvmCell
        );
        (svcparams.currency, svcparams.category) = nextCell2.toSlice().decode(string, string);
        serviceAddress = serviceAddress_;
        serviceOwner = ownerAddress;
    }

    function cancel() public onlyOwner {
        ISubscriptionServiceContract(serviceAddress).selfdelete();
        selfdestruct(serviceOwner);
    }

    function onCodeUpgrade() internal override {
        tvm.resetStorage();
    }
}