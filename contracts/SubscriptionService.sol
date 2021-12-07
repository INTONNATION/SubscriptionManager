pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;
import "SubscriptionServiceIndex.sol";

contract SubscriptionService {

    TvmCell static params;
    uint256 static serviceKey;
    string static public serviceCategory;
    ServiceParams public svcparams;
    address subscriptionServiceIndexAddress;

    struct ServiceParams {
        address to;
        uint128 value;
        uint32 period;
        string name;
        string description;
        string image;
        string category;
    }

    modifier onlyOwner {
		require(msg.pubkey() == tvm.pubkey(), 100);
		tvm.accept();
		_;
    }

    constructor(TvmCell indexCode, bytes signature) public {
        require(msg.value >= 1 ton, 101);
        TvmCell code = tvm.code();
        require(msg.sender != address(0), 102);
        require(tvm.checkSign(tvm.hash(code), signature.toSlice(), tvm.pubkey()), 105);
        require(tvm.checkSign(tvm.hash(code), signature.toSlice(), serviceKey), 106);
        (svcparams.to, svcparams.value, svcparams.period, svcparams.name, svcparams.description, svcparams.image, svcparams.category) = params.toSlice().decode(address, uint128, uint32, string, string, string, string);
        TvmCell state = tvm.buildStateInit({
            code: indexCode,
            pubkey: tvm.pubkey(),
            varInit: { 
                params: params,
                serviceCategory: serviceCategory
            },
            contr: SubscriptionServiceIndex
        });
        TvmCell stateInit = tvm.insertPubkey(state, tvm.pubkey());
        subscriptionServiceIndexAddress = address(tvm.hash(stateInit));
        new SubscriptionServiceIndex{value: 0.5 ton, flag: 1, bounce: true, stateInit: stateInit}(signature,tvm.code());
    }

    function selfdelete() public {
        require(msg.sender == subscriptionServiceIndexAddress, 106);
        selfdestruct(svcparams.to);
    }
}
