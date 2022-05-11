pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/EverduesErrors.sol";
import "libraries/PlatformTypes.sol";
import "libraries/MsgFlag.sol";
import "libraries/EverduesGas.sol";
import "./Platform.sol";
import "../contracts/SubscriptionIndex.sol";
import "../contracts/SubscriptionIdentificatorIndex.sol";
import "../contracts/SubscriptionServiceIndex.sol";
import "../contracts/EverduesFeeProxy.sol";
import "../contracts/EverduesAccount.sol";
import "../contracts/Subscription.sol";
import "../contracts/SubscriptionService.sol";
import "../contracts/SubscriptionServiceIdentificatorIndex.sol";

interface IPlatform {
	function initializeByRoot(
		TvmCell code,
		TvmCell contract_params,
		uint32 version
	) external;
}

interface ISubscription {
	function cancel() external;
}

contract EverduesRoot {
	uint8 public version;
	string[] public categories;

	TvmCell tvcPlatform;
	TvmCell tvcEverduesAccount;
	TvmCell tvcSubscriptionService;
	TvmCell tvcSubscription;
	TvmCell tvcSubscriptionServiceIndex;
	TvmCell tvcSubscriptionServiceIdentificatorIndex;
	TvmCell tvcSubscriptionIndex;
	TvmCell tvcSubscriptionIdentificatorIndex;
	TvmCell tvcFeeProxy;

	string abiPlatformContract;
	string abiEverduesAccountContract;
	string abiEverduesRootContract;
	string abiTIP3RootContract;
	string abiTIP3TokenWalletContract;
	string abiServiceContract;
	string abiServiceIndexContract;
	string abiSubscriptionContract;
	string abiSubscriptionIndexContract;
	string abiSubscriptionIdentificatorIndexContract;
	string abiFeeProxyContract;
	string abiServiceIdentificatorIndexContract;

	struct VersionsTvcParams {
		TvmCell tvcPlatform;
		TvmCell tvcEverduesAccount;
		TvmCell tvcSubscriptionService;
		TvmCell tvcSubscriptionServiceIndex;
		TvmCell tvcSubscriptionServiceIdentificatorIndex;
		TvmCell tvcSubscription;
		TvmCell tvcSubscriptionIndex;
		TvmCell tvcSubscriptionIdentificatorIndex;
		TvmCell tvcFeeProxy;
	}
	struct VersionsAbiParams {
		string abiPlatformContract;
		string abiEverduesAccountContract;
		string abiEverduesRootContract;
		string abiTIP3RootContract;
		string abiTIP3TokenWalletContract;
		string abiServiceContract;
		string abiServiceIndexContract;
		string abiServiceIdentificatorIndexContract;
		string abiSubscriptionContract;
		string abiSubscriptionIndexContract;
		string abiSubscriptionIdentificatorIndexContract;
		string abiFeeProxyContract;
	}

	mapping(uint8 => VersionsTvcParams) public vrsparamsTvc;
	mapping(uint8 => VersionsAbiParams) public vrsparamsAbi;

	bool has_platform_code;
	uint32 service_version;
	uint32 account_version;
	uint32 subscription_version;
	uint32 fee_proxy_version;
	address public fee_proxy_address;
	uint8 public service_fee;
	uint8 public subscription_fee;
	address public mtds_root_address;
	address public mtds_revenue_accumulator_address;
	address public dex_root_address;
	address public owner;
	address pending_owner;

	onBounce(TvmSlice slice) external view {
		// revert change to initial msg.sender in case of failure during deploy
		// TODO: after https://github.com/tonlabs/ton-labs-node/issues/140
		//uint32 functionId = slice.decode(uint32);
	}

	constructor(address initial_owner) public {
		tvm.rawReserve(EverduesGas.ROOT_INITIAL_BALANCE, 2);
		tvm.accept();
		owner = initial_owner;
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	modifier onlyOwner() {
		require(
			msg.sender == owner,
			EverduesErrors.error_message_sender_is_not_my_owner
		);
		tvm.accept();
		_;
	}

	function transferOwner(address new_owner) external onlyOwner {
		require(
			owner != new_owner,
			EverduesErrors.error_message_sender_is_equal_owner
		);
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		pending_owner = new_owner;
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	function acceptOwner() external {
		require(msg.sender.value != 0, EverduesErrors.error_address_is_empty);
		require(
			msg.sender == pending_owner,
			EverduesErrors.error_message_sender_is_not_pending_owner
		);
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		owner = pending_owner;
		pending_owner = address.makeAddrStd(0, 0);
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	// Getters
	function getPendingOwner()
		external
		view
		responsible
		returns (address dex_pending_owner)
	{
		return pending_owner;
	}

	function getTvcsLatest() public view returns (optional(VersionsTvcParams)) {
		optional(VersionsTvcParams) value = vrsparamsTvc.fetch(version);
		return value;
	}

	// Get all latest TVCs
	function getTvcsLatestResponsible()
		external
		view
		responsible
		returns (VersionsTvcParams)
	{
		VersionsTvcParams value = vrsparamsTvc[version];
		return (value);
	}

	// Get all latest ABIs
	function getAbisLatest() public view returns (optional(VersionsAbiParams)) {
		optional(VersionsAbiParams) value = vrsparamsAbi.fetch(version);
		return value;
	}

	function getOwner() external pure responsible returns (address owner_) {
		return owner_;
	}

	// Settings
	function setTvcPlatform(TvmCell tvcPlatformInput) external onlyOwner {
		require(
			!has_platform_code,
			EverduesErrors.error_platform_code_is_not_empty
		);
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		tvcPlatform = tvcPlatformInput;
		has_platform_code = true;
		owner.transfer({
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}

	function setTvcEverduesAccount(TvmCell tvcEverduesAccountInput)
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
		tvcEverduesAccount = tvcEverduesAccountInput;
		account_version++;
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	function setTvcSubscriptionService(TvmCell tvcSubscriptionServiceInput)
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
		tvcSubscriptionService = tvcSubscriptionServiceInput;
		service_version++;
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	function setTvcSubscription(TvmCell tvcSubscriptionInput)
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
		tvcSubscription = tvcSubscriptionInput;
		subscription_version++;
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	function setTvcSubscriptionServiceIndex(
		TvmCell tvcSubscriptionServiceIndexInput
	) external onlyOwner {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		tvcSubscriptionServiceIndex = tvcSubscriptionServiceIndexInput;
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	function setTvcSubscriptionServiceIdentificatorIndex(
		TvmCell tvcSubscriptionServiceIdentificatorIndexInput
	) external onlyOwner {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		tvcSubscriptionServiceIdentificatorIndex = tvcSubscriptionServiceIdentificatorIndexInput;
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	function setTvcSubscriptionIndex(TvmCell tvcSubscriptionIndexInput)
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
		tvcSubscriptionIndex = tvcSubscriptionIndexInput;
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	function setTvcSubscriptionIdentificatorIndex(
		TvmCell tvcSubscriptionIdentificatorIndexInput
	) external onlyOwner {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		tvcSubscriptionIdentificatorIndex = tvcSubscriptionIdentificatorIndexInput;
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	function setTvcFeeProxy(TvmCell tvcFeeProxyInput) external onlyOwner {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		tvcFeeProxy = tvcFeeProxyInput;
		fee_proxy_version++;
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	// Set ABIs
	function setAbiPlatformContract(string abiPlatformContractInput)
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
		abiPlatformContract = abiPlatformContractInput;
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
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
		abiEverduesAccountContract = abiEverduesAccountContractInput;
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
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
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
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
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
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
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
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
		abiServiceContract = abiServiceContractInput;
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	function setAbiServiceIndexContract(string abiServiceIndexContractInput)
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
		abiServiceIndexContract = abiServiceIndexContractInput;
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	function setAbiServiceIdentificatorIndexContract(
		string abiServiceIdentificatorIndexContractInput
	) external onlyOwner {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		abiServiceIdentificatorIndexContract = abiServiceIdentificatorIndexContractInput;
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
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
		abiSubscriptionContract = abiSubscriptionContractInput;
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	function setAbiSubscriptionIndexContract(
		string abiSubscriptionIndexContractInput
	) external onlyOwner {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		abiSubscriptionIndexContract = abiSubscriptionIndexContractInput;
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	function setAbiSubscriptionIdentificatorIndexContract(
		string abiSubscriptionIdentificatorIndexContractInput
	) external onlyOwner {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		abiSubscriptionIdentificatorIndexContract = abiSubscriptionIdentificatorIndexContractInput;
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
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
		abiFeeProxyContract = abiFeeProxyContractInput;
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	function deleteVersion(uint8 version_) external onlyOwner {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		if (version_ != 1) {
			delete vrsparamsTvc[version_];
			delete vrsparamsAbi[version_];
		}
	}

	function setVersion() external onlyOwner {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		VersionsTvcParams tvc_params;
		VersionsAbiParams abi_params;
		version++;
		if (version > 254) {
			version = 2;
		}
		if (version == 1) {
			tvc_params.tvcPlatform = tvcPlatform;
		} else {
			tvc_params.tvcPlatform = vrsparamsTvc[1].tvcPlatform;
		}
		tvc_params.tvcEverduesAccount = tvcEverduesAccount;
		tvc_params.tvcSubscriptionService = tvcSubscriptionService;
		tvc_params.tvcSubscription = tvcSubscription;
		tvc_params.tvcSubscriptionServiceIndex = tvcSubscriptionServiceIndex;
		tvc_params.tvcSubscriptionIndex = tvcSubscriptionIndex;
		tvc_params
			.tvcSubscriptionIdentificatorIndex = tvcSubscriptionIdentificatorIndex;
		tvc_params.tvcFeeProxy = tvcFeeProxy;
		tvc_params
			.tvcSubscriptionServiceIdentificatorIndex = tvcSubscriptionServiceIdentificatorIndex;
		vrsparamsTvc.add(version, tvc_params);
		abi_params.abiPlatformContract = abiPlatformContract;
		abi_params.abiEverduesAccountContract = abiEverduesAccountContract;
		abi_params.abiEverduesRootContract = abiEverduesRootContract;
		abi_params.abiTIP3RootContract = abiTIP3RootContract;
		abi_params.abiTIP3TokenWalletContract = abiTIP3TokenWalletContract;
		abi_params.abiServiceContract = abiServiceContract;
		abi_params.abiServiceIndexContract = abiServiceIndexContract;
		abi_params
			.abiServiceIdentificatorIndexContract = abiServiceIdentificatorIndexContract;
		abi_params.abiSubscriptionContract = abiSubscriptionContract;
		abi_params.abiSubscriptionIndexContract = abiSubscriptionIndexContract;
		abi_params
			.abiSubscriptionIdentificatorIndexContract = abiSubscriptionIdentificatorIndexContract;
		abi_params.abiFeeProxyContract = abiFeeProxyContract;
		vrsparamsAbi.add(version, abi_params);
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
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
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
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
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
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
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
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
		EverduesFeeProxy(fee_proxy_address).setSupportedCurrencies{
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
		EverduesFeeProxy(fee_proxy_address).setMTDSRootAddress{
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(mtds_root_address, owner);
	}

	function installOrUpgradeDexRootAddress(address dex_root)
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
		dex_root_address = dex_root;
		EverduesFeeProxy(fee_proxy_address).setDexRootAddress{
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(dex_root_address, owner);
	}

	// Managment
	function transferRevenueFromFeeProxy() external view onlyOwner {
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
		EverduesFeeProxy(fee_proxy_address).transferRevenue{
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(mtds_revenue_accumulator_address, owner);
	}

	function swapRevenue(address currency_root) external view onlyOwner {
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
		EverduesFeeProxy(fee_proxy_address).swapRevenueToMTDS{
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(currency_root, owner);
	}

	function syncFeeProxyBalance(address currency_root)
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
		EverduesFeeProxy(fee_proxy_address).syncBalance{
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(currency_root, owner);
	}

	// Upgrade contracts
	function upgradeFeeProxy() external view onlyOwner {
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
		EverduesFeeProxy(fee_proxy_address).upgrade{
			value: 0,
			bounce: true,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(
			vrsparamsTvc[version].tvcFeeProxy.toSlice().loadRef(),
			fee_proxy_version,
			msg.sender
		);
	}

	function upgradeAccount(uint256 pubkey) external view {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		address account_address = address(
			tvm.hash(_buildAccountInitData(PlatformTypes.Account, pubkey))
		);
		require(
			msg.sender == account_address,
			EverduesErrors.error_message_sender_is_not_account_address
		);
		EverduesAccount(account_address).upgrade{
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(
			vrsparamsTvc[version].tvcEverduesAccount.toSlice().loadRef(),
			account_version
		);
	}

	function upgradeSubscription(address service_address) external view {
		require(
			service_address != address(0),
			EverduesErrors.error_address_is_empty
		);
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		TvmCell subscription_code_salt = _buildSubscriptionCode(msg.sender);
		address subscription_address = address(
			tvm.hash(
				_buildInitData(
					PlatformTypes.Subscription,
					_buildSubscriptionPlatformParams(
						msg.sender,
						service_address
					)
				)
			)
		);
		Subscription(subscription_address).upgrade{
			value: 0,
			bounce: true, // TODO: need to revert balance back to current msg.sender in case of failure
			flag: MsgFlag.ALL_NOT_RESERVED
		}(subscription_code_salt, subscription_version, msg.sender);
	}

	function updateSubscriptionIdentificator(
		address service_address,
		TvmCell identificator
	) external view {
		require(
			service_address != address(0),
			EverduesErrors.error_address_is_empty
		);
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		address subscription_address = address(
			tvm.hash(
				_buildInitData(
					PlatformTypes.Subscription,
					_buildSubscriptionPlatformParams(
						msg.sender,
						service_address
					)
				)
			)
		);
		Subscription(subscription_address).updateIdentificator{
			value: 0,
			bounce: true,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(identificator, msg.sender);
	}

	function upgradeService(string service_name, string category)
		external
		view
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		TvmCell service_code_salt = _buildServiceCode(category);
		address service_address = address(
			tvm.hash(
				_buildInitData(
					PlatformTypes.Service,
					_buildServicePlatformParams(msg.sender, service_name)
				)
			)
		);
		SubscriptionService(service_address).upgrade{
			value: 0,
			bounce: true,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(service_code_salt, service_version, msg.sender);
	}

	function updateServiceParams(
		string service_name,
		TvmCell new_service_params
	) external view {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		address service_address = address(
			tvm.hash(
				_buildInitData(
					PlatformTypes.Service,
					_buildServicePlatformParams(msg.sender, service_name)
				)
			)
		);
		SubscriptionService(service_address).updateServiceParams{
			value: 0,
			bounce: true,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(new_service_params);
	}

	function updateServiceIdentificator(
		string service_name,
		TvmCell identificator
	) public view {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		address service_address = address(
			tvm.hash(
				_buildInitData(
					PlatformTypes.Service,
					_buildServicePlatformParams(msg.sender, service_name)
				)
			)
		);
		SubscriptionService(service_address).updateIdentificator{
			value: 0,
			bounce: true,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(identificator, msg.sender);
	}

	function upgrade(TvmCell code) external onlyOwner {
		require(
			msg.value >= EverduesGas.UPGRADE_ROOT_MIN_VALUE,
			EverduesErrors.error_message_low_value
		);

		TvmCell upgrade_data = abi.encode(
			account_version,
			owner,
			service_version,
			fee_proxy_version,
			subscription_version,
			vrsparamsTvc,
			vrsparamsAbi,
			version,
			has_platform_code,
			fee_proxy_address,
			categories,
			service_fee,
			subscription_fee,
			dex_root_address,
			mtds_root_address,
			mtds_revenue_accumulator_address,
			tvcPlatform,
			tvcEverduesAccount,
			tvcSubscriptionService,
			tvcSubscription,
			tvcSubscriptionServiceIndex,
			tvcSubscriptionServiceIdentificatorIndex,
			tvcSubscriptionIndex,
			tvcSubscriptionIdentificatorIndex,
			tvcFeeProxy,
			abiPlatformContract,
			abiEverduesAccountContract,
			abiEverduesRootContract,
			abiTIP3RootContract,
			abiTIP3TokenWalletContract,
			abiServiceContract,
			abiServiceIndexContract,
			abiSubscriptionContract,
			abiSubscriptionIndexContract,
			abiSubscriptionIdentificatorIndexContract,
			abiFeeProxyContract,
			abiServiceIdentificatorIndexContract
		);
		tvm.setcode(code);
		tvm.setCurrentCode(code);
		onCodeUpgrade(upgrade_data);
	}

	function onCodeUpgrade(TvmCell upgrade_data) private {
		tvm.rawReserve(EverduesGas.ROOT_INITIAL_BALANCE, 2);
		tvm.resetStorage();
		(
			account_version,
			owner,
			service_version,
			fee_proxy_version,
			subscription_version,
			vrsparamsTvc,
			vrsparamsAbi,
			version,
			has_platform_code,
			fee_proxy_address,
			categories,
			service_fee,
			subscription_fee,
			dex_root_address,
			mtds_root_address,
			mtds_revenue_accumulator_address,
			tvcPlatform,
			tvcEverduesAccount,
			tvcSubscriptionService,
			tvcSubscription,
			tvcSubscriptionServiceIndex,
			tvcSubscriptionServiceIdentificatorIndex,
			tvcSubscriptionIndex,
			tvcSubscriptionIdentificatorIndex,
			tvcFeeProxy,
			abiPlatformContract,
			abiEverduesAccountContract,
			abiEverduesRootContract,
			abiTIP3RootContract,
			abiTIP3TokenWalletContract,
			abiServiceContract,
			abiServiceIndexContract,
			abiSubscriptionContract,
			abiSubscriptionIndexContract,
			abiSubscriptionIdentificatorIndexContract,
			abiFeeProxyContract,
			abiServiceIdentificatorIndexContract
		) = abi.decode(
				upgrade_data,
				(
					uint32,
					address,
					uint32,
					uint32,
					uint32,
					mapping(uint8 => EverduesRoot.VersionsTvcParams),
					mapping(uint8 => EverduesRoot.VersionsAbiParams),
					uint8,
					bool,
					address,
					string[],
					uint8,
					uint8,
					address,
					address,
					address,
					TvmCell,
					TvmCell,
					TvmCell,
					TvmCell,
					TvmCell,
					TvmCell,
					TvmCell,
					TvmCell,
					TvmCell,
					string,
					string,
					string,
					string,
					string,
					string,
					string,
					string,
					string,
					string,
					string,
					string
				)
			);
		owner.transfer({
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}

	// Deploy contracts
	function deployFeeProxy(address[] currencies) external onlyOwner {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		TvmCell fee_proxy_contract_params = abi.encode(currencies);
		Platform platform = new Platform{
			stateInit: _buildInitData(
				PlatformTypes.FeeProxy,
				_buildPlatformParamsOwnerAddress(address(this))
			),
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(
			vrsparamsTvc[version].tvcFeeProxy.toSlice().loadRef(),
			fee_proxy_contract_params,
			fee_proxy_version,
			msg.sender,
			0
		);
		fee_proxy_address = address(platform);
	}

	function cancelService(string service_name) external view {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		address service_address = address(
			tvm.hash(
				_buildInitData(
					PlatformTypes.Service,
					_buildServicePlatformParams(msg.sender, service_name)
				)
			)
		);
		IEverduesSubscriptionService(service_address).cancel{
			value: 0,
			bounce: true,
			flag: MsgFlag.ALL_NOT_RESERVED
		}();
	}

	function cancelSubscription(address service_address) external view {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		address subscription_address = address(
			tvm.hash(
				_buildInitData(
					PlatformTypes.Subscription,
					_buildSubscriptionPlatformParams(
						msg.sender,
						service_address
					)
				)
			)
		);
		ISubscription(subscription_address).cancel{
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED
		}();
	}

	function deployAccount(uint256 pubkey) external view {
		address account_address = address(
			tvm.hash(_buildAccountInitData(PlatformTypes.Account, pubkey))
		);
		require(
			msg.sender == account_address,
			EverduesErrors.error_message_sender_is_not_account_address
		);
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);

		TvmCell account_params;

		IPlatform(msg.sender).initializeByRoot{
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(
			vrsparamsTvc[version].tvcEverduesAccount.toSlice().loadRef(),
			account_params,
			account_version
		);
	}

	function deploySubscription(
		address service_address,
		TvmCell identificator,
		uint256 owner_pubkey,
		uint128 additional_gas
	) external view {
		require(
			service_address != address(0),
			EverduesErrors.error_address_is_empty
		);
		require(
			fee_proxy_address != address(0),
			EverduesErrors.error_address_is_empty
		);
		require(
			msg.value >=
				(EverduesGas.SUBSCRIPTION_INITIAL_BALANCE +
					EverduesGas.INIT_SUBSCRIPTION_VALUE +
					EverduesGas.EXECUTE_SUBSCRIPTION_VALUE +
					EverduesGas.INDEX_INITIAL_BALANCE *
					2 +
					additional_gas),
			EverduesErrors.error_message_low_value
		);
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);

		TvmCell subsIndexStateInit = _buildSubscriptionIndex(
			service_address,
			msg.sender
		);
		TvmCell subsIndexIdentificatorStateInit = _buildSubscriptionIdentificatorIndex(
				service_address,
				identificator,
				msg.sender
			);
		TvmCell subscription_code_salt = _buildSubscriptionCode(msg.sender);
		address owner_account_address = address(
			tvm.hash(_buildAccountInitData(PlatformTypes.Account, owner_pubkey))
		);
		address subs_index = address(tvm.hash(subsIndexStateInit));
		address subs_index_identificator = address(
			tvm.hash(subsIndexIdentificatorStateInit)
		);
		TvmCell subscription_params = abi.encode(
			fee_proxy_address,
			service_fee,
			subscription_fee,
			tvm.pubkey(),
			subs_index,
			subs_index_identificator,
			service_address,
			owner_account_address,
			owner_pubkey
		);

		Platform platform = new Platform{
			stateInit: _buildInitData(
				PlatformTypes.Subscription,
				_buildSubscriptionPlatformParams(msg.sender, service_address)
			),
			value: EverduesGas.SUBSCRIPTION_INITIAL_BALANCE +
				EverduesGas.INIT_SUBSCRIPTION_VALUE +
				EverduesGas.EXECUTE_SUBSCRIPTION_VALUE +
				(additional_gas / 3),
			flag: MsgFlag.SENDER_PAYS_FEES
		}(
			subscription_code_salt,
			subscription_params,
			subscription_version,
			msg.sender,
			0
		);
		new SubscriptionIndex{
			value: EverduesGas.INDEX_INITIAL_BALANCE +
				(additional_gas / 3 - 100),
			flag: MsgFlag.SENDER_PAYS_FEES,
			bounce: false,
			stateInit: subsIndexStateInit
		}(address(platform));
		if (!identificator.toSlice().empty()) {
			new SubscriptionIdentificatorIndex{
				value: EverduesGas.INDEX_INITIAL_BALANCE +
					(additional_gas / 3 - 100),
				flag: MsgFlag.SENDER_PAYS_FEES,
				bounce: false,
				stateInit: subsIndexIdentificatorStateInit
			}(address(platform));
		}
		msg.sender.transfer({
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}

	function deployService(
		TvmCell service_params,
		TvmCell identificator,
		uint128 additional_gas
	) external view {
		require(
			msg.value >=
				(EverduesGas.SERVICE_INITIAL_BALANCE +
					EverduesGas.INDEX_INITIAL_BALANCE *
					2 +
					EverduesGas.INIT_MESSAGE_VALUE *
					4 +
					EverduesGas.SET_SERVICE_INDEXES_VALUE +
					additional_gas),
			EverduesErrors.error_message_low_value
		);
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		TvmCell next_cell;
		string category;
		string service_name;
		(, , , next_cell) = service_params.toSlice().decode(
			address,
			uint128,
			uint32,
			TvmCell
		);
		(service_name, , , next_cell) = next_cell.toSlice().decode(
			string,
			string,
			string,
			TvmCell
		);
		(, category) = next_cell.toSlice().decode(address, string);
		TvmCell service_code_salt = _buildServiceCode(category);
		Platform platform = new Platform{
			stateInit: _buildInitData(
				PlatformTypes.Service,
				_buildServicePlatformParams(msg.sender, service_name)
			),
			value: EverduesGas.SERVICE_INITIAL_BALANCE +
				EverduesGas.INIT_MESSAGE_VALUE +
				(additional_gas / 4),
			flag: MsgFlag.SENDER_PAYS_FEES
		}(service_code_salt, service_params, service_version, msg.sender, 0);
		TvmCell serviceIndexStateInit = _buildServiceIndex(
			msg.sender,
			service_name
		);
		TvmCell serviceIdentificatorIndexStateInit = _buildServiceIdentificatorIndex(
				msg.sender,
				identificator,
				address(platform)
			);
		SubscriptionService(address(platform)).setIndexes{
			value: EverduesGas.SET_SERVICE_INDEXES_VALUE +
				EverduesGas.INIT_MESSAGE_VALUE +
				(additional_gas / 4),
			flag: MsgFlag.SENDER_PAYS_FEES
		}(
			address(tvm.hash(serviceIndexStateInit)),
			address(tvm.hash(serviceIdentificatorIndexStateInit))
		);
		new SubscriptionServiceIndex{
			value: EverduesGas.INDEX_INITIAL_BALANCE +
				EverduesGas.INIT_MESSAGE_VALUE +
				(additional_gas / 4),
			flag: MsgFlag.SENDER_PAYS_FEES,
			bounce: false,
			stateInit: serviceIndexStateInit
		}(address(platform));
		if (!identificator.toSlice().empty()) {
			new SubscriptionServiceIdentificatorIndex{
				value: EverduesGas.INDEX_INITIAL_BALANCE +
					EverduesGas.INIT_MESSAGE_VALUE +
					(additional_gas / 4),
				flag: MsgFlag.SENDER_PAYS_FEES,
				bounce: false,
				stateInit: serviceIdentificatorIndexStateInit
			}();
		}
		msg.sender.transfer({
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}

	// Builders

	function _buildSubscriptionCode(address subscription_owner)
		private
		view
		returns (TvmCell)
	{
		TvmBuilder saltBuilder;
		saltBuilder.store(subscription_owner, address(this)); // Max 4 items
		TvmCell code = tvm.setCodeSalt(
			vrsparamsTvc[version].tvcSubscription.toSlice().loadRef(),
			saltBuilder.toCell()
		);
		return code;
	}

	function _buildServiceCode(string category) private view returns (TvmCell) {
		TvmBuilder saltBuilder;
		saltBuilder.store(category, address(this)); // Max 4 items
		TvmCell code = tvm.setCodeSalt(
			vrsparamsTvc[version].tvcSubscriptionService.toSlice().loadRef(),
			saltBuilder.toCell()
		);
		return code;
	}

	function _buildSubscriptionIdentificatorIndex(
		address service_address,
		TvmCell identificator,
		address subscription_owner
	) private view returns (TvmCell) {
		TvmBuilder saltBuilder;
		saltBuilder.store(service_address, identificator, address(this));
		TvmCell code = tvm.setCodeSalt(
			vrsparamsTvc[version]
				.tvcSubscriptionIdentificatorIndex
				.toSlice()
				.loadRef(),
			saltBuilder.toCell()
		);
		TvmCell stateInit = tvm.buildStateInit({
			code: code,
			pubkey: 0,
			varInit: {subscription_owner: subscription_owner},
			contr: SubscriptionIdentificatorIndex
		});
		return stateInit;
	}

	function _buildSubscriptionIndex(
		address service_address,
		address subscription_owner
	) private view returns (TvmCell) {
		TvmBuilder saltBuilder;
		saltBuilder.store(service_address, address(this));
		TvmCell code = tvm.setCodeSalt(
			vrsparamsTvc[version].tvcSubscriptionIndex.toSlice().loadRef(),
			saltBuilder.toCell()
		);
		TvmCell stateInit = tvm.buildStateInit({
			code: code,
			pubkey: 0,
			varInit: {subscription_owner: subscription_owner},
			contr: SubscriptionIndex
		});
		return stateInit;
	}

	function _buildServiceIndex(address serviceOwner, string service_name)
		private
		view
		returns (TvmCell)
	{
		TvmBuilder saltBuilder;
		saltBuilder.store(serviceOwner, address(this));
		TvmCell code = tvm.setCodeSalt(
			vrsparamsTvc[version]
				.tvcSubscriptionServiceIndex
				.toSlice()
				.loadRef(),
			saltBuilder.toCell()
		);
		TvmCell state = tvm.buildStateInit({
			code: code,
			pubkey: 0,
			varInit: {service_name: service_name},
			contr: SubscriptionServiceIndex
		});
		return state;
	}

	function _buildServiceIdentificatorIndex(
		address serviceOwner,
		TvmCell identificator_,
		address service_address
	) private view returns (TvmCell) {
		TvmBuilder saltBuilder;
		saltBuilder.store(identificator_, address(this));
		TvmCell code = tvm.setCodeSalt(
			vrsparamsTvc[version]
				.tvcSubscriptionServiceIdentificatorIndex
				.toSlice()
				.loadRef(),
			saltBuilder.toCell()
		);
		TvmCell state = tvm.buildStateInit({
			code: code,
			pubkey: 0,
			varInit: {
				service_owner: serviceOwner,
				service_address: service_address
			},
			contr: SubscriptionServiceIdentificatorIndex
		});
		return state;
	}

	function _buildInitData(uint8 type_id, TvmCell params)
		private
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
				code: vrsparamsTvc[version].tvcPlatform.toSlice().loadRef()
			});
	}

	function _buildAccountInitData(uint8 type_id, uint256 pubkey)
		private
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
				code: vrsparamsTvc[version].tvcPlatform.toSlice().loadRef()
			});
	}

	function _buildPlatformParamsOwnerAddress(address account_owner)
		private
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
	) private inline pure returns (TvmCell) {
		TvmBuilder builder;
		builder.store(subscription_owner);
		builder.store(service_address);
		return builder.toCell();
	}

	function _buildServicePlatformParams(
		address service_owner,
		string service_name
	) private inline pure returns (TvmCell) {
		TvmBuilder builder;
		builder.store(service_owner);
		builder.store(service_name);
		return builder.toCell();
	}

	// Addresses calculations

	function accountOf(uint256 owner_pubkey)
		public
		view
		returns (address account)
	{
		account = address(
			tvm.hash(_buildAccountInitData(PlatformTypes.Account, owner_pubkey))
		);
	}

	function serviceOf(address owner_address_, string service_name_)
		public
		view
		returns (address service)
	{
		service = address(
			tvm.hash(
				_buildInitData(
					PlatformTypes.Service,
					_buildServicePlatformParams(owner_address_, service_name_)
				)
			)
		);
	}

	function subscriptionOf(address owner_address_, address service_address_)
		public
		view
		returns (address subscription)
	{
		subscription = address(
			tvm.hash(
				_buildInitData(
					PlatformTypes.Subscription,
					_buildSubscriptionPlatformParams(
						owner_address_,
						service_address_
					)
				)
			)
		);
	}
}
