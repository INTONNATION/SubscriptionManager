pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/SubscriptionErrors.sol";

contract SubscriptionidentificatorIndex {
    
    struct ServiceParams {
        address to;
        uint128 value;
        uint32 period;
        string name;
        string description;
        TvmCell subscription_identificator;
        string image;
        string currency;
        string category;
    }
    TvmCell static params;
    TvmCell static subscription_identificator;
    address public ownerAddress;
    address public subscription_addr;
    ServiceParams public svcparams;

    modifier onlyOwner {
		require(msg.sender == subscription_addr, SubscriptionErrors.error_message_sender_is_not_index);
		_;
    }

    constructor(address subsAddr, address senderAddress) public {
        require(msg.value >= 0.02 ton, SubscriptionErrors.error_not_enough_balance_in_message);
        optional(TvmCell) salt = tvm.codeSalt(tvm.code());
        require(salt.hasValue(), SubscriptionErrors.error_salt_is_empty);
        (TvmCell identificator, address subsmanAddr) = salt.get().toSlice().decode(TvmCell, address);
        require(subsAddr != address(0), SubscriptionErrors.incorrect_subscription_address_in_constructor);
        require(subsmanAddr == msg.sender, SubscriptionErrors.error_message_sender_is_not_subsman);
	    require(identificator == subscription_identificator, SubscriptionErrors.error_salt_is_not_match_static_var);
        svcparams.subscription_identificator = subscription_identificator;
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
    }

    function cancel() public onlyOwner {
        selfdestruct(subscription_addr);
    }
}
