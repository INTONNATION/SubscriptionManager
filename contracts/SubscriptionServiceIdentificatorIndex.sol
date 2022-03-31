pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/SubscriptionServiceErrors.sol";

contract SubscriptionServiceIdentificatorIndex {
    address static service_owner;
    address public service_address;
    address public root;
    TvmCell public identificator;

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
        (TvmCell identificator_, address metaduesRootAddr) = salt
            .get()
            .toSlice()
            .decode(TvmCell, address);
        require(
            msg.sender == metaduesRootAddr,
            SubscriptionServiceErrors.error_message_sender_is_not_metadues_root
        );
        service_address = serviceAddress_;
        identificator = identificator_;
    }

    function cancel() external onlyOwner {
        selfdestruct(service_owner);
    }

    function upgrade(TvmCell code, address send_gas_to) external onlyOwner {
        TvmBuilder builder;
        builder.store(send_gas_to);
        builder.store(code);
        tvm.setcode(code);
        tvm.setCurrentCode(code);
        onCodeUpgrade(builder.toCell());
    }

    function onCodeUpgrade(TvmCell upgrade_data) private {}
}
