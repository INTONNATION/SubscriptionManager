//pragma ton-solidity ^ 0.47.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;
import "SubscriptionServiceIndex.sol";

interface ISubscriptionServiceIndexContract {
    function cancel () external;
}

contract SubscriptionService {

    TvmCell static params;
    uint256 static serviceKey;
    ServiceParams public svcparams;
    address subscriptionServiceIndexAddress;

    struct ServiceParams {
        address to;
        uint128 value;
        uint32 period;
        string name;
        string description;
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
        require(tvm.checkSign(tvm.hash(code), signature.toSlice(), tvm.pubkey()), 103);
        require(tvm.checkSign(tvm.hash(code), signature.toSlice(), serviceKey), 104);
        (svcparams.to, svcparams.value, svcparams.period, svcparams.name, svcparams.description) = params.toSlice().decode(address, uint128, uint32, string, string);
        TvmCell state = tvm.buildStateInit({
            code: indexCode,
            pubkey: tvm.pubkey(),
            varInit: { 
                params: params
            },
            contr: SubscriptionServiceIndex
        });
        TvmCell stateInit = tvm.insertPubkey(state, tvm.pubkey());
        subscriptionServiceIndexAddress = address(tvm.hash(stateInit));
        new SubscriptionServiceIndex{value: 0.5 ton, flag: 1, bounce: true, stateInit: stateInit}(signature,tvm.code());
    }

    function selfdelete() public onlyOwner {
        if (msg.isInternal){
            require(msg.sender == subscriptionServiceIndexAddress, 106);
        } else {
            ISubscriptionServiceIndexContract(subscriptionServiceIndexAddress).cancel();
        }
        selfdestruct(svcparams.to);
    }
}
