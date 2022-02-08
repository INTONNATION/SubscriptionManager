pragma ton-solidity >= 0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;

import "../libraries/configsErrors.sol";

contract configVersions {
  
    uint8 public versionTvc;
	uint8 public versionAbi;
	string[] public categories;

	TvmCell tvcMetaduesAccount;
	TvmCell tvcSubscriptionService;
	TvmCell tvcSubscription;
	TvmCell tvcSubscriptionServiceIndex;
	TvmCell tvcSubscriptionIndex;
	TvmCell tvcSubscriptionIdentificatorIndex;

	string abiMetaduesRootContract;
	string abiTIP3RootContract;
	string abiServiceContract;
	string abiServiceIndexContract;
	string abiSubscriptionContract;
	string abiSubscriptionIndexContract;
	string abiSubscriptionIdentificatorIndexContract;

	struct VersionsTvcParams {
		TvmCell tvcMetaduesAccount;
		TvmCell tvcSubscriptionService;
		TvmCell tvcSubscription;
		TvmCell tvcSubscriptionServiceIndex;
		TvmCell tvcSubscriptionIndex;
		TvmCell tvcSubscriptionIdentificatorIndex;
	}
	struct VersionsAbiParams {
		string abiMetaduesRootContract;
		string abiTIP3RootContract;
		string abiServiceContract;
		string abiServiceIndexContract;
		string abiSubscriptionContract;
		string abiSubscriptionIndexContract;
		string abiSubscriptionIdentificatorIndexContract;
	}

	mapping (uint8 => VersionsTvcParams) public vrsparamsTvc;
    mapping (uint8 => VersionsAbiParams) public vrsparamsAbi;

    modifier onlyOwner {
		require(msg.pubkey() == tvm.pubkey(), configsErrors.error_message_sender_is_not_my_owner);
		tvm.accept();
		_;
    }

	constructor() public {
		require(msg.pubkey() == tvm.pubkey(), configsErrors.error_message_sender_is_not_my_owner);
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

	// Set TVCs
    function setTvcMetaduesAccount(
		TvmCell tvcMetaduesAccountInput
	)  
	public onlyOwner 
	{
		tvcMetaduesAccount = tvcMetaduesAccountInput;
    }

	function setTvcSubscriptionService(
		TvmCell tvcSubscriptionServiceInput
	)  
	public onlyOwner 
	{
		tvcSubscriptionService = tvcSubscriptionServiceInput;
    }
	
	function setTvcSubscription(
		TvmCell tvcSubscriptionInput
	)  
	public onlyOwner 
	{
		tvcSubscription = tvcSubscriptionInput;
    }

	function setTvcSubscriptionServiceIndex(
		TvmCell tvcSubscriptionServiceIndexInput
	)  
	public onlyOwner 
	{
		tvcSubscriptionServiceIndex = tvcSubscriptionServiceIndexInput;
    }

	function setTvcSubscriptionIndex(
		TvmCell tvcSubscriptionIndexInput
	)  
	public onlyOwner 
	{
		tvcSubscriptionIndex = tvcSubscriptionIndexInput;
    }

	function setTvcSubscriptionIdentificatorIndex(
		TvmCell tvcSubscriptionIdentificatorIndexInput
	)  
	public onlyOwner 
	{
		tvcSubscriptionIdentificatorIndex = tvcSubscriptionIdentificatorIndexInput;
    }

    function setTvc() public onlyOwner {
		versionTvc++;
		VersionsTvcParams params;
		params.tvcMetaduesAccount = tvcMetaduesAccount;
		params.tvcSubscriptionService = tvcSubscriptionService;
		params.tvcSubscription = tvcSubscription;
		params.tvcSubscriptionServiceIndex = tvcSubscriptionServiceIndex;
		params.tvcSubscriptionIndex = tvcSubscriptionIndex;
		params.tvcSubscriptionIdentificatorIndex = tvcSubscriptionIdentificatorIndex;
		vrsparamsTvc.add(versionTvc, params);
    }

	// Set ABIs

	function setAbiMetaduesRootContract(
		string abiMetaduesRootContractInput
	) public onlyOwner 
	{
		abiMetaduesRootContract = abiMetaduesRootContractInput;
    }

	function setAbiTIP3RootContract(
		string abiTIP3RootContractInput
	) public onlyOwner 
	{
		abiTIP3RootContract = abiTIP3RootContractInput;
    }

	function setAbiServiceContract(
		string abiServiceContractInput
	) public onlyOwner 
	{
		abiServiceContract = abiServiceContractInput;
    }

	function setAbiServiceIndexContract(
		string abiServiceIndexContractInput
	) public onlyOwner 
	{
		abiServiceIndexContract = abiServiceIndexContractInput;
    }

	function setAbiSubscriptionContract(
		string abiSubscriptionContractInput
	) public onlyOwner 
	{
		abiSubscriptionContract = abiSubscriptionContractInput;
    }

	function setAbiSubscriptionIndexContract(
		string abiSubscriptionIndexContractInput
	) public onlyOwner 
	{
		abiSubscriptionIndexContract = abiSubscriptionIndexContractInput;
    }

	function setAbiSubscriptionIdentificatorIndexContract(
		string abiSubscriptionIdentificatorIndexContractInput
	) public onlyOwner 
	{
		abiSubscriptionIdentificatorIndexContract = abiSubscriptionIdentificatorIndexContractInput;
    }

    function setAbi() public onlyOwner {
		versionAbi++;
		VersionsAbiParams params;
		params.abiMetaduesRootContract = abiMetaduesRootContract;
		params.abiTIP3RootContract = abiTIP3RootContract;
		params.abiServiceContract = abiServiceContract;
		params.abiServiceIndexContract = abiServiceIndexContract;
		params.abiSubscriptionContract = abiSubscriptionContract;
		params.abiSubscriptionIndexContract = abiSubscriptionIndexContract;
		params.abiSubscriptionIdentificatorIndexContract = abiSubscriptionIdentificatorIndexContract;
		vrsparamsAbi.add(versionAbi, params);
    }

	function setCategories(string[] categoriesInput) public onlyOwner {
		categories = categoriesInput;
	}

}