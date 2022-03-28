pragma ton-solidity >= 0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/SubscriptionErrors.sol";

contract SubscriptionIdentificatorIndex {
    
    address static subscription_owner;
    address public subscription_address;
    address public root;
    TvmCell public identificator;


    modifier onlyOwner {
		require(msg.sender == subscription_address, SubscriptionErrors.error_message_sender_is_not_owner);
		_;
    }

    constructor(address subsAddr) public {
        optional(TvmCell) salt = tvm.codeSalt(tvm.code());
        (TvmCell identificator_, address root_) = salt.get().toSlice().decode(TvmCell, address);
        require(msg.sender == root_, SubscriptionErrors.error_message_sender_is_not_root);
        root = root_;
        identificator = identificator_;
        subscription_address = subsAddr;
    }

    function upgrade(TvmCell code, address send_gas_to) external onlyOwner {
        TvmBuilder builder;
        builder.store(send_gas_to);
        builder.store(code);
        tvm.setcode(code);
        tvm.setCurrentCode(code);
        onCodeUpgrade(builder.toCell());
    }

    function onCodeUpgrade(TvmCell upgrade_data) private {
    }

    function cancel() public onlyOwner {
        selfdestruct(subscription_owner);
    }
}
