pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;

contract configVersions {
  

    uint8 public versionTvc;
	uint8 public versionAbi;
        
	struct VersionsTvcParams {
		TvmCell tvcService;
		TvmCell tvcWallet;
		TvmCell tvcSubsciption;
		TvmCell tvcSubscriptionServiceIndex;
		TvmCell tvcSuscriptionIndex;

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

    function setTvc(TvmCell tvcServiceInput,TvmCell tvcWalletInput, TvmCell tvcSubsciptionInput, TvmCell tvcSubscriptionServiceIndexInput,TvmCell tvcSuscriptionIndexInput)  public onlyOwner {
		versionTvc++;
		VersionsTvcParams params;
		params.tvcService = tvcServiceInput;
		params.tvcWallet = tvcWalletInput;
		params.tvcSubsciption = tvcSubsciptionInput;
		params.tvcSubscriptionServiceIndex = tvcSubscriptionServiceIndexInput;
		params.tvcSuscriptionIndex = tvcSuscriptionIndexInput;
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

