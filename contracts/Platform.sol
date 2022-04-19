pragma ton-solidity >=0.39.0;

import "libraries/MsgFlag.sol";
import "libraries/MetaduesErrors.sol";

contract Platform {
    address static root;
    uint8 static type_id;
    TvmCell static platform_params;

    constructor(
        TvmCell code,
        TvmCell contract_params,
        uint32 version,
        address send_gas_to
    ) public {
        require(msg.sender == root, MetaduesErrors.error_message_sender_is_not_metadues_root);
        if (msg.sender == root) {
            _initialize(code, contract_params, version, send_gas_to);
        } else {
            send_gas_to.transfer({
                value: 0,
                flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.DESTROY_IF_ZERO,
                bounce: false
            });
        }
    }

    function _initialize(
        TvmCell code,
        TvmCell contract_params,
        uint32 version,
        address send_gas_to
    ) private {
        TvmBuilder builder;

        builder.store(root);
        builder.store(send_gas_to);
        builder.store(uint32(0));
        builder.store(version);
        builder.store(type_id);
        builder.store(tvm.code());
        builder.store(platform_params);
        builder.store(contract_params);
        builder.store(code);

        tvm.setcode(code);
        tvm.setCurrentCode(code);

        onCodeUpgrade(builder.toCell());
    }

    function onCodeUpgrade(TvmCell data) private {}
}
