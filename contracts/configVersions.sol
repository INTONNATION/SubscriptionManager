pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;

contract configVersions {
  

    uint8 public versionTvc;
	uint8 public versionAbi;
        
	struct VersionsTvcParams {
		TvmCell tvcSubscriptionService;
		TvmCell tvcWallet;
		TvmCell tvcSubscription;
		TvmCell tvcSubscriptionServiceIndex;
		TvmCell tvcSubscriptionIndex;

}

	struct VersionsAbiParams {
		string abiServiceContract;
		string abiServiceIndexContract;
		string abiSubscriptionIndexContract;
		string abiSubsManDebot;

}
	mapping (uint8 => VersionsTvcParams) public vrsparamsTvc;
    mapping (uint8 => VersionsAbiParams) public vrsparamsAbi;

	constructor() public {
		require(tvm.pubkey() != 0, 101);
		tvm.accept();
	}

    
    modifier onlyOwner {
		require(msg.pubkey() == tvm.pubkey(), 100);
		tvm.accept();
		_;
    }
    function getTvcLatest() public view returns(optional (VersionsTvcParams)){
        optional(VersionsTvcParams) value = vrsparamsTvc.fetch(versionTvc);
		return value;
    }

	function getAbiLatest() public view returns(optional (VersionsAbiParams)){
        optional(VersionsAbiParams) value = vrsparamsAbi.fetch(versionAbi);
		return value;
    }

    function getTvcVersions() public view returns (uint8[] arr ){
        for ((uint8 k,) : vrsparamsTvc) {
        arr.push(k);
        }
    }   

    function getAbiVersions() public view returns (uint8[] arr ){
        for ((uint8 k,) : vrsparamsAbi) {
        arr.push(k);
        }
    }     
	
	function getTvcVersion(uint8 tvcVersion) public view returns(optional (VersionsTvcParams)){
        optional(VersionsTvcParams) value = vrsparamsTvc.fetch(tvcVersion);
		return value;
    }
    function getAbiVersion(uint8 AbiVersion) public view returns(optional (VersionsAbiParams)){
        optional(VersionsAbiParams) value = vrsparamsAbi.fetch(AbiVersion);
		return value;
    }

    function setTvc(TvmCell tvcSubscriptionServiceInput,TvmCell tvcWalletInput, TvmCell tvcSubscriptionInput, TvmCell tvcSubscriptionServiceIndexInput,TvmCell tvcSubscriptionIndexInput)  public onlyOwner {
		versionTvc++;
		VersionsTvcParams params;
		params.tvcSubscriptionService = tvcSubscriptionServiceInput;
		params.tvcWallet = tvcWalletInput;
		params.tvcSubscription = tvcSubscriptionInput;
		params.tvcSubscriptionServiceIndex = tvcSubscriptionServiceIndexInput;
		params.tvcSubscriptionIndex = tvcSubscriptionIndexInput;
		vrsparamsTvc.add(versionTvc, params);
		
    }
    function setAbi(string abiServiceContractInput, string abiServiceIndexContractInput, string abiSubscriptionIndexContractInput,string abiSubsManDebotInput)  public onlyOwner {
		versionAbi++;
		VersionsAbiParams params;
		params.abiServiceContract = abiServiceContractInput;
		params.abiServiceIndexContract = abiServiceIndexContractInput;
		params.abiSubscriptionIndexContract = abiSubscriptionIndexContractInput;
		params.abiSubsManDebot = abiSubsManDebotInput;
		vrsparamsAbi.add(versionAbi, params);
		
    }
}

