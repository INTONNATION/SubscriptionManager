pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/SubscriptionErrors.sol";


interface ISubscriptionContract {
    function cancel () external;
}


contract SubscriptionIndex {
    
    struct ServiceParams {
        address to;
        uint128 value;
        uint32 period;
        string name;
        string description;
        TvmCell subscription_indificator;
        string image;
        string currency;
        string category;
    }
    TvmCell public static params;
    TvmCell public static subscription_indificator;
    address public ownerAddress;
    address public subscription_addr;
    ServiceParams public svcparams;

    modifier onlyOwner {
		require(msg.sender == ownerAddress, SubscriptionErrors.error_message_sender_is_not_my_owner);
		_;
    }

    constructor(address subsAddr, address ownerAddress_) public {
        require(msg.value >= 0.5 ton, SubscriptionErrors.error_not_enough_balance_in_message);
        optional(TvmCell) salt = tvm.codeSalt(tvm.code());
        require(salt.hasValue(), SubscriptionErrors.error_salt_is_empty);
        (address owner_address, address subsmanAddr) = salt.get().toSlice().decode(address, address);
        require(subsAddr != address(0), SubscriptionErrors.incorrect_subscription_address_in_constructor);
        require(ownerAddress_ == owner_address, SubscriptionErrors.error_define_owner_address_in_static_vars);
        require(subsmanAddr == msg.sender, SubscriptionErrors.error_message_sender_is_not_subsman);
        svcparams.subscription_indificator = subscription_indificator;
        subscription_addr = subsAddr;
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
        ownerAddress = ownerAddress_;
    }

    function cancel() public onlyOwner {
        ISubscriptionContract(subscription_addr).cancel();
        selfdestruct(ownerAddress);
    }
}
