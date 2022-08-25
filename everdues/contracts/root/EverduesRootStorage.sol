pragma ton-solidity >=0.56.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../../libraries/MsgFlag.sol";
import "../Platform.sol";
import "../Index.sol";
import "../../libraries/ContractTypes.sol";

abstract contract EverduesRootStorage {
	address public fee_proxy_address;
	address public owner;
	address public mtds_root_address;
	address public mtds_revenue_accumulator_address;
	address public dex_root_address;
	address public wever_root;
	address public pending_owner;
	address public tip3_to_ever_address;
	uint8 public service_fee;
	uint8 public subscription_fee;
	uint8 service_gas_compenstation;
	uint8 subscription_gas_compenstation;

	string[] categories;
	bool has_platform_code;
	uint128 account_threshold = 10 ever; // default value
	uint128 recurring_payment_gas = 0.4 ever; // default value

	string abiPlatformContract;
	string abiEverduesRootContract;
	string abiTIP3RootContract;
	string abiTIP3TokenWalletContract;
	string abiEverduesAccountContract;
	string abiServiceContract;
	string abiIndexContract;
	string abiSubscriptionContract;
	string abiFeeProxyContract;

	TvmCell codePlatform;
	TvmCell codeEverduesAccount;
	TvmCell codeFeeProxy;
	TvmCell codeService;
	TvmCell codeIndex;
	TvmCell codeSubscription;
	struct ContractParams {
		TvmCell contractCode;
		string contractAbi;
	}

	struct ContractVersionParams {
		uint32 contractVersion;
		string contractAbi;
	}

	struct EverduesContractsInfo {
		mapping(uint8 => mapping(uint256 => ContractVersionParams)) versions;
		mapping(uint32 => ContractParams) account_versions;
		TvmCell platform_code;
		string tip3_root_abi;
		string tip3_wallet_abi;
		string everdues_root_abi;
		string platform_abi;
		// string everdues_root_abi;
		address account_address;
		string[] categories;
		string everdues_fee_proxy_abi;
		string index_abi;
		mapping (uint256=>string) subs_abis;
	}

	struct ServiceDeployParams {
		address wallet_address;
		uint128 required_amount;
	}
	mapping(uint8 => mapping(uint32 => ContractParams)) public versions;

	mapping(address => ServiceDeployParams) public wallets_mapping; // supported tip3 for locking -> rquired token's amount (service deploy)

	function getCodeHashes(uint256 owner_pubkey)
		external
		view
		returns (EverduesContractsInfo everdues_contracts_info)
	{
		mapping(uint8 => mapping(uint256 => ContractVersionParams)) external_data_structure;
		mapping(uint256 => ContractVersionParams) contracts;
		address account = address(
			tvm.hash(_buildAccountInitData(ContractTypes.Account, owner_pubkey))
		);
		for (
			(uint32 version, ContractParams contract_params):
			versions[ContractTypes.Service]
		) {
			for (uint256 i = 0; i < categories.length; i++) {
				uint256 hash_ = tvm.hash(
					_buildPublicServiceCodeByVersion(categories[i], version)
				);
				ContractVersionParams contract_info;
				contract_info.contractVersion = version;
				contract_info.contractAbi = contract_params.contractAbi;
				contracts.add(hash_, contract_info);
			}
		}
		external_data_structure.add(ContractTypes.Service, contracts);
		delete contracts;
		for (
			(uint32 version, ContractParams contract_params):
			versions[ContractTypes.Subscription]
		) {
			uint256 hash_ = tvm.hash(
				_buildSubscriptionCodeByVersion(account, version)
			);
			ContractVersionParams contract_info;
			contract_info.contractVersion = version;
			contract_info.contractAbi = contract_params.contractAbi;
			contracts.add(hash_, contract_info);
		}
		external_data_structure.add(ContractTypes.Subscription, contracts);
		delete contracts;
		for (
			(uint32 version, ContractParams contract_params):
			versions[ContractTypes.Account]
		) {
			uint256 hash_ = tvm.hash(contract_params.contractCode);
			ContractVersionParams contract_info;
			contract_info.contractVersion = version;
			contract_info.contractAbi = contract_params.contractAbi;
			contracts.add(hash_, contract_info);
		}
		external_data_structure.add(ContractTypes.Account, contracts);
		delete contracts;
		for (
			(uint32 version, ContractParams contract_params):
			versions[ContractTypes.Index]
		) {
			uint256 hash_ = tvm.hash(
				_buildServiceIndexCode(contract_params.contractCode, account)
			);
			ContractVersionParams contract_info;
			contract_info.contractVersion = version;
			contract_info.contractAbi = contract_params.contractAbi;
			contracts.add(hash_, contract_info);
		}
		external_data_structure.add(ContractTypes.ServiceIndex, contracts);
		delete contracts;
		/*for (
			(uint32 version, ContractParams contract_params):
			versions[ContractTypes.Index]
		) {
			uint256 hash_ = tvm.hash(_buildSubscriptionIndex(contract_params.contractCode);
			ContractVersionParams contract_info;
			contract_info.contractVersion = version;
			contract_info.contractAbi = contract_params.contractAbi;
			contracts.add(hash_, contract_info);
		}
		external_data_structure.add(ContractTypes.SubscriptionIndex, contracts);
		delete contracts;*/
		everdues_contracts_info.versions = external_data_structure;
		everdues_contracts_info.platform_code = codePlatform;
		everdues_contracts_info.platform_abi = abiPlatformContract;
		everdues_contracts_info.tip3_root_abi = abiTIP3RootContract;
		everdues_contracts_info.tip3_wallet_abi = abiTIP3TokenWalletContract;
		everdues_contracts_info.everdues_root_abi = abiEverduesRootContract;
		everdues_contracts_info.everdues_fee_proxy_abi = versions[
			ContractTypes.FeeProxy
		][1].contractAbi;
		everdues_contracts_info.account_address = account;
		everdues_contracts_info.account_versions = versions[
			ContractTypes.Account
		];
		for (uint256 i = 0; i < categories.length; i++) {
			everdues_contracts_info.categories.push(categories[i]);
		}
		everdues_contracts_info.index_abi = versions[ContractTypes.Index][1].contractAbi;
		mapping (uint256=>string) subs_abis_mapping;
		for (
			(, ContractParams contract_params):
			versions[ContractTypes.Subscription]
		) {
			subs_abis_mapping.add(tvm.hash(contract_params.contractAbi), contract_params.contractAbi);
		}
		everdues_contracts_info.subs_abis = subs_abis_mapping;
	}

	function getPendingOwner()
		external
		view
		responsible
		returns (address dex_pending_owner)
	{
		return
			{
				value: 0,
				bounce: false,
				flag: MsgFlag.REMAINING_GAS
			} pending_owner;
	}

	function _buildAccountInitData(uint8 type_id, uint256 pubkey)
		internal
		inline
		view
		returns (TvmCell)
	{
		TvmCell params;
		return
			tvm.buildStateInit({
				contr: Platform,
				varInit: {
					root: address(this),
					type_id: type_id,
					platform_params: params
				},
				pubkey: pubkey,
				code: codePlatform
			});
	}

	function _buildPublicServiceCodeByVersion(string category, uint32 version_)
		internal
		view
		returns (TvmCell)
	{
		TvmBuilder saltBuilder;
		saltBuilder.store(category, address(this));
		ContractParams latestVersion = versions[ContractTypes.Service][
			version_
		];
		TvmCell code = tvm.setCodeSalt(
			latestVersion.contractCode,
			saltBuilder.toCell()
		);
		return code;
	}

	function _buildSubscriptionCodeByVersion(
		address subscription_owner,
		uint32 contract_version
	) internal view returns (TvmCell) {
		TvmBuilder saltBuilder;
		saltBuilder.store(subscription_owner, address(this));
		ContractParams selectedVersion = versions[ContractTypes.Subscription][
			contract_version
		];
		TvmCell code = tvm.setCodeSalt(
			selectedVersion.contractCode,
			saltBuilder.toCell()
		);
		return code;
	}

	// Builders

	function _buildSubscriptionCode(address subscription_owner)
		internal
		view
		returns (TvmCell)
	{
		TvmBuilder saltBuilder;
		saltBuilder.store(subscription_owner, address(this));
		optional(uint32, ContractParams) latest_version_opt = versions[
			ContractTypes.Subscription
		].max();
		(, ContractParams latest_params) = latest_version_opt.get();
		TvmCell code = tvm.setCodeSalt(
			latest_params.contractCode,
			saltBuilder.toCell()
		);
		return code;
	}

	function _buildPublicServiceCode(string category)
		internal
		view
		returns (TvmCell)
	{
		TvmBuilder saltBuilder;
		saltBuilder.store(category, address(this));
		optional(uint32, ContractParams) latest_version_opt = versions[
			ContractTypes.Service
		].max();
		(, ContractParams latest_params) = latest_version_opt.get();
		TvmCell code = tvm.setCodeSalt(
			latest_params.contractCode,
			saltBuilder.toCell()
		);
		return code;
	}

	function _buildPrivateServiceCode(uint256 nonce)
		internal
		view
		returns (TvmCell)
	{
		TvmBuilder saltBuilder;
		saltBuilder.store(nonce, address(this));
		optional(uint32, ContractParams) latest_version_opt = versions[
			ContractTypes.Service
		].max();
		(, ContractParams latest_params) = latest_version_opt.get();
		TvmCell code = tvm.setCodeSalt(
			latest_params.contractCode,
			saltBuilder.toCell()
		);
		return code;
	}

	function _buildSubscriptionIdentificatorIndex(
		address service_address,
		TvmCell identificator,
		address subscription_owner
	) internal view returns (TvmCell) {
		TvmBuilder saltBuilder;
		TvmCell index_salt_data = abi.encode(service_address, identificator);
		saltBuilder.store(index_salt_data, address(this));
		ContractParams latestVersion = versions[ContractTypes.Index][1];
		TvmCell code = tvm.setCodeSalt(
			latestVersion.contractCode,
			saltBuilder.toCell()
		);
		TvmCell index_data_static = abi.encode(subscription_owner);
		TvmCell stateInit = tvm.buildStateInit({
			code: code,
			pubkey: 0,
			varInit: {index_static_data: index_data_static},
			contr: Index
		});
		return stateInit;
	}

	function _buildSubscriptionIndexCode(address service_address)
		internal
		view
		returns (TvmCell code)
	{
		TvmBuilder saltBuilder;
		saltBuilder.store(abi.encode(service_address), address(this));
		ContractParams latestVersion = versions[ContractTypes.Index][1];
		code = tvm.setCodeSalt(
			latestVersion.contractCode,
			saltBuilder.toCell()
		);
	}

	function _buildSubscriptionIndex(
		address service_address,
		address subscription_owner
	) internal view returns (TvmCell) {
		TvmCell code = _buildSubscriptionIndexCode(service_address);
		TvmCell index_data_static = abi.encode(subscription_owner);
		TvmCell stateInit = tvm.buildStateInit({
			code: code,
			pubkey: 0,
			varInit: {index_static_data: index_data_static},
			contr: Index
		});
		return stateInit;
	}

	function _buildServiceIndexCode(TvmCell contractCode, address serviceOwner)
		internal
		pure
		returns (TvmCell)
	{
		TvmBuilder saltBuilder;
		saltBuilder.store(abi.encode(serviceOwner), address(this));
		TvmCell code = tvm.setCodeSalt(contractCode, saltBuilder.toCell());
		return code;
	}

	function _buildServiceIndex(address serviceOwner, string serviceName)
		internal
		view
		returns (TvmCell)
	{
		TvmBuilder saltBuilder;
		saltBuilder.store(abi.encode(serviceOwner), address(this));
		ContractParams latestVersion = versions[ContractTypes.Index][1];
		TvmCell code = tvm.setCodeSalt(
			latestVersion.contractCode,
			saltBuilder.toCell()
		);
		TvmCell index_data_static = abi.encode(serviceOwner, serviceName);
		TvmCell state = tvm.buildStateInit({
			code: code,
			pubkey: 0,
			varInit: {index_static_data: index_data_static},
			contr: Index
		});
		return state;
	}

	function _buildServiceIdentificatorIndex(
		address serviceOwner,
		TvmCell identificator,
		address serviceAddress
	) internal view returns (TvmCell) {
		TvmBuilder saltBuilder;
		saltBuilder.store(identificator, address(this));
		ContractParams latestVersion = versions[ContractTypes.Index][1];
		TvmCell code = tvm.setCodeSalt(
			latestVersion.contractCode,
			saltBuilder.toCell()
		);
		TvmCell index_data_static = abi.encode(serviceOwner, serviceAddress);
		TvmCell state = tvm.buildStateInit({
			code: code,
			pubkey: 0,
			varInit: {index_static_data: index_data_static},
			contr: Index
		});
		return state;
	}

	function _buildInitData(uint8 type_id, TvmCell params)
		internal
		inline
		view
		returns (TvmCell)
	{
		return
			tvm.buildStateInit({
				contr: Platform,
				varInit: {
					root: address(this),
					type_id: type_id,
					platform_params: params
				},
				pubkey: 0,
				code: codePlatform
			});
	}

	function _buildPlatformParamsOwnerAddress(address account_owner)
		internal
		inline
		pure
		returns (TvmCell)
	{
		TvmBuilder builder;
		builder.store(account_owner);
		return builder.toCell();
	}

	function _buildSubscriptionPlatformParams(
		address subscription_owner,
		address service_address
	) internal inline pure returns (TvmCell) {
		TvmBuilder builder;
		builder.store(subscription_owner);
		builder.store(service_address);
		return builder.toCell();
	}

	function _buildServicePlatformParams(
		address service_owner,
		string service_name
	) internal inline pure returns (TvmCell) {
		TvmBuilder builder;
		builder.store(service_owner);
		builder.store(service_name);
		return builder.toCell();
	}

	// Getters

	function getGasCompenstationProportion()
		external
		view
		responsible
		returns (uint8, uint8)
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		return { value: 0, bounce: false, flag: MsgFlag.ALL_NOT_RESERVED } (service_gas_compenstation, subscription_gas_compenstation);
	}

	// Addresses calculations

	function accountOf(uint256 owner_pubkey)
		external
		view
		returns (address account)
	{
		account = address(
			tvm.hash(_buildAccountInitData(ContractTypes.Account, owner_pubkey))
		);
	}

	function serviceOf(address owner_address_, string service_name_)
		external
		view
		returns (address service)
	{
		service = address(
			tvm.hash(
				_buildInitData(
					ContractTypes.Service,
					_buildServicePlatformParams(owner_address_, service_name_)
				)
			)
		);
	}

	function subscriptionOf(address owner_address_, address service_address_)
		external
		view
		returns (address subscription)
	{
		subscription = address(
			tvm.hash(
				_buildInitData(
					ContractTypes.Subscription,
					_buildSubscriptionPlatformParams(
						owner_address_,
						service_address_
					)
				)
			)
		);
	}

	function subscribersOf(address service_address)
		external
		view
		returns (uint256 subscribers_code_hash)
	{
		subscribers_code_hash = tvm.hash(
			_buildSubscriptionIndexCode(service_address)
		);
	}

	function getSubscriberIndexById(
		address service_address,
		TvmCell identificator
	) external view returns (uint256) {
		TvmBuilder saltBuilder;
		TvmCell index_salt_data = abi.encode(service_address, identificator); 
		saltBuilder.store(index_salt_data, address(this));
		ContractParams latestVersion = versions[ContractTypes.Index][1];
		TvmCell code = tvm.setCodeSalt(
			latestVersion.contractCode,
			saltBuilder.toCell()
		);
		return tvm.hash(code);
	}
}
