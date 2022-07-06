pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "Platform.sol";
import "libraries/EverduesErrors.sol";
import "libraries/PlatformTypes.sol";
import "libraries/MsgFlag.sol";
import "libraries/EverduesGas.sol";
import "../contracts/SubscriptionIndex.sol";
import "../contracts/SubscriptionIdentificatorIndex.sol";
import "../contracts/ServiceIndex.sol";
import "../contracts/EverduesFeeProxy.sol";
import "../contracts/EverduesAccount.sol";
import "../contracts/Subscription.sol";
import "../contracts/Service.sol";
import "../contracts/ServiceIdentificatorIndex.sol";

interface IPlatform {
	function initializeByRoot(
		TvmCell code,
		TvmCell contract_params,
		uint32 version
	) external;
}

contract EverduesRoot {

	TvmCell codePlatform;
	string abiPlatformContract;
	string abiEverduesRootContract;
	string abiTIP3RootContract;
	string abiTIP3TokenWalletContract;

	TvmCell codeEverduesAccount;
	TvmCell codeFeeProxy;
	TvmCell codeService;
	TvmCell codeServiceIndex;
	TvmCell codeServiceIdentificatorIndex;
	TvmCell codeSubscription;
	TvmCell codeSubscriptionIndex;
	TvmCell codeSubscriptionIdentificatorIndex;
	string abiEverduesAccountContract;
	string abiServiceContract;
	string abiServiceIndexContract;
	string abiSubscriptionContract;
	string abiSubscriptionIndexContract;
	string abiSubscriptionIdentificatorIndexContract;
	string abiFeeProxyContract;
	string abiServiceIdentificatorIndexContract;

	struct ContractVersionParams {
		TvmCell contractCode;
		string contractAbi;
	}

	mapping(uint8 => mapping(uint32 => ContractVersionParams)) public versions;

	bool has_platform_code;

	uint32 service_version;
	uint32 account_version;
	uint32 subscription_version;
	uint32 fee_proxy_version;

	address public fee_proxy_address;
	address public owner;
	address mtds_root_address;
	address mtds_revenue_accumulator_address;
	address dex_root_address;
	address wever_root;
	address pending_owner;
	address tip3_to_ever_address;

	uint8 service_fee;
	uint8 subscription_fee;
	string[] public categories;

	uint128 deploy_service_lock_value = 2 ever;
	uint128 account_threshold = 10 ever;

	onBounce(TvmSlice slice) external view {
		// revert change to initial msg.sender in case of failure during deploy
		// TODO: after https://github.com/tonlabs/ton-labs-node/issues/140
		//uint32 functionId = slice.decode(uint32);
	}

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

	modifier onlyOwner() {
		require(
			msg.sender == owner,
			EverduesErrors.error_message_sender_is_not_my_owner
		);
		tvm.accept();
		_;
	}

	modifier onlyAccountContract(uint256 pubkey) {
		address account_contract_address = address(
			tvm.hash(_buildAccountInitData(PlatformTypes.Account, pubkey))
		);
		require(
			msg.sender == account_contract_address,
			EverduesErrors.error_message_sender_is_not_account_address
		);
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
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
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
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	// Getters
	function getServiceCodeHashes()
		public
		view
		returns (uint256[] service_hashes)
	{
		uint256[] hashes;
		for ((uint32 key, ): versions[PlatformTypes.Service]) {
			// iteration over the mapping
			for (uint256 i = 0; i < categories.length; i++) {
				hashes.push(
					tvm.hash(
						_buildPublicServiceCodeByVersion(categories[i], key)
					)
				);
			}
		}
		service_hashes = hashes;
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

	// Settings
	function setCodePlatform(TvmCell codePlatformInput) external onlyOwner {
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
		codePlatform = codePlatformInput;
		has_platform_code = true;
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
		if (!abiEverduesAccountContract.empty()) {
			account_version++;
			addNewContractVersion_(
				PlatformTypes.Account,
				account_version,
				codeEverduesAccountInput,
				abiEverduesAccountContract
			);
			delete codeEverduesAccount;
			delete abiEverduesAccountContract;
		} else {
			codeEverduesAccount = codeEverduesAccountInput;
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
		if (!abiServiceContract.empty()) {
			service_version++;
			addNewContractVersion_(
				PlatformTypes.Service,
				service_version,
				codeServiceInput,
				abiServiceContract
			);
			delete codeService;
			delete abiServiceContract;
		} else {
			codeService = codeServiceInput;
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
		if (!abiSubscriptionContract.empty()) {
			subscription_version++;
			addNewContractVersion_(
				PlatformTypes.Subscription,
				subscription_version,
				codeSubscriptionInput,
				abiSubscriptionContract
			);
			delete codeSubscription;
			delete abiSubscriptionContract;
		} else {
			codeSubscription = codeSubscriptionInput;
		}
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function setCodeServiceIndex(TvmCell codeServiceIndexInput)
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
		if (!abiServiceIndexContract.empty()) {
			addNewContractVersion_(
				PlatformTypes.ServiceIndex,
				1,
				codeServiceIndexInput,
				abiServiceIndexContract
			);
			delete abiServiceIndexContract;
			delete codeServiceIndex;
		} else {
			codeServiceIndex = codeServiceIndexInput;
		}
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function setCodeServiceIdentificatorIndex(
		TvmCell codeServiceIdentificatorIndexInput
	) external onlyOwner {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		if (!abiServiceIdentificatorIndexContract.empty()) {
			addNewContractVersion_(
				PlatformTypes.ServiceIdentificatorIndex,
				1,
				codeServiceIdentificatorIndexInput,
				abiServiceIdentificatorIndexContract
			);
			delete abiServiceIdentificatorIndexContract;
			delete codeServiceIdentificatorIndex;
		} else {
			codeServiceIdentificatorIndex = codeServiceIdentificatorIndexInput;
		}
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function setCodeSubscriptionIndex(TvmCell codeSubscriptionIndexInput)
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
		if (!abiSubscriptionIndexContract.empty()) {
			addNewContractVersion_(
				PlatformTypes.SubscriptionIndex,
				1,
				codeSubscriptionIndexInput,
				abiSubscriptionIndexContract
			);
			delete codeSubscriptionIndex;
			delete abiSubscriptionIndexContract;
		} else {
			codeSubscriptionIndex = codeSubscriptionIndexInput;
		}
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
	}

	function setCodeSubscriptionIdentificatorIndex(
		TvmCell codeSubscriptionIdentificatorIndexInput
	) external onlyOwner {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		if (!abiSubscriptionIdentificatorIndexContract.empty()) {
			addNewContractVersion_(
				PlatformTypes.SubscriptionIdentificatorIndex,
				1,
				codeSubscriptionIdentificatorIndexInput,
				abiSubscriptionIdentificatorIndexContract
			);
			delete codeSubscriptionIdentificatorIndex;
			delete abiSubscriptionIdentificatorIndexContract;
		} else {
			codeSubscriptionIdentificatorIndex = codeSubscriptionIdentificatorIndexInput;
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
		if (!abiFeeProxyContract.empty()) {
			fee_proxy_version++;
			addNewContractVersion_(
				PlatformTypes.FeeProxy,
				1,
				codeFeeProxyInput,
				abiFeeProxyContract
			);
			delete codeFeeProxyInput;
			delete abiFeeProxyContract;
		} else {
			codeFeeProxy = codeFeeProxyInput;
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
		if (!codeEverduesAccount.toSlice().empty()) {
			account_version++;
			addNewContractVersion_(
				PlatformTypes.Account,
				account_version,
				codeEverduesAccount,
				abiEverduesAccountContractInput
			);
			delete codeEverduesAccount;
			delete abiEverduesAccountContract;
		} else {
			abiEverduesAccountContract = abiEverduesAccountContractInput;
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
		if (!codeService.toSlice().empty()) {
			service_version++;
			addNewContractVersion_(
				PlatformTypes.Service,
				service_version,
				codeService,
				abiServiceContractInput
			);
			delete codeService;
			delete abiServiceContract;
		} else {
			abiServiceContract = abiServiceContractInput;
		}
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
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
		if (!codeServiceIndex.toSlice().empty()) {
			addNewContractVersion_(
				PlatformTypes.ServiceIndex,
				1,
				codeServiceIndex,
				abiServiceIndexContractInput
			);
			delete abiServiceIndexContract;
			delete codeServiceIndex;
		} else {
			abiServiceIndexContract = abiServiceIndexContractInput;
		}
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
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
		if (!codeServiceIdentificatorIndex.toSlice().empty()) {
			addNewContractVersion_(
				PlatformTypes.ServiceIdentificatorIndex,
				1,
				codeServiceIdentificatorIndex,
				abiServiceIdentificatorIndexContractInput
			);
			delete abiServiceIdentificatorIndexContract;
			delete codeServiceIdentificatorIndex;
		} else {
			abiServiceIdentificatorIndexContract = abiServiceIdentificatorIndexContractInput;
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
		if (!codeSubscription.toSlice().empty()) {
			subscription_version++;
			addNewContractVersion_(
				PlatformTypes.Subscription,
				subscription_version,
				codeSubscription,
				abiSubscriptionContractInput
			);
			delete codeSubscription;
			delete abiSubscriptionContract;
		} else {
			abiSubscriptionContract = abiSubscriptionContractInput;
		}
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
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
		if (!codeSubscriptionIndex.toSlice().empty()) {
			addNewContractVersion_(
				PlatformTypes.SubscriptionIndex,
				1,
				codeSubscriptionIndex,
				abiSubscriptionIndexContractInput
			);
			delete codeSubscriptionIndex;
			delete abiSubscriptionIndexContract;
		} else {
			abiSubscriptionIndexContract = abiSubscriptionIndexContractInput;
		}
		owner.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
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
		if (!codeSubscriptionIdentificatorIndex.toSlice().empty()) {
			addNewContractVersion_(
				PlatformTypes.SubscriptionIdentificatorIndex,
				1,
				codeSubscriptionIdentificatorIndex,
				abiSubscriptionIdentificatorIndexContractInput
			);
			delete codeSubscriptionIdentificatorIndex;
			delete abiSubscriptionIdentificatorIndexContract;
		} else {
			abiSubscriptionIdentificatorIndexContract = abiSubscriptionIdentificatorIndexContractInput;
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
		if (!codeFeeProxy.toSlice().empty()) {
			fee_proxy_version++;
			addNewContractVersion_(
				PlatformTypes.FeeProxy,
				1,
				codeFeeProxy,
				abiFeeProxyContractInput
			);
			delete codeFeeProxy;
			delete abiFeeProxyContract;
		} else {
			abiFeeProxyContract = abiFeeProxyContractInput;
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
			mapping(uint32 => ContractVersionParams) versions_ = versions[
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

	function setDeployServiceLockValue(uint128 deploy_service_lock_value_)
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
		deploy_service_lock_value = deploy_service_lock_value_;
		msg.sender.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		});
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
		EverduesFeeProxy(fee_proxy_address).setAccountGasThreshold{
			value: 0,
			bounce: true,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(account_threshold, owner);
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
		TvmCell upgrade_data;
		EverduesRoot.ContractVersionParams latestVersion = versions[
			PlatformTypes.FeeProxy
		][1];
		EverduesFeeProxy(fee_proxy_address).upgrade{
			value: 0,
			bounce: true,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(
			latestVersion.contractCode,
			fee_proxy_version,
			msg.sender,
			upgrade_data
		);
	}

	function forceUpgradeAccount(address account_address)
		external
		view
		onlyOwner
	{
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		TvmCell update_data = abi.encode(wever_root, tip3_to_ever_address);
		EverduesRoot.ContractVersionParams latestVersion = versions[
			PlatformTypes.Account
		][account_version];
		EverduesAccount(account_address).upgrade{
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(latestVersion.contractCode, account_version, update_data);
	}

	function upgradeAccount(uint256 pubkey)
		external
		view
		onlyAccountContract(pubkey)
	{
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
		TvmCell update_data = abi.encode(dex_root_address, wever_root);
		require(
			msg.sender == account_address,
			EverduesErrors.error_message_sender_is_not_account_address
		);
		EverduesRoot.ContractVersionParams latestVersion = versions[
			PlatformTypes.Account
		][account_version];
		EverduesAccount(account_address).upgrade{
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(latestVersion.contractCode, account_version, update_data);
	}

	function upgradeSubscriptionPlan(
		address service_address,
		uint8 subscription_plan,
		uint256 owner_pubkey
	) external view onlyAccountContract(owner_pubkey) {
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
		Subscription(subscription_address).upgradeSubscriptionPlan{
			value: 0,
			bounce: true, // TODO: need to revert balance back to current msg.sender in case of failure
			flag: MsgFlag.ALL_NOT_RESERVED
		}(subscription_plan);
	}

	function upgradeSubscription(address service_address, uint256 owner_pubkey)
		external
		view
		onlyAccountContract(owner_pubkey)
	{
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
		TvmCell upgrade_data;
		Subscription(subscription_address).upgrade{
			value: 0,
			bounce: true, // TODO: need to revert balance back to current msg.sender in case of failure
			flag: MsgFlag.ALL_NOT_RESERVED
		}(
			subscription_code_salt,
			subscription_version,
			msg.sender,
			upgrade_data
		);
	}

	function forceUpgradeSubscription(
		address subscription_address,
		address subscription_owner
	) external view {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		TvmCell subscription_code_salt = _buildSubscriptionCode(
			subscription_owner
		);
		TvmCell upgrade_data;
		Subscription(subscription_address).upgrade{
			value: 0,
			bounce: true, // TODO: need to revert balance back to current msg.sender in case of failure
			flag: MsgFlag.ALL_NOT_RESERVED
		}(
			subscription_code_salt,
			subscription_version,
			address(this),
			upgrade_data
		);
	}

	function updateSubscriptionIdentificator(
		address service_address,
		TvmCell identificator,
		uint256 owner_pubkey
	) external view onlyAccountContract(owner_pubkey) {
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

	function upgradeService(
		string service_name,
		string category,
		bool publish_to_catalog,
		uint256 owner_pubkey
	) external view onlyAccountContract(owner_pubkey) {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		TvmCell service_code_salt;
		if (publish_to_catalog) {
			service_code_salt = _buildPublicServiceCode(category);
		} else {
			uint256 nonce = rnd.next();
			service_code_salt = _buildPrivateServiceCode(nonce);
		}
		address service_address = address(
			tvm.hash(
				_buildInitData(
					PlatformTypes.Service,
					_buildServicePlatformParams(msg.sender, service_name)
				)
			)
		);
		TvmCell upgrade_data;
		Service(service_address).upgrade{
			value: 0,
			bounce: true,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(service_code_salt, service_version, msg.sender, upgrade_data);
	}

	function forceUpgradeService(
		address service_address,
		string category,
		bool publish_to_catalog
	) external view {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		TvmCell service_code_salt;
		if (publish_to_catalog) {
			service_code_salt = _buildPublicServiceCode(category);
		} else {
			uint256 nonce = rnd.next();
			service_code_salt = _buildPrivateServiceCode(nonce);
		}
		TvmCell upgrade_data;
		Service(service_address).upgrade{
			value: 0,
			bounce: true,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(service_code_salt, service_version, address(this), upgrade_data);
	}

	function updateServiceParams(
		string service_name,
		TvmCell new_service_params,
		uint256 owner_pubkey
	) external view onlyAccountContract(owner_pubkey) {
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
		Service(service_address).updateServiceParams{
			value: 0,
			bounce: true,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(new_service_params);
	}

	function updateServiceIdentificator(
		string service_name,
		TvmCell identificator,
		uint256 owner_pubkey
	) external view onlyAccountContract(owner_pubkey) {
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
		Service(service_address).updateIdentificator{
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
			tip3_to_ever_address
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
			tip3_to_ever_address
		) = abi.decode(
			upgrade_data,
			(
				uint32,
				address,
				uint32,
				uint32,
				uint32,
				mapping(uint8 => mapping(uint32 => ContractVersionParams)),
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
				address
			)
		);
		owner.transfer({
			value: 0,
			bounce: false,
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
		EverduesRoot.ContractVersionParams latestVersion = versions[
			PlatformTypes.FeeProxy
		][1];
		Platform platform = new Platform{
			stateInit: _buildInitData(
				PlatformTypes.FeeProxy,
				_buildPlatformParamsOwnerAddress(address(this))
			),
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(
			latestVersion.contractCode,
			fee_proxy_contract_params,
			fee_proxy_version,
			msg.sender,
			0
		);
		fee_proxy_address = address(platform);
	}

	function cancelService(string service_name, uint256 owner_pubkey)
		external
		view
		onlyAccountContract(owner_pubkey)
	{
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
		IEverduesService(service_address).cancel{
			value: 0,
			bounce: true,
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

		TvmCell account_params = abi.encode(
			dex_root_address,
			wever_root,
			tip3_to_ever_address,
			account_threshold
		);
		EverduesRoot.ContractVersionParams latestVersion = versions[
			PlatformTypes.Account
		][account_version];
		IPlatform(msg.sender).initializeByRoot{
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(latestVersion.contractCode, account_params, account_version);
	}

	function deploySubscription(
		address service_address,
		TvmCell identificator,
		uint256 owner_pubkey,
		uint8 subscription_plan,
		uint128 additional_gas
	) external view onlyAccountContract(owner_pubkey) {
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
			owner_pubkey,
			subscription_plan
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
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}

	function deployService(
		TvmCell service_params_cell,
		TvmCell identificator,
		uint256 owner_pubkey,
		bool publish_to_catalog,
		uint128 additional_gas
	) external view onlyAccountContract(owner_pubkey) {
		require(
			msg.value >= deploy_service_lock_value,
			EverduesErrors.error_message_low_value
		);
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		(
			TvmCell service_params, /*TvmCell subscription_plans*/

		) = abi.decode(service_params_cell, (TvmCell, TvmCell));
		(
			,
			/*address account*/
			string service_name, /*string description*/ /*string image*/
			,
			,
			string category
		) = abi.decode(
				service_params,
				(address, string, string, string, string)
			);
		TvmCell service_code_salt;
		if (publish_to_catalog) {
			service_code_salt = _buildPublicServiceCode(category);
		} else {
			uint256 nonce = rnd.next();
			service_code_salt = _buildPrivateServiceCode(nonce);
		}
		TvmCell serviceIndexStateInit = _buildServiceIndex(
			msg.sender,
			service_name
		);
		TvmCell serviceIdentificatorIndexStateInit = _buildServiceIdentificatorIndex(
				msg.sender,
				identificator,
				address(
					tvm.hash(
						_buildInitData(
							PlatformTypes.Service,
							_buildServicePlatformParams(
								msg.sender,
								service_name
							)
						)
					)
				)
			);
		TvmCell additional_params = abi.encode(
			address(tvm.hash(serviceIndexStateInit)),
			address(tvm.hash(serviceIdentificatorIndexStateInit))
		);
		TvmCell service_params_cell_with_additional_params = abi.encode(
			service_params_cell,
			additional_params
		);
		Platform platform = new Platform{
			stateInit: _buildInitData(
				PlatformTypes.Service,
				_buildServicePlatformParams(msg.sender, service_name)
			),
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(
			service_code_salt,
			service_params_cell_with_additional_params,
			service_version,
			msg.sender,
			0
		);
		new ServiceIndex{
			value: EverduesGas.INDEX_INITIAL_BALANCE +
				EverduesGas.INIT_MESSAGE_VALUE +
				(additional_gas / 3),
			flag: MsgFlag.SENDER_PAYS_FEES,
			bounce: false,
			stateInit: serviceIndexStateInit
		}(address(platform));
		if (!identificator.toSlice().empty()) {
			new ServiceIdentificatorIndex{
				value: EverduesGas.INDEX_INITIAL_BALANCE +
					EverduesGas.INIT_MESSAGE_VALUE +
					(additional_gas / 3),
				flag: MsgFlag.SENDER_PAYS_FEES,
				bounce: false,
				stateInit: serviceIdentificatorIndexStateInit
			}();
		}
		msg.sender.transfer({
			value: 0,
			bounce: false,
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
		saltBuilder.store(subscription_owner, address(this));
		EverduesRoot.ContractVersionParams latestVersion = versions[
			PlatformTypes.Subscription
		][subscription_version];
		TvmCell code = tvm.setCodeSalt(
			latestVersion.contractCode,
			saltBuilder.toCell()
		);
		return code;
	}

	function _buildPublicServiceCode(string category)
		private
		view
		returns (TvmCell)
	{
		TvmBuilder saltBuilder;
		saltBuilder.store(category, address(this));
		EverduesRoot.ContractVersionParams latestVersion = versions[
			PlatformTypes.Service
		][service_version];
		TvmCell code = tvm.setCodeSalt(
			latestVersion.contractCode,
			saltBuilder.toCell()
		);
		return code;
	}

	function _buildPublicServiceCodeByVersion(string category, uint32 version_)
		private
		view
		returns (TvmCell)
	{
		TvmBuilder saltBuilder;
		saltBuilder.store(category, address(this));
		ContractVersionParams latestVersion = versions[PlatformTypes.Service][
			version_
		];
		TvmCell code = tvm.setCodeSalt(
			latestVersion.contractCode,
			saltBuilder.toCell()
		);
		return code;
	}

	function _buildPrivateServiceCode(uint256 nonce)
		private
		view
		returns (TvmCell)
	{
		TvmBuilder saltBuilder;
		saltBuilder.store(nonce, address(this));
		EverduesRoot.ContractVersionParams latestVersion = versions[
			PlatformTypes.Service
		][service_version];
		TvmCell code = tvm.setCodeSalt(
			latestVersion.contractCode,
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
		EverduesRoot.ContractVersionParams latestVersion = versions[
			PlatformTypes.SubscriptionIdentificatorIndex
		][1];
		TvmCell code = tvm.setCodeSalt(
			latestVersion.contractCode,
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
		EverduesRoot.ContractVersionParams latestVersion = versions[
			PlatformTypes.SubscriptionIndex
		][1];
		TvmCell code = tvm.setCodeSalt(
			latestVersion.contractCode,
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
		EverduesRoot.ContractVersionParams latestVersion = versions[
			PlatformTypes.ServiceIndex
		][1];
		TvmCell code = tvm.setCodeSalt(
			latestVersion.contractCode,
			saltBuilder.toCell()
		);
		TvmCell state = tvm.buildStateInit({
			code: code,
			pubkey: 0,
			varInit: {service_name: service_name},
			contr: ServiceIndex
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
		EverduesRoot.ContractVersionParams latestVersion = versions[
			PlatformTypes.ServiceIdentificatorIndex
		][1];
		TvmCell code = tvm.setCodeSalt(
			latestVersion.contractCode,
			saltBuilder.toCell()
		);
		TvmCell state = tvm.buildStateInit({
			code: code,
			pubkey: 0,
			varInit: {
				service_owner: serviceOwner,
				service_address: service_address
			},
			contr: ServiceIdentificatorIndex
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
				code: codePlatform
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
				code: codePlatform
			});
	}

	function addNewContractVersion_(
		uint8 contract_type,
		uint32 version,
		TvmCell contract_code,
		string contract_abi
	) private {
		mapping(uint32 => ContractVersionParams) contract_versions_ = versions[
			contract_type
		];
		ContractVersionParams new_version_params;
		new_version_params.contractCode = contract_code;
		new_version_params.contractAbi = contract_abi;
		contract_versions_[version] = new_version_params;
		versions[
			contract_type
		] = contract_versions_;
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
