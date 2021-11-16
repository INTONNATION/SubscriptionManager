//pragma ton-solidity ^ 0.47.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

interface ISubscriptionServiceContract {
    function selfdelete () external;
}

contract SubscriptionServiceIndex {
    ServiceParams public svcparams;
    struct ServiceParams {
        address to;
        uint128 value;
        uint32 period;
        string name;
        string description;
        string image;
    }
    TvmCell public static params;
    string static public serviceCategory;
    address serviceAddress;

    modifier onlyOwner {
		require(msg.pubkey() == tvm.pubkey(), 100);
		tvm.accept();
		_;
    }

    constructor(bytes signature,TvmCell svcCode) public {
        require(msg.sender != address(0), 101);
        require(tvm.checkSign(tvm.hash(svcCode), signature.toSlice(), tvm.pubkey()), 102);
        (svcparams.to, svcparams.value, svcparams.period, svcparams.name, svcparams.description, svcparams.image) = params.toSlice().decode(address, uint128, uint32, string, string, string);
        serviceAddress = msg.sender;
    }

    function cancel() public onlyOwner {
        ISubscriptionServiceContract(serviceAddress).selfdelete();
        selfdestruct(svcparams.to);
    }
}