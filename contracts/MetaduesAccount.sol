pragma ton-solidity >=0.56.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "libraries/MetaduesRootErrors.sol";
import "libraries/PlatformTypes.sol";
import "libraries/MetaduesGas.sol";
import "libraries/MsgFlag.sol";
import "./Platform.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenWallet.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenRoot.sol";
import "../ton-eth-bridge-token-contracts/contracts/interfaces/TIP3TokenWallet.sol";

contract MetaduesAccount {
    mapping(address => balance_wallet_struct) public wallets_mapping;
    address public root;
    TvmCell platform_code;
    TvmCell platform_params;
    uint32 current_version;
    uint8 type_id;
    address account_owner;
    uint128 public withdraw_value;
    address public sync_balance_currency_root;
    address owner;

    constructor() public {
        revert();
    }

    struct balance_wallet_struct {
        address wallet;
        uint128 balance;
    }

    modifier onlyRoot() {
        require(msg.sender == root, 111);
        _;
    }

    modifier onlyOwner() {
        //account_owner
        tvm.accept();
        _;
    }

    event Deposit(address walletAddress, uint128 amount);
    event Withdraw(address walletAddress, uint128 amount);

    function upgrade(
        TvmCell code,
        uint32 version,
        address send_gas_to
    ) external onlyRoot {
        tvm.rawReserve(MetaduesGas.ACCOUNT_INITIAL_BALANCE, 2);

        TvmBuilder builder;
        TvmBuilder upgrade_params;
        builder.store(root);
        builder.store(send_gas_to);
        builder.store(current_version);
        builder.store(version);
        builder.store(type_id);
        builder.store(platform_code);
        builder.store(platform_params);
        builder.store(code);
        upgrade_params.store(wallets_mapping);
        builder.store(upgrade_params.toCell());
        tvm.setcode(code);
        tvm.setCurrentCode(code);
        onCodeUpgrade(builder.toCell());
    }

    function onCodeUpgrade(TvmCell upgrade_data) private {
        tvm.rawReserve(MetaduesGas.ACCOUNT_INITIAL_BALANCE, 2);
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
        platform_code = s.loadRef();
        platform_params = s.loadRef();
        current_version = version;
        type_id = type_id_;
        account_owner = platform_params.toSlice().decode(address);

        send_gas_to.transfer({ value: 0, flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS });
    }

    function paySubscription(
        uint128 value,
        address currency_root,
        address account_wallet,
        address subscription_wallet,
        address service_address
    ) external responsible returns (uint8) {
        tvm.rawReserve(MetaduesGas.ACCOUNT_INITIAL_BALANCE, 0);
        // require > MetaduesGas.TRANSFER_MIN_VALUE + something
        address subsciption_addr = address(
            tvm.hash(
                _buildInitData(
                    PlatformTypes.Subscription,
                    _buildSubscriptionParams(account_owner, service_address)
                )
            )
        );
        //        require(subsciption_addr == msg.sender, 333);
        TvmCell payload;
        optional(balance_wallet_struct) current_balance_struct = wallets_mapping
            .fetch(currency_root);

        if (current_balance_struct.hasValue()) {
            balance_wallet_struct current_balance_key_value = current_balance_struct
                    .get();
            uint128 current_balance = current_balance_key_value.balance;
            if (value >= current_balance) {
                return{value: 0, flag: MsgFlag.REMAINING_GAS} 1;
            } else {
                ITokenWallet(account_wallet).transferToWallet{
                    value: MetaduesGas.TRANSFER_MIN_VALUE,
                    bounce: false,
                    flag: MsgFlag.SENDER_PAYS_FEES
                }(
                    value,
                    subscription_wallet,
                    msg.sender,
                    true,
                    payload
                );
                uint128 balance_after_pay = current_balance - value;
                current_balance_key_value.balance = balance_after_pay;
                wallets_mapping[currency_root] = current_balance_key_value;
                return{value: 0, flag: MsgFlag.REMAINING_GAS} 0;
            }
        } else {
            return{value: 0, flag: MsgFlag.REMAINING_GAS} 1;
        }
    }

    function syncBalance(address currency_root) external onlyOwner {
        require(sync_balance_currency_root == address(0), 335);
        tvm.rawReserve(MetaduesGas.ACCOUNT_INITIAL_BALANCE, 0);
        sync_balance_currency_root = currency_root;
        optional(balance_wallet_struct) current_balance_struct = wallets_mapping
            .fetch(currency_root);
        balance_wallet_struct current_balance_key = current_balance_struct
            .get();
        address account_wallet = current_balance_key.wallet;
        TIP3TokenWallet(account_wallet).balance{
            value: 0,
            bounce: false,
            flag: MsgFlag.REMAINING_GAS,
            callback: MetaduesAccount.onBalanceOf
        }();
    }

    function onBalanceOf(uint128 balance_) external {
        tvm.rawReserve(MetaduesGas.ACCOUNT_INITIAL_BALANCE, 0);
        uint128 balance_wallet = balance_;
        optional(balance_wallet_struct) current_balance_struct = wallets_mapping
            .fetch(sync_balance_currency_root);
        balance_wallet_struct current_balance_key = current_balance_struct
            .get();
        current_balance_key.balance = balance_wallet;
        wallets_mapping[sync_balance_currency_root] = current_balance_key;
        sync_balance_currency_root = address(0);
        account_owner.transfer({ value: 0, flag: MsgFlag.REMAINING_GAS });
    }

    function withdrawFunds(address currency_root, uint128 withdraw_value_)
        external
        onlyOwner
    {
        tvm.rawReserve(
            math.max(
                MetaduesGas.ACCOUNT_INITIAL_BALANCE,
                address(this).balance - msg.value
            ),
            2
        );
        optional(balance_wallet_struct) current_balance_struct = wallets_mapping
            .fetch(currency_root);
        balance_wallet_struct current_balance_key = current_balance_struct
            .get();
        address account_wallet = current_balance_key.wallet;
        TvmCell payload;
        current_balance_key.balance =
            current_balance_key.balance -
            withdraw_value_;
        wallets_mapping[currency_root] = current_balance_key;
        emit Withdraw(msg.sender, withdraw_value_);
        ITokenWallet(account_wallet).transfer{
            value: 0,
            bounce: false,
            flag: MsgFlag.REMAINING_GAS
        }(
            withdraw_value_,
            account_owner,
            0,
            account_owner,
            true,
            payload
        );
    }

    function destroyAccount() public onlyOwner {
        selfdestruct(account_owner);
    }

    function onAcceptTokensTransfer(
        address tokenRoot,
        uint128 amount,
        address sender,
        address senderWallet,
        address remainingGasTo,
        TvmCell payload
    ) external {
        tvm.rawReserve(MetaduesGas.ACCOUNT_INITIAL_BALANCE, 0);
        optional(balance_wallet_struct) current_balance_struct = wallets_mapping
            .fetch(tokenRoot);
        if (current_balance_struct.hasValue()) {
            balance_wallet_struct current_balance_key = current_balance_struct
                .get();
            current_balance_key.balance += amount;
            wallets_mapping[tokenRoot] = current_balance_key;
        } else {
            balance_wallet_struct current_balance_struct;
            current_balance_struct.wallet = msg.sender;
            current_balance_struct.balance = amount;
            wallets_mapping[tokenRoot] = current_balance_struct;
        }
        emit Deposit(msg.sender, amount);
        remainingGasTo.transfer({ value: 0, flag: MsgFlag.REMAINING_GAS + MsgFlag.IGNORE_ERRORS });

    }

    function _buildSubscriptionParams(
        address subscription_owner,
        address service_address
    ) private inline pure returns (TvmCell) {
        TvmBuilder builder;
        builder.store(subscription_owner);
        builder.store(service_address);
        return builder.toCell();
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
                code: platform_code
            });
    }

    function getOwner() external view responsible returns (address wner) {
        return account_owner;
    }
}
