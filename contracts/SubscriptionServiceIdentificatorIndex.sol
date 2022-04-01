pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/SubscriptionServiceErrors.sol";
import "libraries/MetaduesGas.sol";
import "libraries/MsgFlag.sol";

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
            msg.value >= MetaduesGas.INDEX_INITIAL_BALANCE,
            1111
        );
        optional(TvmCell) salt = tvm.codeSalt(tvm.code());
        require(salt.hasValue(), SubscriptionServiceErrors.error_salt_is_empty);
        (TvmCell identificator_, address root_) = salt
            .get()
            .toSlice()
            .decode(TvmCell, address);
        require(
            msg.sender == root_,
            SubscriptionServiceErrors.error_message_sender_is_not_metadues_root
        );
        tvm.rawReserve(MetaduesGas.INDEX_INITIAL_BALANCE, 2);
        root = root_;
        service_address = serviceAddress_;
        identificator = identificator_;
        service_owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS});
    }

    function cancel() external onlyOwner {
        selfdestruct(service_owner);
    }

    function upgrade(TvmCell code) external onlyOwner {
        tvm.rawReserve(MetaduesGas.INDEX_INITIAL_BALANCE, 2);
        TvmBuilder builder;
        builder.store(code);
        builder.store(root);
        builder.store(service_owner);
        builder.store(service_address);
        builder.store(identificator);
        tvm.setcode(code);
        tvm.setCurrentCode(code);
        onCodeUpgrade(builder.toCell());
    }

    function onCodeUpgrade(TvmCell upgrade_data) private {}
}
