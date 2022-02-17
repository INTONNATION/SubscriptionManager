pragma ton-solidity >= 0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/SubscriptionErrors.sol";

contract SubscriptionIndex {
    
    address static subscription_owner;
    address public subscription_address;
    address public root;
    address public service_address;

    modifier onlyOwner {
		require(msg.sender == subscription_address, SubscriptionErrors.error_message_sender_is_not_my_owner);
		_;
    }

    constructor(address subscription_address_) public { 
        optional(TvmCell) salt = tvm.codeSalt(tvm.code());
        (address service_address_, address root_) = salt.get().toSlice().decode(address, address);
        require(msg.sender == root_, SubscriptionErrors.error_message_sender_is_not_root);
        root = root_;
        service_address = service_address_;
        subscription_address = subscription_address_;
    }

    function cancel() public onlyOwner {
        selfdestruct(subscription_address);
    }
}
