pragma ton-solidity >=0.56.0;

pragma AbiHeader expire;
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
			fee_proxy_address,
			categories,
			service_fee,
			subscription_fee,
			dex_root_address,
			dues_root_address,
			dues_revenue_accumulator_address,
			codePlatform,
			abiPlatformContract,
			abiEverduesRootContract,
			abiTIP3RootContract,
			abiTIP3TokenWalletContract,
			abiEVMRecurringContract,
			wever_root,
			tip3_to_ever_address,
			service_gas_compenstation,
			subscription_gas_compenstation,
			wallets_mapping,
			cross_chain_token,
			cross_chain_subscriptions,
			cross_chain_proxies,
			supported_external_tokens,
			service_registration_token,
			watcher
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
			fee_proxy_address,
			categories,
			service_fee,
			subscription_fee,
			dex_root_address,
			dues_root_address,
			dues_revenue_accumulator_address,
			codePlatform,
			abiPlatformContract,
			abiEverduesRootContract,
			abiTIP3RootContract,
			abiTIP3TokenWalletContract,
			abiEVMRecurringContract,
			wever_root,
			tip3_to_ever_address,
			service_gas_compenstation,
			subscription_gas_compenstation,
			wallets_mapping,
			cross_chain_token,
			cross_chain_subscriptions,
			cross_chain_proxies,
			supported_external_tokens,
			service_registration_token,
			watcher
		) = abi.decode(
			upgrade_data,
			(
				address,
				mapping(uint8 => mapping(uint32 => ContractParams)),
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
				string,
				address,
				address,
				uint8,
				uint8,
				mapping(address => ServiceDeployParams),
				address,
				mapping(uint32 => mapping(uint256 => ExternalSubscription)),
				mapping(uint32 => string),
				mapping (uint32=>string[]),
				address,
				address
			)
		);
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}
}
