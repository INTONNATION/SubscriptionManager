pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/MetaduesErrors.sol";
import "libraries/MetaduesGas.sol";
import "libraries/MsgFlag.sol";

contract SubscriptionIdentificatorIndex {
    address static subscription_owner;
    address public subscription_address;
    address public root;
    TvmCell public identificator;
    address public service_address;

    modifier onlyOwner() {
        require(
            msg.sender == subscription_address,
            MetaduesErrors.error_message_sender_is_not_owner
        );
        _;
    }

    constructor(address subsAddr) public {
        optional(TvmCell) salt = tvm.codeSalt(tvm.code());
        (address service_, TvmCell identificator_, address root_) = salt.get().toSlice().decode(
            address,
            TvmCell,
            address
        );
        require(
            msg.sender == root_,
            MetaduesErrors.error_message_sender_is_not_root
        );
        tvm.rawReserve(MetaduesGas.INDEX_INITIAL_BALANCE, 2);
        service_address = service_;
        root = root_;
        identificator = identificator_;
        subscription_address = subsAddr;
        subscription_owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS});
    }

    function upgrade(TvmCell code) external onlyOwner {
        tvm.rawReserve(MetaduesGas.INDEX_INITIAL_BALANCE, 2);
        TvmBuilder builder;
        builder.store(code);
        builder.store(root);
        builder.store(subscription_owner);
        builder.store(subscription_address);
        builder.store(identificator);
        tvm.setcode(code);
        tvm.setCurrentCode(code);
        onCodeUpgrade(builder.toCell());
    }

    function onCodeUpgrade(TvmCell upgrade_data) private {}

    function cancel() public onlyOwner {
        selfdestruct(subscription_owner);
    }
}