pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/SubscriptionErrors.sol";


contract SubscriptionIndificatorIndex {
    
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
    address subscriptionIndexAddress;

    constructor(address subsAddr, address subscriptionIndexAddressINPUT) public {
        require(msg.value >= 0.5 ton, SubscriptionErrors.error_not_enough_balance_in_message);
        optional(TvmCell) salt = tvm.codeSalt(tvm.code());
        require(salt.hasValue(), SubscriptionErrors.error_salt_is_empty);
        (TvmCell indificator, address subsmanAddr) = salt.get().toSlice().decode(TvmCell, address);
        require(subsAddr != address(0), SubscriptionErrors.incorrect_subscription_address_in_constructor);
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
        subscriptionIndexAddress = subscriptionIndexAddressINPUT;
    }

    function cancel() public {
        require(msg.sender == subscriptionIndexAddress, SubscriptionErrors.error_message_sender_is_not_index);
        selfdestruct(subscription_addr);
    }
}
