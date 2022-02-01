pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/SubscriptionErrors.sol";

contract SubscriptionidentificatorIndex {
    

    address public ownerAddress;
    address public subscription_addr;

    modifier onlyOwner {
		require(msg.sender == subscription_addr, SubscriptionErrors.error_message_sender_is_not_index);
		_;
    }

    constructor(address subsAddr, address senderAddress) public {
        optional(TvmCell) salt = tvm.codeSalt(tvm.code());
        (TvmCell identificator, address root) = salt.get().toSlice().decode(TvmCell, address);
        subscription_addr = subsAddr;
    }

    function cancel() public onlyOwner {
        selfdestruct(subscription_addr);
    }
}
