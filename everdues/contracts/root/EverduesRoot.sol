pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "./EverduesRootBase.sol";

contract EverduesRoot is EverduesRootBase {
	constructor(address initial_owner) public {
		tvm.rawReserve(EverduesGas.ROOT_INITIAL_BALANCE, 2);
		tvm.accept();
		owner = initial_owner;
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function upgrade(TvmCell code) external onlyOwner {
		TvmCell upgrade_data = abi.encode(
			owner,
			versions,
			has_platform_code,
			fee_proxy_address,
			categories,
			service_fee,
			subscription_fee,
			dex_root_address,
			mtds_root_address,
			mtds_revenue_accumulator_address,
			codePlatform,
			abiPlatformContract,
			abiEverduesRootContract,
			abiTIP3RootContract,
			abiTIP3TokenWalletContract,
			wever_root,
			tip3_to_ever_address,
			wallets_mapping
		);
		tvm.setcode(code);
		tvm.setCurrentCode(code);
		onCodeUpgrade(upgrade_data);
	}

	function onCodeUpgrade(TvmCell upgrade_data) private {
		tvm.rawReserve(EverduesGas.ROOT_INITIAL_BALANCE, 2);
		tvm.resetStorage();
		(
			owner,
			versions,
			has_platform_code,
			fee_proxy_address,
			categories,
			service_fee,
			subscription_fee,
			dex_root_address,
			mtds_root_address,
			mtds_revenue_accumulator_address,
			codePlatform,
			abiPlatformContract,
			abiEverduesRootContract,
			abiTIP3RootContract,
			abiTIP3TokenWalletContract,
			wever_root,
			tip3_to_ever_address,
			wallets_mapping
		) = abi.decode(
			upgrade_data,
			(
				address,
				mapping(uint8 => mapping(uint32 => ContractParams)),
				bool,
				address,
				string[],
				uint8,
				uint8,
				address,
				address,
				address,
				TvmCell,
				string,
				string,
				string,
				string,
				address,
				address,
				mapping(address => ServiceDeployParams)
			)
		);
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}
}
