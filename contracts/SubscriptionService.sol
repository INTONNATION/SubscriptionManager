pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/SubscriptionServiceErrors.sol";

interface ISubscriptionServiceIndexContract {
    function cancel() external;
}

interface IServiceIdentificatorIndexContract {
    function upgrade(TvmCell code, address send_gas_to) external;
}

contract SubscriptionService {
    struct ServiceParams {
        address to;
        uint128 value;
        uint32 period;
        string name;
        string description;
        string image;
        address currency_root;
        string category;
    }
    address public root;
    address public service_owner;
    address public subscription_service_index_address;
    address public subscription_service_index_identificator_address;
    TvmCell platform_code;
    TvmCell platform_params;
    TvmCell code;
    uint32 current_version;
    uint8 type_id;
    TvmCell public service_params;
    uint8 public status = 0;

    ServiceParams public svcparams;

    constructor() public {
        revert();
    }

    modifier onlyOwner() {
        // require service_owner
        tvm.accept();
        _;
    }

    function getParams() external view responsible returns (TvmCell) {
        return{value: 0, flag: 128} service_params;
    }

    function getInfo() external view responsible returns (TvmCell) {
        TvmBuilder info;
        info.store(status);
        return{value: 0, flag: 128} info.toCell();
    }

    modifier onlyRoot() {
        require(msg.sender == root, 111);
        _;
    }

    function pause() public onlyOwner {
        status = 1;
    }

    function resume() public onlyOwner {
        status = 0;
    }

    function upgrade(
        TvmCell code,
        uint32 version,
        address send_gas_to
    ) external onlyRoot {
        TvmBuilder builder;
        TvmBuilder upgrade_params;
        builder.store(root);
        builder.store(send_gas_to);
        builder.store(current_version);
        builder.store(version);
        builder.store(type_id);
        builder.store(platform_code);
        builder.store(platform_params);
        builder.store(service_params);
        builder.store(code);
        tvm.setcode(code);
        tvm.setCurrentCode(code);
        onCodeUpgrade(builder.toCell());
    }

    function onCodeUpgrade(TvmCell upgrade_data) private {
        TvmSlice s = upgrade_data.toSlice();
        (
            address root_,
            address send_gas_to,
            uint32 old_version,
            uint32 version,
            uint8 type_id_
        ) = s.decode(address, address, uint32, uint32, uint8);

        if (old_version == 0) {
            tvm.resetStorage();
        }

        root = root_;
        current_version = version;
        type_id = type_id_;
        TvmCell nextCell;
        platform_code = s.loadRef();
        platform_params = s.loadRef();
        (service_owner, svcparams.name) = platform_params.toSlice().decode(
            address,
            string
        );
        service_params = s.loadRef();
        (
            svcparams.to,
            svcparams.value,
            svcparams.period,
            nextCell
        ) = service_params.toSlice().decode(address, uint128, uint32, TvmCell);
        TvmCell nextCell2;
        (, svcparams.description, svcparams.image, nextCell2) = nextCell
            .toSlice()
            .decode(string, string, string, TvmCell);
        (svcparams.currency_root, svcparams.category) = nextCell2
            .toSlice()
            .decode(address, string);
    }

    function setIndexes(
        address subscription_service_index_address_,
        address subscription_service_index_identificator_address_
    ) external onlyRoot {
        subscription_service_index_address = subscription_service_index_address_;
        subscription_service_index_identificator_address = subscription_service_index_identificator_address_;
    }

    function updateServiceParams(TvmCell new_service_params) public onlyOwner {
        TvmCell nextCell;
        (
            svcparams.to,
            svcparams.value,
            svcparams.period,
            nextCell
        ) = new_service_params.toSlice().decode(
            address,
            uint128,
            uint32,
            TvmCell
        );
        TvmCell nextCell2;
        (, svcparams.description, svcparams.image, nextCell2) = nextCell
            .toSlice()
            .decode(string, string, string, TvmCell);
        (svcparams.currency_root, svcparams.category) = nextCell2
            .toSlice()
            .decode(address, string);
        service_params = new_service_params;
    }

    function cancel() public onlyOwner {
        ISubscriptionServiceIndexContract(subscription_service_index_address)
            .cancel();
        ISubscriptionServiceIndexContract(
            subscription_service_index_identificator_address
        ).cancel();
        selfdestruct(service_owner);
    }

    function upgradeIdentificatorIndex(TvmCell code, address send_gas_to)
        public
        onlyOwner
    {
        IServiceIdentificatorIndexContract(
            subscription_service_index_identificator_address
        ).upgrade(code, send_gas_to);
    }
}
