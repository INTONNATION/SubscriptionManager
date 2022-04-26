pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/MetaduesErrors.sol";
import "libraries/PlatformTypes.sol";
import "libraries/MsgFlag.sol";
import "libraries/MetaduesGas.sol";
import "./Platform.sol";
import "../contracts/SubscriptionIndex.sol";
import "../contracts/SubscriptionIdentificatorIndex.sol";
import "../contracts/SubscriptionServiceIndex.sol";
import "../contracts/MetaduesFeeProxy.sol";
import "../contracts/MetaduesAccount.sol";
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

contract MetaduesRoot {
	uint256 tmp_pubkey; //debug
	uint8 public versionTvc;
	uint8 public versionAbi;
	string[] public categories;

	TvmCell tvcPlatform;
	TvmCell tvcMetaduesAccount;
	TvmCell tvcSubscriptionService;
	TvmCell tvcSubscription;
	TvmCell tvcSubscriptionServiceIndex;
	TvmCell tvcSubscriptionServiceIdentificatorIndex;
	TvmCell tvcSubscriptionIndex;
	TvmCell tvcSubscriptionIdentificatorIndex;
	TvmCell tvcFeeProxy;

	string abiPlatformContract;
	string abiMetaduesAccountContract;
	string abiMetaduesRootContract;
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
		TvmCell tvcMetaduesAccount;
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
		string abiMetaduesAccountContract;
		string abiMetaduesRootContract;
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

	onBounce(TvmSlice slice) external {
		// revert change to initial msg.sender in case of failure during deploy
		// TODO check SubsMan balance after that
		uint32 functionId = slice.decode(uint32);
	}

	constructor(address initial_owner) public {
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		tvm.accept();
		owner = initial_owner;
		owner.transfer({value: 0, flag: MsgFlag.ALL_NOT_RESERVED});
	}

	modifier onlyOwner() {
		require(
			msg.sender == owner,
			MetaduesErrors.error_message_sender_is_not_my_owner
		);
		tvm.accept();
		_;
	}

	function transferOwner(address new_owner) external onlyOwner {
		require(
			owner != new_owner,
			MetaduesErrors.error_message_sender_is_equal_owner
		);
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		pending_owner = new_owner;
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function acceptOwner() external {
		require(msg.sender.value != 0, MetaduesErrors.error_address_is_empty);
		require(
			msg.sender == pending_owner,
			MetaduesErrors.error_message_sender_is_not_pending_owner
		);
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		owner = pending_owner;
		pending_owner = address.makeAddrStd(0, 0);
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
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
		optional(VersionsTvcParams) value = vrsparamsTvc.fetch(versionTvc);
		return value;
	}

	// Get all latest TVCs
	function getTvcsLatestResponsible()
		external
		view
		responsible
		returns (VersionsTvcParams)
	{
		VersionsTvcParams value = vrsparamsTvc[versionTvc];
		return (value);
	}

	// Get all latest ABIs
	function getAbisLatest() public view returns (optional(VersionsAbiParams)) {
		optional(VersionsAbiParams) value = vrsparamsAbi.fetch(versionAbi);
		return value;
	}

	function getOwner() external view responsible returns (address owner) {
		return owner;
	}

	// Settings
	function setTvcPlatform(TvmCell tvcPlatformInput) external onlyOwner {
		require(
			!has_platform_code,
			MetaduesErrors.error_platform_code_is_not_empty
		);
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		tvcPlatform = tvcPlatformInput;
		has_platform_code = true;
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function setTvcMetaduesAccount(TvmCell tvcMetaduesAccountInput)
		external
		onlyOwner
	{
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		tvcMetaduesAccount = tvcMetaduesAccountInput;
		account_version++;
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function setTvcSubscriptionService(TvmCell tvcSubscriptionServiceInput)
		external
		onlyOwner
	{
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		tvcSubscriptionService = tvcSubscriptionServiceInput;
		service_version++;
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function setTvcSubscription(TvmCell tvcSubscriptionInput)
		external
		onlyOwner
	{
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		tvcSubscription = tvcSubscriptionInput;
		subscription_version++;
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function setTvcSubscriptionServiceIndex(
		TvmCell tvcSubscriptionServiceIndexInput
	) external onlyOwner {
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		tvcSubscriptionServiceIndex = tvcSubscriptionServiceIndexInput;
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function setTvcSubscriptionServiceIdentificatorIndex(
		TvmCell tvcSubscriptionServiceIdentificatorIndexInput
	) external onlyOwner {
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		tvcSubscriptionServiceIdentificatorIndex = tvcSubscriptionServiceIdentificatorIndexInput;
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function setTvcSubscriptionIndex(TvmCell tvcSubscriptionIndexInput)
		external
		onlyOwner
	{
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		tvcSubscriptionIndex = tvcSubscriptionIndexInput;
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function setTvcSubscriptionIdentificatorIndex(
		TvmCell tvcSubscriptionIdentificatorIndexInput
	) external onlyOwner {
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		tvcSubscriptionIdentificatorIndex = tvcSubscriptionIdentificatorIndexInput;
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function setTvcFeeProxy(TvmCell tvcFeeProxyInput) external onlyOwner {
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		tvcFeeProxy = tvcFeeProxyInput;
		fee_proxy_version++;
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function setTvc() external onlyOwner {
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		versionTvc++;
		VersionsTvcParams params;
		params.tvcPlatform = tvcPlatform;
		params.tvcMetaduesAccount = tvcMetaduesAccount;
		params.tvcSubscriptionService = tvcSubscriptionService;
		params.tvcSubscription = tvcSubscription;
		params.tvcSubscriptionServiceIndex = tvcSubscriptionServiceIndex;
		params.tvcSubscriptionIndex = tvcSubscriptionIndex;
		params
			.tvcSubscriptionIdentificatorIndex = tvcSubscriptionIdentificatorIndex;
		params.tvcFeeProxy = tvcFeeProxy;
		params
			.tvcSubscriptionServiceIdentificatorIndex = tvcSubscriptionServiceIdentificatorIndex;
		vrsparamsTvc.add(versionTvc, params);
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	// Set ABIs
	function setAbiPlatformContract(string abiPlatformContractInput)
		external
		onlyOwner
	{
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		abiPlatformContract = abiPlatformContractInput;
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function setAbiMetaduesAccountContract(
		string abiMetaduesAccountContractInput
	) external onlyOwner {
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		abiMetaduesAccountContract = abiMetaduesAccountContractInput;
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function setAbiMetaduesRootContract(string abiMetaduesRootContractInput)
		external
		onlyOwner
	{
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		abiMetaduesRootContract = abiMetaduesRootContractInput;
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function setAbiTIP3RootContract(string abiTIP3RootContractInput)
		external
		onlyOwner
	{
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		abiTIP3RootContract = abiTIP3RootContractInput;
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function setAbiTIP3TokenWalletContract(
		string abiTIP3TokenWalletContractInput
	) external onlyOwner {
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		abiTIP3TokenWalletContract = abiTIP3TokenWalletContractInput;
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function setAbiServiceContract(string abiServiceContractInput)
		external
		onlyOwner
	{
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		abiServiceContract = abiServiceContractInput;
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function setAbiServiceIndexContract(string abiServiceIndexContractInput)
		external
		onlyOwner
	{
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		abiServiceIndexContract = abiServiceIndexContractInput;
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function setAbiServiceIdentificatorIndexContract(
		string abiServiceIdentificatorIndexContractInput
	) external onlyOwner {
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		abiServiceIdentificatorIndexContract = abiServiceIdentificatorIndexContractInput;
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function setAbiSubscriptionContract(string abiSubscriptionContractInput)
		external
		onlyOwner
	{
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		abiSubscriptionContract = abiSubscriptionContractInput;
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function setAbiSubscriptionIndexContract(
		string abiSubscriptionIndexContractInput
	) external onlyOwner {
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		abiSubscriptionIndexContract = abiSubscriptionIndexContractInput;
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function setAbiSubscriptionIdentificatorIndexContract(
		string abiSubscriptionIdentificatorIndexContractInput
	) external onlyOwner {
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		abiSubscriptionIdentificatorIndexContract = abiSubscriptionIdentificatorIndexContractInput;
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function setAbiFeeProxyContract(string abiFeeProxyContractInput)
		external
		onlyOwner
	{
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		abiFeeProxyContract = abiFeeProxyContractInput;
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function setAbi() external onlyOwner {
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		versionAbi++;
		VersionsAbiParams params;
		params.abiPlatformContract = abiPlatformContract;
		params.abiMetaduesAccountContract = abiMetaduesAccountContract;
		params.abiMetaduesRootContract = abiMetaduesRootContract;
		params.abiTIP3RootContract = abiTIP3RootContract;
		params.abiTIP3TokenWalletContract = abiTIP3TokenWalletContract;
		params.abiServiceContract = abiServiceContract;
		params.abiServiceIndexContract = abiServiceIndexContract;
		params
			.abiServiceIdentificatorIndexContract = abiServiceIdentificatorIndexContract;
		params.abiSubscriptionContract = abiSubscriptionContract;
		params.abiSubscriptionIndexContract = abiSubscriptionIndexContract;
		params
			.abiSubscriptionIdentificatorIndexContract = abiSubscriptionIdentificatorIndexContract;
		params.abiFeeProxyContract = abiFeeProxyContract;
		vrsparamsAbi.add(versionAbi, params);
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function setCategories(string[] categoriesInput) external onlyOwner {
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		categories = categoriesInput;
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function setFees(uint8 service_fee_, uint8 subscription_fee_)
		external
		onlyOwner
	{
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		service_fee = service_fee_;
		subscription_fee = subscription_fee_;
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function installOrUpgradeMTDSRevenueDelegationAddress(address revenue_to)
		external
		onlyOwner
	{
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		mtds_revenue_accumulator_address = revenue_to;
		owner.transfer({value: 0, flag: MsgFlag.REMAINING_GAS});
	}

	function installOrUpdateFeeProxyParams(address[] currencies)
		external
		onlyOwner
	{
		require(
			fee_proxy_address != address(0),
			MetaduesErrors.error_address_is_empty
		);
		tvm.rawReserve(
			math.max(
				MetaduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		TvmBuilder currencies_cell;
		currencies_cell.store(currencies);
		TvmCell fee_proxy_contract_params = currencies_cell.toCell();
		MetaduesFeeProxy(fee_proxy_address).setSupportedCurrencies{
			value: 0,
			bounce: true, // need to handle
			flag: MsgFlag.ALL_NOT_RESERVED
		}(fee_proxy_contract_params, owner);
	}

	function installOrUpgradeMTDSRootAddress(address mtds_root_)
		external
		onlyOwner
	{
		require(
			fee_proxy_address != address(0),
			MetaduesErrors.error_address_is_empty
		);
		tvm.rawReserve(
			math.max(
				MetaduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		mtds_root_address = mtds_root_;
		MetaduesFeeProxy(fee_proxy_address).setMTDSRootAddress{
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
			MetaduesErrors.error_address_is_empty
		);
		tvm.rawReserve(
			math.max(
				MetaduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		dex_root_address = dex_root;
		MetaduesFeeProxy(fee_proxy_address).setDexRootAddress{
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(dex_root_address, owner);
	}

	// Managment
	function transferRevenueFromFeeProxy() external view onlyOwner {
		require(
			fee_proxy_address != address(0),
			MetaduesErrors.error_address_is_empty
		);
		tvm.rawReserve(
			math.max(
				MetaduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		MetaduesFeeProxy(fee_proxy_address).transferRevenue{
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(mtds_revenue_accumulator_address, owner);
	}

	function swapRevenue(address currency_root) external view onlyOwner {
		require(
			fee_proxy_address != address(0),
			MetaduesErrors.error_address_is_empty
		);
		tvm.rawReserve(
			math.max(
				MetaduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		MetaduesFeeProxy(fee_proxy_address).swapRevenueToMTDS{
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
			MetaduesErrors.error_address_is_empty
		);
		tvm.rawReserve(
			math.max(
				MetaduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		MetaduesFeeProxy(fee_proxy_address).syncBalance{
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(currency_root, owner);
	}

	// Upgrade contracts
	function upgradeFeeProxy() external view onlyOwner {
		require(
			fee_proxy_address != address(0),
			MetaduesErrors.error_address_is_empty
		);
		tvm.rawReserve(
			math.max(
				MetaduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		MetaduesFeeProxy(fee_proxy_address).upgrade{
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(tvcFeeProxy.toSlice().loadRef(), fee_proxy_version, msg.sender);
	}

	function upgradeAccount(uint256 pubkey) external view {
		tvm.rawReserve(
			math.max(
				MetaduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		address account_address = address(
			tvm.hash(_buildAccountInitData(PlatformTypes.Account, pubkey))
		);
		//check that msg.sender from correct account platform
		require(msg.sender == account_address, 1111);
		MetaduesAccount(account_address).upgrade{
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(tvcMetaduesAccount.toSlice().loadRef(), account_version);
	}

	function upgradeSubscription(address service_address, TvmCell identificator)
		external
		view
	{
		require(
			service_address != address(0),
			MetaduesErrors.error_address_is_empty
		);
		tvm.rawReserve(
			math.max(
				MetaduesGas.ROOT_INITIAL_BALANCE,
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
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(subscription_code_salt, subscription_version, msg.sender);
	}

	function upgradeService(string service_name, string category)
		external
		view
	{
		tvm.rawReserve(
			math.max(
				MetaduesGas.ROOT_INITIAL_BALANCE,
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
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(service_code_salt, service_version, msg.sender);
	}

	function upgrade(TvmCell code) external onlyOwner {
		require(
			msg.value >= MetaduesGas.UPGRADE_ROOT_MIN_VALUE,
			MetaduesErrors.error_message_low_value
		);

		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);

		TvmBuilder builder;
		builder.store(account_version);
		builder.store(owner);
		builder.store(service_version);
		builder.store(fee_proxy_version);
		builder.store(subscription_version);
		builder.store(vrsparamsTvc);
		builder.store(vrsparamsAbi);
		tvm.setcode(code);
		tvm.setCurrentCode(code);
		onCodeUpgrade(builder.toCell());
	}

	function onCodeUpgrade(TvmCell upgrade_data) private {
		tvm.rawReserve(MetaduesGas.ROOT_INITIAL_BALANCE, 2);
		tvm.resetStorage();
		(
			uint32 account_version_,
			address owner_,
			uint32 service_version_,
			uint32 fee_proxy_version_,
			uint32 subscription_version_
		) = upgrade_data.toSlice().decode(
				uint32,
				address,
				uint32,
				uint32,
				uint32
			);
		// decode vrsparamsAbi and vrsparamsTvc
		account_version = account_version_;
		service_version = service_version_;
		fee_proxy_version = fee_proxy_version_;
		subscription_version = subscription_version_;

		owner = owner_;
		owner.transfer({
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}

	// Deploy contracts
	function deployFeeProxy(address[] currencies) external onlyOwner {
		tvm.rawReserve(
			math.max(
				MetaduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		TvmBuilder currencies_cell;
		currencies_cell.store(currencies);
		TvmCell fee_proxy_contract_params = currencies_cell.toCell();
		Platform platform = new Platform{
			stateInit: _buildInitData(
				PlatformTypes.FeeProxy,
				_buildPlatformParamsOwnerAddress(address(this))
			),
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(
			tvcFeeProxy.toSlice().loadRef(),
			fee_proxy_contract_params,
			fee_proxy_version,
			msg.sender,
			0
		);
		fee_proxy_address = address(platform);
	}

	function cancelService(string service_name) external {
		tvm.rawReserve(
			math.max(
				MetaduesGas.ROOT_INITIAL_BALANCE,
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
			flag: MsgFlag.ALL_NOT_RESERVED
		}();
	}

	function cancelSubscription(address service_address) external {
		tvm.rawReserve(
			math.max(
				MetaduesGas.ROOT_INITIAL_BALANCE,
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

	function deployAccount(uint256 pubkey) external {
		address account_address = address(
			tvm.hash(_buildAccountInitData(PlatformTypes.Account, pubkey))
		);
		require(msg.sender == account_address, 1111);
		tvm.rawReserve(
			math.max(
				MetaduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);

		TvmCell account_params;

		IPlatform(msg.sender).initializeByRoot{
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(
			tvcMetaduesAccount.toSlice().loadRef(),
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
			MetaduesErrors.error_address_is_empty
		);
		require(
			fee_proxy_address != address(0),
			MetaduesErrors.error_address_is_empty
		);
		require(
			msg.value >=
				(MetaduesGas.SUBSCRIPTION_INITIAL_BALANCE +
					MetaduesGas.INIT_SUBSCRIPTION_VALUE +
					MetaduesGas.EXECUTE_SUBSCRIPTION_VALUE +
					MetaduesGas.INDEX_INITIAL_BALANCE *
					2 +
					additional_gas),
			MetaduesErrors.error_message_low_value
		);
		tvm.rawReserve(
			math.max(
				MetaduesGas.ROOT_INITIAL_BALANCE,
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
		TvmBuilder service_params;
		TvmBuilder index_addresses;
		TvmBuilder fees_params;
		address owner_account_address = address(
			tvm.hash(_buildAccountInitData(PlatformTypes.Account, owner_pubkey))
		);
		address subs_index = address(tvm.hash(subsIndexStateInit));
		address subs_index_identificator = address(
			tvm.hash(subsIndexIdentificatorStateInit)
		);
		fees_params.store(fee_proxy_address, service_fee, subscription_fee);
		index_addresses.store(
			subs_index,
			subs_index_identificator,
			fees_params.toCell()
		);
		service_params.store(
			service_address,
			owner_account_address,
			index_addresses.toCell()
		);

		Platform platform = new Platform{
			stateInit: _buildInitData(
				PlatformTypes.Subscription,
				_buildSubscriptionPlatformParams(msg.sender, service_address)
			),
			value: MetaduesGas.SUBSCRIPTION_INITIAL_BALANCE +
				MetaduesGas.EXECUTE_SUBSCRIPTION_VALUE +
				(additional_gas / 3),
			flag: MsgFlag.SENDER_PAYS_FEES
		}(
			subscription_code_salt,
			service_params.toCell(),
			subscription_version,
			msg.sender,
			0
		);
		new SubscriptionIndex{
			value: MetaduesGas.INDEX_INITIAL_BALANCE +
				(additional_gas / 3 - 100),
			flag: MsgFlag.SENDER_PAYS_FEES,
			bounce: false,
			stateInit: subsIndexStateInit
		}(address(platform));
		if (!identificator.toSlice().empty()) {
			new SubscriptionIdentificatorIndex{
				value: MetaduesGas.INDEX_INITIAL_BALANCE +
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
				(MetaduesGas.SERVICE_INITIAL_BALANCE +
					MetaduesGas.INDEX_INITIAL_BALANCE *
					2 +
					MetaduesGas.SET_SERVICE_INDEXES_VALUE +
					additional_gas),
			MetaduesErrors.error_message_low_value
		);
		tvm.rawReserve(
			math.max(
				MetaduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		TvmCell next_cell;
		string category;
		string service_name;
		address currency_root;
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
			value: MetaduesGas.SERVICE_INITIAL_BALANCE +
				(additional_gas / 4) -
				100,
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
			value: MetaduesGas.SET_SERVICE_INDEXES_VALUE +
				(additional_gas / 4) -
				100,
			flag: MsgFlag.SENDER_PAYS_FEES
		}(
			address(tvm.hash(serviceIndexStateInit)),
			address(tvm.hash(serviceIdentificatorIndexStateInit))
		);
		new SubscriptionServiceIndex{
			value: MetaduesGas.INDEX_INITIAL_BALANCE +
				(additional_gas / 4) -
				100,
			flag: MsgFlag.SENDER_PAYS_FEES,
			bounce: false,
			stateInit: serviceIndexStateInit
		}(address(platform));
		if (!identificator.toSlice().empty()) {
			new SubscriptionServiceIdentificatorIndex{
				value: MetaduesGas.INDEX_INITIAL_BALANCE +
					(additional_gas / 4) -
					100,
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
			tvcSubscription.toSlice().loadRef(),
			saltBuilder.toCell()
		);
		return code;
	}

	function _buildServiceCode(string category) private view returns (TvmCell) {
		TvmBuilder saltBuilder;
		saltBuilder.store(category, address(this)); // Max 4 items
		TvmCell code = tvm.setCodeSalt(
			tvcSubscriptionService.toSlice().loadRef(),
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
			tvcSubscriptionIdentificatorIndex.toSlice().loadRef(),
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
			tvcSubscriptionIndex.toSlice().loadRef(),
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
			tvcSubscriptionServiceIndex.toSlice().loadRef(),
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
			tvcSubscriptionServiceIdentificatorIndex.toSlice().loadRef(),
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
				code: tvcPlatform.toSlice().loadRef()
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
				code: tvcPlatform.toSlice().loadRef()
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
