pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;

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
	}

	mapping (uint8 => VersionsAutobiller) public vrsAutobiller;

	constructor() public {
		require(tvm.pubkey() != 0, 101);
		tvm.accept();
	}

    
    modifier onlyOwner {
		require(msg.pubkey() == tvm.pubkey(), 100);
		tvm.accept();
		_;
    }
    function getAutobillerLatest() public view returns(optional (VersionsAutobiller)){
        optional(VersionsAutobiller) value = vrsAutobiller.fetch(versionAutobiller);
		return value;
    }

    function getAutobillerVersions() public view returns (uint8[] arr ){
        for ((uint8 k,) : vrsAutobiller) {
        arr.push(k);
        }
    }   

	
	// get configs by version
	function getAutobillerVersion(uint8 versionAutobiller) public view returns(optional (VersionsAutobiller)){
        optional(VersionsAutobiller) value = vrsAutobiller.fetch(versionAutobiller);
		return value;
    }

    function setAutobillerConfig(string pubkeyINPUT, string nameINPUT, string periodINPUT, string valueINPUT, string imageINPUT, string descriptionINPUT, string toINPUT, string categoryINPUT)  public onlyOwner {
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
		vrsAutobiller.add(versionAutobiller, params);
    }

}

