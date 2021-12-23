pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

interface ISubscriptionContract {
    function cancel () external;
}

contract SubscriptionIndex {

    TvmCell public static params;
    address public static user_wallet;
    TvmCell public static subscription_indificator;
    uint256 public ownerKey;
    address public subscription_addr;
    ServiceParams public svcparams;

    struct ServiceParams {
        uint256 to;
        uint128 value;
        uint32 period;
        string name;
        string description;
        TvmCell subscription_indificator;
        string image;
        string currency;
        string category;
    }

    modifier onlyOwner {
		require(msg.pubkey() == tvm.pubkey(), 100);
		tvm.accept();
		_;
    }

    constructor(bytes signature, address subsAddr) public {
        require(msg.value >= 0.5 ton, 102);
        require(msg.sender != address(0), 103);
        TvmCell code = tvm.code();
        optional(TvmCell) salt = tvm.codeSalt(code);
        require(salt.hasValue(), 104);
        ownerKey = salt.get().toSlice().decode(uint256);
        require(tvm.checkSign(tvm.hash(code), signature.toSlice(), tvm.pubkey()), 105);
        require(tvm.checkSign(tvm.hash(code), signature.toSlice(), ownerKey), 106);
        require(subsAddr != address(0), 108);
        svcparams.subscription_indificator = subscription_indificator;
        subscription_addr = subsAddr;
	    TvmCell nextCell;
        (svcparams.to, svcparams.value, svcparams.period, nextCell) = params.toSlice().decode(uint256, uint128, uint32, TvmCell);
        TvmCell nextCell2;
        (svcparams.name, svcparams.description, svcparams.image, nextCell2) = nextCell.toSlice().decode(string, string, string, TvmCell);
        (svcparams.currency, svcparams.category) = nextCell2.toSlice().decode(string, string);
    }

    function cancel() public onlyOwner {
        ISubscriptionContract(subscription_addr).cancel();
        selfdestruct(user_wallet);
    }
}
