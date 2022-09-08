pragma ton-solidity >=0.56.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./EverduesRootStorage.sol";
import "../../libraries/EverduesErrors.sol";
import "../../interfaces/IEverduesFeeProxy.sol";

import "../../../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenRoot.sol";

abstract contract EverduesRootSettings is EverduesRootStorage {
	modifier onlyOwner() {
		require(
			msg.sender == owner,
			EverduesErrors.error_message_sender_is_not_owner
		);
		tvm.accept();
		_;
	}

	modifier onlyAccountContract(uint256 pubkey) {
		address account_contract_address = address(
			tvm.hash(_buildAccountInitData(ContractTypes.Account, pubkey))
		);
		require(
			msg.sender == account_contract_address,
			EverduesErrors.error_message_sender_is_not_account_address
		);
		_;
	}

	function setCodePlatform(TvmCell codePlatformInput) external onlyOwner {
		require(
			codePlatform.toSlice().empty(),
			EverduesErrors.error_platform_code_is_not_empty
		);
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		codePlatform = codePlatformInput;
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}

	function setCodeEverduesAccount(TvmCell codeEverduesAccountInput)
		external
		onlyOwner
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		if (
			!checkVersionCodeAlreadyExists(
				ContractTypes.Account,
				codeEverduesAccountInput
			)
		) {
			if (!abiEverduesAccountContract.empty()) {
				optional(uint32, ContractParams) latest_version_opt = versions[
					ContractTypes.Account
				].max();
				uint32 latest_version;
				if (latest_version_opt.hasValue()) {
					(latest_version, ) = latest_version_opt.get();
					latest_version++;
				} else {
					latest_version = 1;
				}
				addNewContractVersion_(
					ContractTypes.Account,
					latest_version,
					codeEverduesAccountInput,
					abiEverduesAccountContract
				);
				delete codeEverduesAccount;
				delete abiEverduesAccountContract;
			} else {
				codeEverduesAccount = codeEverduesAccountInput;
			}
		}
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function setCodeService(TvmCell codeServiceInput) external onlyOwner {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		if (
			!checkVersionCodeAlreadyExists(
				ContractTypes.Service,
				codeServiceInput
			)
		) {
			if (!abiServiceContract.empty()) {
				optional(uint32, ContractParams) latest_version_opt = versions[
					ContractTypes.Service
				].max();
				uint32 latest_version;
				if (latest_version_opt.hasValue()) {
					(latest_version, ) = latest_version_opt.get();
					latest_version++;
				} else {
					latest_version = 1;
				}
				addNewContractVersion_(
					ContractTypes.Service,
					latest_version,
					codeServiceInput,
					abiServiceContract
				);
				delete codeService;
				delete abiServiceContract;
			} else {
				codeService = codeServiceInput;
			}
		}
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function setCodeSubscription(TvmCell codeSubscriptionInput)
		external
		onlyOwner
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		if (
			!checkVersionCodeAlreadyExists(
				ContractTypes.Subscription,
				codeSubscriptionInput
			)
		) {
			if (!abiSubscriptionContract.empty()) {
				optional(uint32, ContractParams) latest_version_opt = versions[
					ContractTypes.Subscription
				].max();
				uint32 latest_version;
				if (latest_version_opt.hasValue()) {
					(latest_version, ) = latest_version_opt.get();
					latest_version++;
				} else {
					latest_version = 1;
				}
				addNewContractVersion_(
					ContractTypes.Subscription,
					latest_version,
					codeSubscriptionInput,
					abiSubscriptionContract
				);
				delete codeSubscription;
				delete abiSubscriptionContract;
			} else {
				codeSubscription = codeSubscriptionInput;
			}
		}
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function setCodeIndex(TvmCell codeIndexInput) external onlyOwner {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		if (
			!checkVersionCodeAlreadyExists(ContractTypes.Index, codeIndexInput)
		) {
			if (!abiIndexContract.empty()) {
				optional(uint32, ContractParams) latest_version_opt = versions[
					ContractTypes.Index
				].max();
				uint32 latest_version;
				if (latest_version_opt.hasValue()) {
					(latest_version, ) = latest_version_opt.get();
				} else {
					latest_version = 1;
				}
				addNewContractVersion_(
					ContractTypes.Index,
					latest_version,
					codeIndexInput,
					abiIndexContract
				);
				delete codeIndex;
				delete abiIndexContract;
			} else {
				codeIndex = codeIndexInput;
			}
		}
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function setCodeFeeProxy(TvmCell codeFeeProxyInput) external onlyOwner {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		if (
			!checkVersionCodeAlreadyExists(
				ContractTypes.FeeProxy,
				codeFeeProxyInput
			)
		) {
			if (!abiFeeProxyContract.empty()) {
				addNewContractVersion_(
					ContractTypes.FeeProxy,
					1,
					codeFeeProxyInput,
					abiFeeProxyContract
				);
				delete codeFeeProxyInput;
				delete abiFeeProxyContract;
			} else {
				codeFeeProxy = codeFeeProxyInput;
			}
		}
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	// Set ABIs
	function setAbiPlatformContract(string abiPlatformContractInput)
		external
		onlyOwner
	{
		require(
			abiPlatformContract.empty(),
			EverduesErrors.error_platform_code_is_not_empty
		);
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		abiPlatformContract = abiPlatformContractInput;
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function setAbiEverduesAccountContract(
		string abiEverduesAccountContractInput
	) external onlyOwner {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		if (
			!checkVersionAbiAlreadyExists(
				ContractTypes.Account,
				abiEverduesAccountContractInput
			) ||
			!checkVersionCodeAlreadyExists(
				ContractTypes.Account,
				codeEverduesAccount
			)
		) {
			if (!codeEverduesAccount.toSlice().empty()) {
				optional(uint32, ContractParams) latest_version_opt = versions[
					ContractTypes.Account
				].max();
				uint32 latest_version;
				if (latest_version_opt.hasValue()) {
					(latest_version, ) = latest_version_opt.get();
					latest_version++;
				} else {
					latest_version = 1;
				}
				addNewContractVersion_(
					ContractTypes.Account,
					latest_version,
					codeEverduesAccount,
					abiEverduesAccountContractInput
				);
				delete codeEverduesAccount;
				delete abiEverduesAccountContract;
			} else {
				abiEverduesAccountContract = abiEverduesAccountContractInput;
			}
		}
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function setAbiEverduesRootContract(string abiEverduesRootContractInput)
		external
		onlyOwner
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		abiEverduesRootContract = abiEverduesRootContractInput;
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function setAbiTIP3RootContract(string abiTIP3RootContractInput)
		external
		onlyOwner
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		abiTIP3RootContract = abiTIP3RootContractInput;
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function setAbiTIP3TokenWalletContract(
		string abiTIP3TokenWalletContractInput
	) external onlyOwner {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		abiTIP3TokenWalletContract = abiTIP3TokenWalletContractInput;
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function setAbiServiceContract(string abiServiceContractInput)
		external
		onlyOwner
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		if (
			!checkVersionAbiAlreadyExists(
				ContractTypes.Service,
				abiServiceContractInput
			) ||
			!checkVersionCodeAlreadyExists(ContractTypes.Service, codeService)
		) {
			if (!codeService.toSlice().empty()) {
				optional(uint32, ContractParams) latest_version_opt = versions[
					ContractTypes.Service
				].max();
				uint32 latest_version;
				if (latest_version_opt.hasValue()) {
					(latest_version, ) = latest_version_opt.get();
					latest_version++;
				} else {
					latest_version = 1;
				}
				addNewContractVersion_(
					ContractTypes.Service,
					latest_version,
					codeService,
					abiServiceContractInput
				);
				delete codeService;
				delete abiServiceContract;
			} else {
				abiServiceContract = abiServiceContractInput;
			}
		}
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function setAbiSubscriptionContract(string abiSubscriptionContractInput)
		external
		onlyOwner
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		if (
			!checkVersionAbiAlreadyExists(
				ContractTypes.Subscription,
				abiSubscriptionContractInput
			) ||
			!checkVersionCodeAlreadyExists(
				ContractTypes.Subscription,
				codeSubscription
			)
		) {
			if (!codeSubscription.toSlice().empty()) {
				uint32 latest_version;
				optional(uint32, ContractParams) latest_version_opt = versions[
					ContractTypes.Subscription
				].max();
				if (latest_version_opt.hasValue()) {
					(latest_version, ) = latest_version_opt.get();
					latest_version++;
				} else {
					latest_version = 1;
				}
				addNewContractVersion_(
					ContractTypes.Subscription,
					latest_version,
					codeSubscription,
					abiSubscriptionContractInput
				);
				delete codeSubscription;
				delete abiSubscriptionContract;
			} else {
				abiSubscriptionContract = abiSubscriptionContractInput;
			}
		}
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function setAbiIndexContract(string abiIndexContractInput)
		external
		onlyOwner
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		if (
			!checkVersionAbiAlreadyExists(
				ContractTypes.Index,
				abiIndexContractInput
			) || !checkVersionCodeAlreadyExists(ContractTypes.Index, codeIndex)
		) {
			if (!codeIndex.toSlice().empty()) {
				optional(uint32, ContractParams) latest_version_opt = versions[
					ContractTypes.SubscriptionIndex
				].max();
				uint32 latest_version;
				if (latest_version_opt.hasValue()) {
					(latest_version, ) = latest_version_opt.get();
					latest_version++;
				} else {
					latest_version = 1;
				}
				addNewContractVersion_(
					ContractTypes.Index,
					latest_version,
					codeIndex,
					abiIndexContractInput
				);
				delete codeIndex;
				delete abiIndexContract;
			} else {
				abiIndexContract = abiIndexContractInput;
			}
		}
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function setAbiFeeProxyContract(string abiFeeProxyContractInput)
		external
		onlyOwner
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		if (
			!checkVersionAbiAlreadyExists(
				ContractTypes.FeeProxy,
				abiFeeProxyContractInput
			) ||
			!checkVersionCodeAlreadyExists(ContractTypes.FeeProxy, codeFeeProxy)
		) {
			if (!codeFeeProxy.toSlice().empty()) {
				addNewContractVersion_(
					ContractTypes.FeeProxy,
					1,
					codeFeeProxy,
					abiFeeProxyContractInput
				);
				delete codeFeeProxy;
				delete abiFeeProxyContract;
			} else {
				abiFeeProxyContract = abiFeeProxyContractInput;
			}
		}
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function deleteVersion(uint8 contract_type, uint8 version_)
		external
		onlyOwner
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		if (version_ != 1) {
			mapping(uint32 => ContractParams) versions_ = versions[
				contract_type
			];
			delete versions_[version_];
			versions[contract_type] = versions_;
		}
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function setCategories(string[] categoriesInput) external onlyOwner {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		categories = categoriesInput;
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function setDeployServiceParams(address currency_root, uint128 lock_amount)
		external
		onlyOwner
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		optional(
			ServiceDeployParams
		) service_deploy_params_opt = wallets_mapping.fetch(currency_root);
		if (!service_deploy_params_opt.hasValue()) {
			ServiceDeployParams service_deploy_params;
			service_deploy_params.required_amount = lock_amount;
			wallets_mapping[currency_root] = service_deploy_params;
			ITokenRoot(currency_root).deployWallet{
				value: EverduesGas.DEPLOY_EMPTY_WALLET_VALUE,
				bounce: false,
				flag: MsgFlag.SENDER_PAYS_FEES,
				callback: EverduesRootSettings.onDeployWallet
			}(address(this), EverduesGas.DEPLOY_EMPTY_WALLET_GRAMS);
		} else {
			ServiceDeployParams service_deploy_params = service_deploy_params_opt
					.get();
			service_deploy_params.required_amount = lock_amount;
			wallets_mapping[currency_root] = service_deploy_params;
		}
		msg.sender.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function onDeployWallet(address wallet_address) external {
		require(
			wallets_mapping.exists(msg.sender),
			EverduesErrors.error_message_sender_is_not_currency_root
		);
		ServiceDeployParams service_deploy_params = wallets_mapping[msg.sender];
		service_deploy_params.wallet_address = wallet_address;
		wallets_mapping[msg.sender] = service_deploy_params;
	}

	function setAccountGasThreshold(uint128 account_threshold_)
		external
		onlyOwner
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		account_threshold = account_threshold_;
		IEverduesFeeProxy(fee_proxy_address).setAccountGasThreshold{
			value: 0,
			bounce: true,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(account_threshold, owner);
	}

	function setRecurringPaymentGas(uint128 recurring_payment_gas_)
		external
		onlyOwner
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		recurring_payment_gas = recurring_payment_gas_;
		IEverduesFeeProxy(fee_proxy_address).setRecurringPaymentGas{
			value: 0,
			bounce: true,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(recurring_payment_gas);
	}

	function setFees(uint8 service_fee_, uint8 subscription_fee_)
		external
		onlyOwner
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		service_fee = service_fee_;
		subscription_fee = subscription_fee_;
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function setGasCompenstationProportion(uint8 service_gas_compenstation_, uint8 subscription_gas_compenstation_)
		external
		onlyOwner
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		service_gas_compenstation = service_gas_compenstation_;
		subscription_fee = subscription_gas_compenstation_;
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function installOrUpgradeMTDSRevenueDelegationAddress(address revenue_to)
		external
		onlyOwner
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		mtds_revenue_accumulator_address = revenue_to;
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function installOrUpgradeWEVERRoot(address wever_root_) external onlyOwner {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		wever_root = wever_root_;
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function installOrUpdateFeeProxyParams(address[] currencies)
		external
		view
		onlyOwner
	{
		require(
			fee_proxy_address != address(0),
			EverduesErrors.error_address_is_empty
		);
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		TvmBuilder currencies_cell;
		currencies_cell.store(currencies);
		TvmCell fee_proxy_contract_params = currencies_cell.toCell();
		IEverduesFeeProxy(fee_proxy_address).setSupportedCurrencies{
			value: 0,
			bounce: true,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(fee_proxy_contract_params, owner);
	}

	function installOrUpgradeMTDSRootAddress(address mtds_root_)
		external
		onlyOwner
	{
		require(
			fee_proxy_address != address(0),
			EverduesErrors.error_address_is_empty
		);
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		mtds_root_address = mtds_root_;
		IEverduesFeeProxy(fee_proxy_address).setMTDSRootAddress{
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(mtds_root_address, owner);
	}

	function installOrUpgradeDexRootAddresses(
		address dex_root,
		address tip3_to_ever
	) external onlyOwner {
		require(
			fee_proxy_address != address(0),
			EverduesErrors.error_address_is_empty
		);
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		dex_root_address = dex_root;
		tip3_to_ever_address = tip3_to_ever;
		IEverduesFeeProxy(fee_proxy_address).setDexRootAddress{
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(dex_root_address, owner);
	}

	function checkVersionCodeAlreadyExists(
		uint8 contractType,
		TvmCell contractCode
	) private view returns (bool exist) {
		for ((, ContractParams contract_params): versions[contractType]) {
			if (
				tvm.hash(contract_params.contractCode) == tvm.hash(contractCode)
			) {
				return true;
			}
		}
		return false;
	}

	function checkVersionAbiAlreadyExists(
		uint8 contractType,
		string contractAbi
	) private view returns (bool exist) {
		for ((, ContractParams contract_params): versions[contractType]) {
			if (
				tvm.hash(contract_params.contractAbi) == tvm.hash(contractAbi)
			) {
				return true;
			}
		}
		return false;
	}

	function addNewContractVersion_(
		uint8 contract_type,
		uint32 version,
		TvmCell contract_code,
		string contract_abi
	) private {
		optional(
			mapping(uint32 => ContractParams)
		) contract_versions_opt = versions.fetch(contract_type);
		if (contract_versions_opt.hasValue()) {
			mapping(uint32 => ContractParams) contract_versions = contract_versions_opt
					.get();
			ContractParams new_version_params;
			new_version_params.contractCode = contract_code;
			new_version_params.contractAbi = contract_abi;
			contract_versions[version] = new_version_params;
			versions.replace(contract_type, contract_versions);
		} else {
			mapping(uint32 => ContractParams) contract_versions;
			ContractParams new_version_params;
			new_version_params.contractCode = contract_code;
			new_version_params.contractAbi = contract_abi;
			contract_versions[version] = new_version_params;
			versions.add(contract_type, contract_versions);
		}
	}
}
