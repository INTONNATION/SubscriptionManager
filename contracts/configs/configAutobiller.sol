pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;

import "../libraries/configsErrors.sol";


contract configAutobiller {

    uint8 public versionAutobiller;
	struct VersionsAutobiller {
		string pubkey;
        string name;
        string period;
        string value;
        string image; 
        string description;
        string to;
        string category;
		string currency;
	}
	mapping (uint8 => VersionsAutobiller) public vrsAutobiller;

	constructor() public {
		require(msg.pubkey() == tvm.pubkey(), configsErrors.error_message_sender_is_not_my_owner);
		tvm.accept();
	}

    modifier onlyOwner {
		require(msg.pubkey() == tvm.pubkey(), configsErrors.error_message_sender_is_not_my_owner);
		tvm.accept();
		_;
    }

    function getAutobillerLatest() public view returns(optional(VersionsAutobiller)) {
        optional(VersionsAutobiller) value = vrsAutobiller.fetch(versionAutobiller);
		return value;
    }

    function getAutobillerVersions() public view returns (uint8[] arr) {
        for ((uint8 k,) : vrsAutobiller) {
        	arr.push(k);
        }
    }   

	// get configs by version
	function getAutobillerVersion(uint8 versionAutobiller) public view returns(optional(VersionsAutobiller)) {
        optional(VersionsAutobiller) value = vrsAutobiller.fetch(versionAutobiller);
		return value;
    }

    function setAutobillerConfig(
		string pubkeyINPUT, 
		string nameINPUT, 
		string periodINPUT, 
		string valueINPUT, 
		string imageINPUT, 
		string descriptionINPUT, 
		string toINPUT, 
		string categoryINPUT,
		string currencyINPUT
	) public onlyOwner 
	{
		versionAutobiller++;
		VersionsAutobiller params;
		params.pubkey = pubkeyINPUT;
		params.name = nameINPUT;
		params.period = periodINPUT;
		params.value = valueINPUT;
		params.image = imageINPUT;
		params.description = descriptionINPUT;
		params.to = toINPUT;
		params.category = categoryINPUT;
		params.currency = currencyINPUT;
		vrsAutobiller.add(versionAutobiller, params);
    }
}