pragma ton-solidity >= 0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/SubscriptionErrors.sol";

contract SubscriptionIndex {
    
    address public subscription_addr;

    modifier onlyOwner {
		require(msg.sender == subscription_addr, SubscriptionErrors.error_message_sender_is_not_my_owner);
		_;
    }

    constructor(address subsAddr, address senderAddress) public { 
        optional(TvmCell) salt = tvm.codeSalt(tvm.code());
        (address service_address, address root) = salt.get().toSlice().decode(address, address);
        subscription_addr = subsAddr;
    }

    function cancel() public onlyOwner {
        selfdestruct(subscription_addr);
    }
}
