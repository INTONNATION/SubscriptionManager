pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;


contract configVersions {
  
    uint8 public versionTvc;
	uint8 public versionAbi;
	struct VersionsTvcParams {
		TvmCell tvcSubscriptionService;
		TvmCell tvcSubscription;
		TvmCell tvcSubscriptionServiceIndex;
		TvmCell tvcSubscriptionIndex;
	}
	struct VersionsAbiParams {
		string abiServiceContract;
		string abiServiceIndexContract;
		string abiSubscriptionContract;
		string abiSubscriptionIndexContract;
		string abiSubsManDebot;
	}
	string[] public categories;
	mapping (uint8 => VersionsTvcParams) public vrsparamsTvc;
    mapping (uint8 => VersionsAbiParams) public vrsparamsAbi;

    modifier onlyOwner {
		require(msg.pubkey() == tvm.pubkey(), 100);
		tvm.accept();
		_;
    }

	constructor() public {
		require(msg.pubkey() == tvm.pubkey(), 100);
		tvm.accept();
	}
    
	// Get all latest TVCs
    function getTvcsLatest() public view returns(optional(VersionsTvcParams)){
        optional(VersionsTvcParams) value = vrsparamsTvc.fetch(versionTvc);
		return value;
    }

	// Get all latest TVCs
    function getTvcsLatestResponsible() external view responsible returns(VersionsTvcParams){
        VersionsTvcParams value = vrsparamsTvc[versionTvc];
		return{value: 0, flag: 64}(value);
    }

	// Get all latest ABIs
	function getAbisLatest() public view returns(optional(VersionsAbiParams)){
        optional(VersionsAbiParams) value = vrsparamsAbi.fetch(versionAbi);
		return value;
    }

	// Get just list of versions
    function getTvcVersionsOnly() public view returns (uint8[] arr){
        for ((uint8 k,) : vrsparamsTvc) {
        	arr.push(k);
        }
    }

    function getAbiVersionsOnly() public view returns (uint8[] arr){
        for ((uint8 k,) : vrsparamsAbi) {
        	arr.push(k);
        }
    }
	
	// get TVC by by specific version
	function getTvcByVersion(uint8 tvcVersion) public view returns(optional(VersionsTvcParams)){
        optional(VersionsTvcParams) value = vrsparamsTvc.fetch(tvcVersion);
		return value;
    }

	// get ABI by specific version
    function getAbiByVersion(uint8 AbiVersion) public view returns(optional(VersionsAbiParams)){
        optional(VersionsAbiParams) value = vrsparamsAbi.fetch(AbiVersion);
		return value;
    }

    function setTvc(
		TvmCell tvcSubscriptionServiceInput, 
		TvmCell tvcSubscriptionInput, 
		TvmCell tvcSubscriptionServiceIndexInput,
		TvmCell tvcSubscriptionIndexInput
	)  
	public onlyOwner 
	{
		versionTvc++;
		VersionsTvcParams params;
		params.tvcSubscriptionService = tvcSubscriptionServiceInput;
		params.tvcSubscription = tvcSubscriptionInput;
		params.tvcSubscriptionServiceIndex = tvcSubscriptionServiceIndexInput;
		params.tvcSubscriptionIndex = tvcSubscriptionIndexInput;
		vrsparamsTvc.add(versionTvc, params);
    }

    function setAbi(
		string abiServiceContractInput, 
		string abiServiceIndexContractInput, 
		string abiSubscriptionContractInput, 
		string abiSubscriptionIndexContractInput, 
		string abiSubsManDebotInput
	) public onlyOwner 
	{
		versionAbi++;
		VersionsAbiParams params;
		params.abiServiceContract = abiServiceContractInput;
		params.abiServiceIndexContract = abiServiceIndexContractInput;
		params.abiSubscriptionContract = abiSubscriptionContractInput;
		params.abiSubscriptionIndexContract = abiSubscriptionIndexContractInput;
		params.abiSubsManDebot = abiSubsManDebotInput;
		vrsparamsAbi.add(versionAbi, params);
    }

	function setCategories(string[] categoriesInput) public onlyOwner {
		categories = categoriesInput;
	}
}