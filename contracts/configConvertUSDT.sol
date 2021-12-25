pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;

contract configVersions {
        
	TvmCell public tvcWallet;

	address public mUSDTRootAddr;
	address public USDTRootAddr;
	address public mUSDTConvertWallet;
	address public USDTConvertWallet;

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

	function setmUSDTRootAddr(address mUSDTRootAddrINPUT) public onlyOwner {
		mUSDTRootAddr = mUSDTRootAddrINPUT;
	}

	function setUSDTRootAddr(address USDTRootAddrINPUT) public onlyOwner {
		USDTRootAddr = USDTRootAddrINPUT;
	}
	function setmUSDTConvertWallet(address mUSDTConvertWalletINPUT) public onlyOwner {
		mUSDTConvertWallet = mUSDTConvertWalletINPUT;
	}

	function setUSDTConvertWallet(address USDTConvertWalletINPUT) public onlyOwner {
		USDTConvertWallet = USDTConvertWalletINPUT;
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

