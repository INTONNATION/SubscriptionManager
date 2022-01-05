pragma ton-solidity ^ 0.51.0;
pragma AbiHeader expire;
pragma AbiHeader time;

import "../libraries/configsErrors.sol";


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

    modifier onlyOwner {
		require(msg.pubkey() == tvm.pubkey(), configsErrors.error_message_sender_is_not_my_owner);
		tvm.accept();
		_;
    }

	constructor() public {
		require(tvm.pubkey() != 0, configsErrors.error_pubkey_not_defined);
		tvm.accept();
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