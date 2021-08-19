pragma ton-solidity >=0.47.0;

contract SubscriptionService {

    TvmCell static params;
    uint256 static serviceKey;

    struct ServiceParams {
        address to;
        uint128 value;
        uint32 period;
    }

    function getParams() public view returns (ServiceParams){
        ServiceParams svcparams;
        (svcparams.to, svcparams.value, svcparams.period) = params.toSlice().decode(address, uint128, uint32);
        return svcparams;
    }

    constructor(bytes signature) public {
        TvmCell code = tvm.code();
        require(msg.sender != address(0), 101);
        require(tvm.checkSign(tvm.hash(code), signature.toSlice(), tvm.pubkey()), 102);
        require(tvm.checkSign(tvm.hash(code), signature.toSlice(), serviceKey), 103);
    }
}