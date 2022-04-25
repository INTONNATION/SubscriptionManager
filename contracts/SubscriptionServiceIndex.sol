pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/MetaduesErrors.sol";
import "libraries/MetaduesGas.sol";
import "libraries/MsgFlag.sol";

contract SubscriptionServiceIndex {
    string public static service_name;
    address public service_address;
    address public service_owner;
    address public root;

    modifier onlyOwner() {
        require(
            msg.sender == service_address,
            MetaduesErrors.error_message_sender_is_not_service_owner
        );
        _;
    }

    constructor(address serviceAddress_) public {
        optional(TvmCell) salt = tvm.codeSalt(tvm.code());
        require(salt.hasValue(), MetaduesErrors.error_salt_is_empty);
        (address service_owner_, address root_) = salt.get().toSlice().decode(address, address);
        require(
            msg.sender == root_,
            MetaduesErrors.error_message_sender_is_not_metadues_root
        );
        tvm.rawReserve(MetaduesGas.INDEX_INITIAL_BALANCE, 2);
        service_owner = service_owner_;
        root = root_;
        service_address = serviceAddress_;
        service_owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS});
    }

    function cancel() external onlyOwner {
        selfdestruct(service_owner);
    }
}