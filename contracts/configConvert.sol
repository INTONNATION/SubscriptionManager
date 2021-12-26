pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;

contract configVersions {
        
	TvmCell public tvcWallet;

	address public mRootAddr;
	address public RootAddr;
	address public mConvertWallet;
	address public ConvertWallet;

	string public mRootTokenContract;
	string public mTONTokenWallet;
	string public RootTokenContract;
	string public TONTokenWallet;

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
	function setmConvertWallet(address mConvertWalletINPUT) public onlyOwner {
		mConvertWallet = mConvertWalletINPUT;
	}

	function setConvertWallet(address ConvertWalletINPUT) public onlyOwner {
		ConvertWallet = ConvertWalletINPUT;
	}

	function setAbimRootTokenContract(string mRootTokenContractINPUT) public onlyOwner {
		mRootTokenContract = mRootTokenContractINPUT;
	}

	function setAbimTONTokenWallet(string mTONTokenWalletINPUT) public onlyOwner {
		mTONTokenWallet = mTONTokenWalletINPUT;
	}

	function setAbiRootTokenContract(string RootTokenContractINPUT) public onlyOwner {
		RootTokenContract = RootTokenContractINPUT;
	}

	function setAbiTONTokenWallet(string TONTokenWalletINPUT) public onlyOwner {
		TONTokenWallet = TONTokenWalletINPUT;
	}

}

