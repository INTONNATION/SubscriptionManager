pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/SubscriptionServiceErrors.sol";

contract SubscriptionServiceIndex {
    string public static service_name;
    address public service_address;
    address public service_owner;

    modifier onlyOwner() {
        require(
            msg.sender == service_address,
            SubscriptionServiceErrors.error_message_sender_is_not_service_owner
        );
        _;
    }

    constructor(address serviceAddress_) public {
        require(
            msg.value >= 0.02 ton,
            SubscriptionServiceErrors.error_low_message_value
        );
        optional(TvmCell) salt = tvm.codeSalt(tvm.code());
        require(salt.hasValue(), SubscriptionServiceErrors.error_salt_is_empty);
        address root;
        (service_owner, root) = salt.get().toSlice().decode(address, address);
        require(
            msg.sender == root,
            SubscriptionServiceErrors.error_message_sender_is_not_metadues_root
        );
        service_address = serviceAddress_;
    }

    function cancel() external onlyOwner {
        selfdestruct(service_owner);
    }
}