pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;


interface ISubscriptionServiceContract {
    function selfdelete () external;
}


contract SubscriptionServiceIndex {

    struct ServiceParams {
        uint256 to;
        uint128 value;
        uint32 period;
        string name;
        string description;
        string image;
        string currency;
        string category;
    }
    ServiceParams public svcparams;
    TvmCell static public params;
    string static public serviceCategory;
    address public serviceAddress;

    modifier onlyOwner {
		require(msg.pubkey() == tvm.pubkey(), 100);
		tvm.accept();
		_;
    }

    constructor(bytes signature,TvmCell svcCode) public {
        require(msg.sender != address(0), 101);
        require(tvm.checkSign(tvm.hash(svcCode), signature.toSlice(), tvm.pubkey()), 103);
        TvmCell nextCell;
        (
            svcparams.to, 
            svcparams.value, 
            svcparams.period, 
            nextCell
        ) = params.toSlice().decode(
            uint256, 
            uint128, 
            uint32, 
            TvmCell
        );
        TvmCell nextCell2;
        (
            svcparams.name, 
            svcparams.description, 
            svcparams.image, 
            nextCell2
        ) = nextCell.toSlice().decode(
            string, 
            string, 
            string, 
            TvmCell
        );
        (svcparams.currency, svcparams.category) = nextCell2.toSlice().decode(string, string);
        serviceAddress = msg.sender;
    }

    function cancel() public onlyOwner {
        ISubscriptionServiceContract(serviceAddress).selfdelete();
        selfdestruct(serviceAddress);
    }
}