pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/MetaduesRootErrors.sol";
import "libraries/PlatformTypes.sol";
import "./Platform.sol";
import "../contracts/SubscriptionIndex.sol";
import "../contracts/SubscriptionIdentificatorIndex.sol";
import "../contracts/SubscriptionServiceIndex.sol";
import "../contracts/MetaduesFeeProxy.sol";
import "../contracts/MetaduesAccount.sol";
import "../contracts/Subscription.sol";
import "../contracts/SubscriptionService.sol";
import "../contracts/SubscriptionServiceIdentificatorIndex.sol";

contract MetaduesRoot {
    uint8 public versionTvc;
    uint8 public versionAbi;
    string[] public categories;

    TvmCell tvcPlatform;
    TvmCell tvcMetaduesAccount;
    TvmCell tvcSubscriptionService;
    TvmCell tvcSubscription;
    TvmCell tvcSubscriptionServiceIndex;
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

    struct VersionsTvcParams {
        TvmCell tvcPlatform;
        TvmCell tvcMetaduesAccount;
        TvmCell tvcSubscriptionService;
        TvmCell tvcSubscription;
        TvmCell tvcSubscriptionServiceIndex;
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

    onBounce(TvmSlice slice) external {
        // revert change to initial msg.sender in case of failure during deploy
        // TODO check SubsMan balance after that
        uint32 functionId = slice.decode(uint32);
    }

    constructor() public {
        tvm.accept();
    }

    modifier onlyOwner() {
        tvm.accept();
        _;
    }

    // Get all latest TVCs
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

    // Set TVCs
    function setTvcPlatform(TvmCell tvcPlatformInput) public onlyOwner {
        require(!has_platform_code, 222);
        tvcPlatform = tvcPlatformInput;
        has_platform_code = true;
    }

    function setTvcMetaduesAccount(TvmCell tvcMetaduesAccountInput)
        public
        onlyOwner
    {
        tvcMetaduesAccount = tvcMetaduesAccountInput;
        account_version++;
    }

    function setTvcSubscriptionService(TvmCell tvcSubscriptionServiceInput)
        public
        onlyOwner
    {
        tvcSubscriptionService = tvcSubscriptionServiceInput;
        service_version++;
    }

    function setTvcSubscription(TvmCell tvcSubscriptionInput) public onlyOwner {
        tvcSubscription = tvcSubscriptionInput;
        subscription_version++;
    }

    function setTvcSubscriptionServiceIndex(
        TvmCell tvcSubscriptionServiceIndexInput
    ) public onlyOwner {
        tvcSubscriptionServiceIndex = tvcSubscriptionServiceIndexInput;
    }

    function setTvcSubscriptionIndex(TvmCell tvcSubscriptionIndexInput)
        public
        onlyOwner
    {
        tvcSubscriptionIndex = tvcSubscriptionIndexInput;
    }

    function setTvcSubscriptionIdentificatorIndex(
        TvmCell tvcSubscriptionIdentificatorIndexInput
    ) public onlyOwner {
        tvcSubscriptionIdentificatorIndex = tvcSubscriptionIdentificatorIndexInput;
    }

    function setTvcFeeProxy(TvmCell tvcFeeProxyInput) public onlyOwner {
        tvcFeeProxy = tvcFeeProxyInput;
        fee_proxy_version++;
    }

    function setTvc() public onlyOwner {
        versionTvc++;
        VersionsTvcParams params;
        params.tvcPlatform = tvcPlatform;
        params.tvcMetaduesAccount = tvcMetaduesAccount;
        params.tvcSubscriptionService = tvcSubscriptionService;
        params.tvcSubscription = tvcSubscription;
        params.tvcSubscriptionServiceIndex = tvcSubscriptionServiceIndex;
        params.tvcSubscriptionIndex = tvcSubscriptionIndex;
        params.tvcSubscriptionIdentificatorIndex = tvcSubscriptionIdentificatorIndex;
        params.tvcFeeProxy = tvcFeeProxy;
        vrsparamsTvc.add(versionTvc, params);
    }

    // Set ABIs

    function setAbiPlatformContract(string abiPlatformContractInput)
        public
        onlyOwner
    {
        abiPlatformContract = abiPlatformContractInput;
    }

    function setAbiMetaduesAccountContract(
        string abiMetaduesAccountContractInput
    ) public onlyOwner {
        abiMetaduesAccountContract = abiMetaduesAccountContractInput;
    }

    function setAbiMetaduesRootContract(string abiMetaduesRootContractInput)
        public
        onlyOwner
    {
        abiMetaduesRootContract = abiMetaduesRootContractInput;
    }

    function setAbiTIP3RootContract(string abiTIP3RootContractInput)
        public
        onlyOwner
    {
        abiTIP3RootContract = abiTIP3RootContractInput;
    }

    function setAbiTIP3TokenWalletContract(
        string abiTIP3TokenWalletContractInput
    ) public onlyOwner {
        abiTIP3TokenWalletContract = abiTIP3TokenWalletContractInput;
    }

    function setAbiServiceContract(string abiServiceContractInput)
        public
        onlyOwner
    {
        abiServiceContract = abiServiceContractInput;
    }

    function setAbiServiceIndexContract(string abiServiceIndexContractInput)
        public
        onlyOwner
    {
        abiServiceIndexContract = abiServiceIndexContractInput;
    }

    function setAbiSubscriptionContract(string abiSubscriptionContractInput)
        public
        onlyOwner
    {
        abiSubscriptionContract = abiSubscriptionContractInput;
    }

    function setAbiSubscriptionIndexContract(
        string abiSubscriptionIndexContractInput
    ) public onlyOwner {
        abiSubscriptionIndexContract = abiSubscriptionIndexContractInput;
    }

    function setAbiSubscriptionIdentificatorIndexContract(
        string abiSubscriptionIdentificatorIndexContractInput
    ) public onlyOwner {
        abiSubscriptionIdentificatorIndexContract = abiSubscriptionIdentificatorIndexContractInput;
    }

    function setAbiFeeProxyContract(string abiFeeProxyContractInput)
        public
        onlyOwner
    {
        abiFeeProxyContract = abiFeeProxyContractInput;
    }

    function setAbi() public onlyOwner {
        versionAbi++;
        VersionsAbiParams params;
        params.abiPlatformContract = abiPlatformContract;
        params.abiMetaduesAccountContract = abiMetaduesAccountContract;
        params.abiMetaduesRootContract = abiMetaduesRootContract;
        params.abiTIP3RootContract = abiTIP3RootContract;
        params.abiTIP3TokenWalletContract = abiTIP3TokenWalletContract;
        params.abiServiceContract = abiServiceContract;
        params.abiServiceIndexContract = abiServiceIndexContract;
        params.abiSubscriptionContract = abiSubscriptionContract;
        params.abiSubscriptionIndexContract = abiSubscriptionIndexContract;
        params
            .abiSubscriptionIdentificatorIndexContract = abiSubscriptionIdentificatorIndexContract;
        params.abiFeeProxyContract = abiFeeProxyContract;
        vrsparamsAbi.add(versionAbi, params);
    }

    function setCategories(string[] categoriesInput) public onlyOwner {
        categories = categoriesInput;
    }

    function installOrUpdateFeeProxyParams(address[] currencies)
        external
        onlyOwner
    {
        require(fee_proxy_address != address(0), 555);
        TvmBuilder currencies_cell;
        currencies_cell.store(currencies);
        TvmCell fee_proxy_contract_params = currencies_cell.toCell();
        MetaduesFeeProxy(fee_proxy_address).setSupportedCurrencies(
            fee_proxy_contract_params
        );
    }

    function installOrUpgradeMTDSRootAddress(address mtds_root_)
        external
        onlyOwner
    {
        require(fee_proxy_address != address(0), 555);
        mtds_root_address = mtds_root_;
        MetaduesFeeProxy(fee_proxy_address).setMTDSRootAddress(
            mtds_root_address
        );
    }

    function installOrUpgradeDexRootAddress(address dex_root)
        external
        onlyOwner
    {
        require(fee_proxy_address != address(0), 555);
        dex_root_address = dex_root;
        MetaduesFeeProxy(fee_proxy_address).setDexRootAddress(dex_root_address);
    }

    function installOrUpgradeMTDSRevenueDelegationAddress(address revenue_to)
        external
        onlyOwner
    {
        mtds_revenue_accumulator_address = revenue_to;
    }

    function setFees(uint8 service_fee_, uint8 subscription_fee_)
        external
        onlyOwner
    {
        service_fee = service_fee_;
        subscription_fee = subscription_fee_;
    }

    // Managment
    function transferRevenueFromFeeProxy() external view onlyOwner {
        require(fee_proxy_address != address(0), 555);
        MetaduesFeeProxy(fee_proxy_address).transferRevenue{
            value: 1 ton,
            bounce: false,
            flag: 0
        }(mtds_revenue_accumulator_address);
    }

    function swapRevenue(address currency_root) external view onlyOwner {
        require(fee_proxy_address != address(0), 555);
        MetaduesFeeProxy(fee_proxy_address).swapRevenueToMTDS(currency_root);
    }

    function syncFeeProxyBalance(address currency_root)
        external
        view
        onlyOwner
    {
        require(fee_proxy_address != address(0), 555);
        MetaduesFeeProxy(fee_proxy_address).syncBalance{
            value: 1 ton,
            bounce: false,
            flag: 0
        }(currency_root);
    }

    // Upgrade contracts
    function upgradeFeeProxy() external view onlyOwner {
        require(fee_proxy_address != address(0), 555);
        MetaduesFeeProxy(fee_proxy_address).upgrade{
            value: 1 ton,
            bounce: false,
            flag: 0
        }(tvcFeeProxy.toSlice().loadRef(), fee_proxy_version, msg.sender);
    }

    function upgradeAccount() external view onlyOwner {
        require(
            msg.sender != address(0),
            MetaduesRootErrors.error_message_sender_address_not_specified
        );
        address account_address = address(
            tvm.hash(
                _buildInitData(
                    PlatformTypes.Account,
                    _buildPlatformParams(msg.sender)
                )
            )
        );
        MetaduesAccount(account_address).upgrade{
            value: 1 ton,
            bounce: false,
            flag: 0
        }(tvcMetaduesAccount.toSlice().loadRef(), account_version, msg.sender);
    }

    function upgradeSubscription(address service_address, TvmCell identificator)
        public
        view
    {
        require(
            msg.sender != address(0),
            MetaduesRootErrors.error_message_sender_address_not_specified
        );
        require(service_address != address(0), 556);
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
            value: 1 ton,
            bounce: false,
            flag: 0
        }(subscription_code_salt, subscription_version, msg.sender);
    }

    function upgradeService(string service_name, string category) public view {
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
            value: 1 ton,
            bounce: false,
            flag: 0
        }(service_code_salt, service_version, msg.sender);
    }

    // Deploy contracts
    function deployFeeProxy(address[] currencies) external onlyOwner {
        TvmBuilder currencies_cell;
        currencies_cell.store(currencies);
        TvmCell fee_proxy_contract_params = currencies_cell.toCell();
        Platform platform = new Platform{
            stateInit: _buildInitData(
                PlatformTypes.FeeProxy,
                _buildPlatformParams(address(this))
            ),
            value: 1 ton,
            flag: 0
        }();
        platform.initialize{value: 1 ton, flag: 0}(
            tvcFeeProxy.toSlice().loadRef(),
            fee_proxy_contract_params,
            fee_proxy_version,
            msg.sender
        );
        fee_proxy_address = address(platform);
    }

    function deployAccount() external {
        //require(msg.sender != address(0), MetaduesRootErrors.error_message_sender_address_not_specified);
        TvmCell account_params;
        Platform platform = new Platform{
            stateInit: _buildInitData(
                PlatformTypes.Account,
                _buildPlatformParams(msg.sender)
            ),
            value: 1 ton,
            flag: 0
        }();
        platform.initialize{value: 1 ton, flag: 0}(
            tvcMetaduesAccount.toSlice().loadRef(),
            account_params,
            account_version,
            msg.sender
        );
    }

    function deploySubscription(address service_address, TvmCell identificator)
        public
        view
    {
        //require(msg.sender != address(0), MetaduesRootErrors.error_message_sender_address_not_specified);
        require(fee_proxy_address != address(0), 555);
        tvm.accept();
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
            tvm.hash(
                _buildInitData(
                    PlatformTypes.Account,
                    _buildPlatformParams(msg.sender)
                )
            )
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

        // service_params.store(owner_account_address);
        Platform platform = new Platform{
            stateInit: _buildInitData(
                PlatformTypes.Subscription,
                _buildSubscriptionPlatformParams(msg.sender, service_address)
            ),
            value: 1 ton,
            flag: 0
        }();
        platform.initialize{value: 1 ton, flag: 0}(
            subscription_code_salt,
            service_params.toCell(),
            subscription_version,
            msg.sender
        );

        new SubscriptionIndex{
            value: 0.02 ton,
            flag: 0,
            bounce: true,
            stateInit: subsIndexStateInit
        }(address(platform));

        new SubscriptionIdentificatorIndex{
            value: 0.02 ton,
            flag: 0,
            bounce: true,
            stateInit: subsIndexIdentificatorStateInit
        }(address(platform));
    }

    function deployService(TvmCell service_params, TvmCell identificator)
        public
        view
    {
        //require(msg.sender != address(0), MetaduesRootErrors.error_message_sender_address_not_specified);
        tvm.accept();
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
            value: 1 ton,
            flag: 0
        }();
        TvmCell serviceIndexStateInit = _buildServiceIndex(
            msg.sender,
            service_name
        );
        TvmCell serviceIdentificatorIndexStateInit = _buildServiceIdentificatorIndex(
                msg.sender,
                identificator
            );
        platform.initialize{value: 1 ton, flag: 0}(
            service_code_salt,
            service_params,
            service_version,
            msg.sender
        );
        SubscriptionService(address(platform)).setIndexes{
            value: 0.11 ton,
            flag: 0
        }(
            address(tvm.hash(serviceIndexStateInit)),
            address(tvm.hash(serviceIdentificatorIndexStateInit))
        );
        new SubscriptionServiceIndex{
            value: 1 ton,
            flag: 1,
            bounce: true,
            stateInit: serviceIndexStateInit
        }(address(platform));
        new SubscriptionServiceIdentificatorIndex{
            value: 1 ton,
            flag: 1,
            bounce: true,
            stateInit: serviceIdentificatorIndexStateInit
        }(address(platform));
    }

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
            varInit: {subscription_owner:subscription_owner},
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
            varInit: {subscription_owner:subscription_owner},
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
            varInit: {service_name:service_name},
            contr: SubscriptionServiceIndex
        });
        return state;
    }

    function _buildServiceIdentificatorIndex(
        address serviceOwner,
        TvmCell identificator_
    ) private view returns (TvmCell) {
        TvmBuilder saltBuilder;
        saltBuilder.store(identificator_, address(this));
        TvmCell code = tvm.setCodeSalt(
            tvcSubscriptionServiceIndex.toSlice().loadRef(),
            saltBuilder.toCell()
        );
        TvmCell state = tvm.buildStateInit({
            code: code,
            pubkey: 0,
            varInit: {service_owner:serviceOwner},
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
                varInit: {root:address(this),type_id:type_id,platform_params:params},
                pubkey: 0,
                code: tvcPlatform.toSlice().loadRef()
            });
    }

    function _buildPlatformParams(address account_owner)
        private
        inline
        pure
        returns (TvmCell)
    {
        TvmBuilder builder;
        builder.store(account_owner);
        return builder.toCell();
    }

    function accountOf(address owner_address_)
        public
        view
        returns (address account)
    {
        account = address(
            tvm.hash(
                _buildInitData(
                    PlatformTypes.Account,
                    _buildPlatformParams(owner_address_)
                )
            )
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

    function upgrade(TvmCell code, address send_gas_to) external onlyOwner {
        TvmBuilder builder;
        TvmBuilder upgrade_params;
        builder.store(account_version);
        builder.store(send_gas_to);
        builder.store(service_version);
        builder.store(fee_proxy_version);
        builder.store(subscription_version);
        tvm.setcode(code);
        tvm.setCurrentCode(code);
        onCodeUpgrade(builder.toCell());
    }

    function onCodeUpgrade(TvmCell upgrade_data) private {}
}
