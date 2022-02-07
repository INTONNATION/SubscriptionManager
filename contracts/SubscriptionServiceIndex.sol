pragma ton-solidity >= 0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/SubscriptionServiceErrors.sol";
import "libraries/Upgradable.sol";


interface ISubscriptionServiceContract {
    function selfdelete () external;
}


contract SubscriptionServiceIndex is Upgradable {

    address public serviceAddress;
    address public serviceOwner;

    modifier onlyOwner {
		require(msg.sender == serviceOwner, SubscriptionServiceErrors.error_message_sender_is_not_service_owner);
		_;
    }

    constructor(address serviceAddress_, address senderAddress) public {
        require(msg.value >= 0.02 ton, SubscriptionServiceErrors.error_low_message_value);
        optional(TvmCell) salt = tvm.codeSalt(tvm.code());
        require(salt.hasValue(), SubscriptionServiceErrors.error_salt_is_empty);
        (address ownerAddress, address subsmanAddr) = salt.get().toSlice().decode(address, address);
        require(msg.sender == subsmanAddr, SubscriptionServiceErrors.error_message_sender_is_not_subsman);
        require(ownerAddress == senderAddress, SubscriptionServiceErrors.error_define_owner_in_salt);
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