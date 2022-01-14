pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/SubscriptionServiceErrors.sol";
import "libraries/Upgradable.sol";


contract SubscriptionService is Upgradable {

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
    TvmCell static params;
    address static serviceOwner;
    string static public serviceCategory;
    ServiceParams public svcparams;
    address public subscriptionServiceIndexAddress;

    constructor(address subscriptionServiceIndexAddress_, address senderAddress) public {
        require(msg.value >= 0.02 ton, SubscriptionServiceErrors.error_low_message_value);
        optional(TvmCell) salt = tvm.codeSalt(tvm.code());
        require(salt.hasValue(), SubscriptionServiceErrors.error_salt_is_empty);
        (, address subsmanAddr) = salt.get().toSlice().decode(string, address);
        require(msg.sender == subsmanAddr, SubscriptionServiceErrors.error_define_owner_in_salt);
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
        subscriptionServiceIndexAddress = subscriptionServiceIndexAddress_;
    }

    function selfdelete() public {
        require(msg.sender == subscriptionServiceIndexAddress, SubscriptionServiceErrors.error_message_sender_is_not_index);
        selfdestruct(msg.sender);
    }

    function onCodeUpgrade() internal override {
        tvm.resetStorage();
    }
    
}
