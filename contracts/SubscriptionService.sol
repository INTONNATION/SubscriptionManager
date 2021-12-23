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
        uint256 to;
        uint128 value;
        uint32 period;
        string name;
        string description;
        string image;
        string currency;
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
        TvmCell nextCell;
        (svcparams.to, svcparams.value, svcparams.period, nextCell) = params.toSlice().decode(uint256, uint128, uint32, TvmCell);
        TvmCell nextCell2;
        (svcparams.name, svcparams.description, svcparams.image, nextCell2) = nextCell.toSlice().decode(string, string, string, TvmCell);
        (svcparams.currency, svcparams.category) = nextCell2.toSlice().decode(string, string);
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
        selfdestruct(msg.sender);
    }
}
