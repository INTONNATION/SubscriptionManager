pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;

contract configVersions {
        
	TvmCell public tvcWallet;

	address public mRootAddr;
	address public RootAddr;
	address public mConvertWalletAddr;
	address public ConvertWalletAddr;

	string public mRootTokenContract;
	string public mTONTokenWalletContract;
	string public RootTokenContract;
	string public TONTokenWalletContract;

	constructor() public {
		require(tvm.pubkey() != 0, 101);
		tvm.accept();
	}

    modifier onlyOwner {
		require(msg.pubkey() == tvm.pubkey(), 100);
		tvm.accept();
		_;
    }

	function setTvcWallet(TvmCell tvcWalletINPUT) public onlyOwner {
		tvcWallet = tvcWalletINPUT;
	}

	function setmRootAddr(address mRootAddrINPUT) public onlyOwner {
		mRootAddr = mRootAddrINPUT;
	}

	function setRootAddr(address RootAddrINPUT) public onlyOwner {
		RootAddr = RootAddrINPUT;
	}
	function setmConvertWalletAddr(address mConvertWalletAddrINPUT) public onlyOwner {
		mConvertWalletAddr = mConvertWalletAddrINPUT;
	}

	function setConvertWalletAddr(address ConvertWalletAddrINPUT) public onlyOwner {
		ConvertWalletAddr = ConvertWalletAddrINPUT;
	}

	function setAbimRootTokenContract(string mRootTokenContractINPUT) public onlyOwner {
		mRootTokenContract = mRootTokenContractINPUT;
	}

	function setAbimTONTokenWalletContract(string mTONTokenWalletContractINPUT) public onlyOwner {
		mTONTokenWalletContract = mTONTokenWalletContractINPUT;
	}

	function setAbiRootTokenContract(string RootTokenContractINPUT) public onlyOwner {
		RootTokenContract = RootTokenContractINPUT;
	}

	function setAbiTONTokenWalletContract(string TONTokenWalletContractINPUT) public onlyOwner {
		TONTokenWalletContract = TONTokenWalletContractINPUT;
	}

}

