pragma ton-solidity >= 0.39.0;

import "libraries/MsgFlag.sol";


contract Platform {
    address static root;
    uint8 static type_id;
    TvmCell static params;
    TvmCell platform_code;

    constructor() public onlyRoot {   
        tvm.accept();
        platform_code = tvm.code();
    }

    function initialize(TvmCell code, uint32 version, address send_gas_to) external onlyRoot {

        TvmBuilder builder;

        builder.store(root);
        builder.store(send_gas_to);
        builder.store(uint32(0)); 
        builder.store(version);
        builder.store(type_id);
        builder.store(platform_code);
        builder.store(params);

        tvm.setcode(code);
        tvm.setCurrentCode(code);

        onCodeUpgrade(builder.toCell());
    }

    function onCodeUpgrade(TvmCell data) private {}

    modifier onlyRoot() {
        require(msg.sender == root, 111);
        _;
    }
}