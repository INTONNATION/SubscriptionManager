pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;

contract configVersions {
  

    uint8 public version;
        
	struct VersionsParams {
		TvmCell tvcService;
		TvmCell tvcWallet;
		TvmCell tvcSubsciption;
		TvmCell tvcSubscriptionServiceIndex;
		TvmCell tvcSuscriptionIndex;

}

	mapping (uint8 => VersionsParams) vrsparams;

	constructor() public {
		require(tvm.pubkey() != 0, 101);
		tvm.accept();
	}

    
    modifier onlyOwner {
		require(msg.pubkey() == tvm.pubkey(), 100);
		tvm.accept();
		_;
    }
    function getTvcLatest() public view returns(optional (VersionsParams)){
        optional(VersionsParams) value = vrsparams.fetch(version);
		return value;
    }

    function getVersions() public view returns (uint8[] arr ){
        for ((uint8 k,) : vrsparams) {
        arr.push(k);
        }
    }    
	
	function getTvcVersion(uint8 versionTvc) public view returns(optional (VersionsParams)){
        optional(VersionsParams) value = vrsparams.fetch(versionTvc);
		return value;
    }

    function setTvc(TvmCell tvcServiceInput,TvmCell tvcWalletInput, TvmCell tvcSubsciptionInput, TvmCell tvcSubscriptionServiceIndexInput,TvmCell tvcSuscriptionIndexInput)  public onlyOwner {
		version++;
		VersionsParams params;
		params.tvcService = tvcServiceInput;
		params.tvcWallet = tvcWalletInput;
		params.tvcSubsciption = tvcSubsciptionInput;
		params.tvcSubscriptionServiceIndex = tvcSubscriptionServiceIndexInput;
		params.tvcSuscriptionIndex = tvcSuscriptionIndexInput;
		vrsparams.add(version, params);
		
    }
}

