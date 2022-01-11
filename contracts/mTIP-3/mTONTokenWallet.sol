pragma ton-solidity >= 0.39.0;
pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "../interfaces/IDestroyable.sol";
import "../interfaces/ITONTokenWallet.sol";
import "../interfaces/IBurnableByOwnerTokenWallet.sol";
import "../interfaces/IBurnableByRootTokenWallet.sol";
import "../interfaces/IBurnableTokenRootContract.sol";
import "../interfaces/ITokenWalletDeployedCallback.sol";
import "../interfaces/ITokensReceivedCallback.sol";
import "../interfaces/ITokensBouncedCallback.sol";
import "../libraries/TONTokenWalletErrors.sol";
import "../libraries/TONTokenWalletConstants.sol";
import "../interfaces/IVersioned.sol";
import "../Subscription.sol";


struct fees {
    uint128 serviceFee;
    uint128 subscriberFee;
    uint128 serviceRegistrationFee;
}  

interface ISubscription {
    function onPaySubscription(uint8 status) external;
}

interface ITONTokenWalletConfigVersions {
    function getFees(address recipient, uint128 value, address subsAddr) external responsible returns(fees, address, uint128, address);
}

/*
    @title FT token wallet contract
*/
contract TONTokenWallet is ITONTokenWallet, IDestroyable, IBurnableByOwnerTokenWallet, IBurnableByRootTokenWallet, IVersioned {

    address static root_address;
    address static owner_address;
    TvmCell static code;
    uint256 static wallet_public_key;
    uint128 balance_;
    optional(AllowanceInfo) allowance_;
    address receive_callback;
    address bounced_callback;
    bool allow_non_notifiable;
    address public subsmanAddr;
    address public configVersionsAddr;
    uint8 public subscr_ver = 0;
    uint128 public serviceFee;
    uint128 public subscriberFee;
    mapping (uint8 => TvmCell) public subscr_images;

    /*
        @notice Creates new token wallet
        @dev All the parameters are specified as initial data
        @dev If owner_address is not empty, it will be notified with .notifyWalletDeployed
    */
    constructor(TvmCell subsImage, address subsmanAddrINPUT, address configVersionsAddrINPUT) public {
        require(wallet_public_key == tvm.pubkey() && (owner_address.value == 0 || wallet_public_key == 0));
        tvm.accept();

        allow_non_notifiable = true;

        if (owner_address.value != 0) {
            ITokenWalletDeployedCallback(owner_address).notifyWalletDeployed{value: 0.00001 ton, flag: 1}(root_address);
        }
        subscr_images.add(subscr_ver, subsImage);
        configVersionsAddr = configVersionsAddrINPUT;
        subsmanAddr = subsmanAddrINPUT;
    }

    function getVersion() override external pure responsible returns (uint32) {
        return 4;
    }

    function balance() override external view responsible returns (uint128) {
        return { value: 0, bounce: false, flag: 64 } balance_;
    }

    /*
        @notice Get details about token wallet
        @returns root_address Token root address
        @returns wallet_public_key Token wallet owner public key
        @returns owner_address Token wallet owner address
        @returns balance Token wallet balance in tokens
        @returns receive_callback Receive callback contract
        @returns bounced_callback Bounce callback contract
        @return allow_non_notifiable Wallet receive transfers without notify_receiver
    */
    function getDetails() override external view responsible returns (ITONTokenWalletDetails) {
        return { value: 0, bounce: false, flag: 64 } ITONTokenWalletDetails(
            root_address,
            wallet_public_key,
            owner_address,
            balance_,
            receive_callback,
            bounced_callback,
            allow_non_notifiable
        );
    }

    /*
        @returns code Token wallet code
    */
    function getWalletCode() override external view responsible returns (TvmCell) {
        return { value: 0, bounce: false, flag: 64 } code;
    }

    function setSubscriptionImage(TvmCell image) public onlyOwner {
        subscr_ver++;
        subscr_images.add(subscr_ver, image);
    }

/*
    @notice Accept minted tokens from root
    @dev Can be called only by root token
    @param tokens How much tokens to accept
*/
    function accept(
        uint128 tokens
    )
        override
        external
        onlyRoot
    {
        tvm.accept();
        balance_ += tokens;
    }

    function allowance() override external view responsible returns (AllowanceInfo) {
        return { value: 0, bounce: false, flag: 64 } (allowance_.hasValue() ? allowance_.get() : AllowanceInfo(0, address.makeAddrStd(0, 0)));
    }

    /*
        @notice Approve another token to spent current token wallet's tokens
        @dev Can be called only by owner
        @dev No multi-allowance is allowed - only one sender and amount
        @param spender Tokens spender address
        @param remaining_tokens Required current tokens balance
        @param tokens How much tokens to spend
    */
    function approve(
        address spender,
        uint128 remaining_tokens,
        uint128 tokens
    )
        override
        external
        onlyOwner
    {
        require(remaining_tokens == 0 || !allowance_.hasValue(), TONTokenWalletErrors.error_non_zero_remaining);
        if (owner_address.value != 0 ) {
            tvm.rawReserve(math.max(TONTokenWalletConstants.target_gas_balance, address(this).balance - msg.value), 2);
        } else {
            tvm.accept();
        }

        if (allowance_.hasValue()) {
            if (allowance_.get().remaining_tokens == remaining_tokens) {
                allowance_.set(AllowanceInfo(tokens, spender));
            }
        } else {
            allowance_.set(AllowanceInfo(tokens, spender));
        }

        if (owner_address.value != 0 ) {
            msg.sender.transfer({ value: 0, flag: 128 });
        }
    }

    function disapprove() override external onlyOwner {
        if (owner_address.value != 0 ) {
            tvm.rawReserve(math.max(TONTokenWalletConstants.target_gas_balance, address(this).balance - msg.value), 2);
        } else {
            tvm.accept();
        }

        allowance_.reset();

        if (owner_address.value != 0 ) {
            msg.sender.transfer({ value: 0, flag: 128 });
        }
    }

    /*
        @notice Transfer tokens and deploy token wallet for receiver
        @dev Can be called only by token wallet owner
        @dev Works fine with 2 * 0.05 TON + deploy_grams
        @dev transfer_grams ignored in case of internal message
        @dev If deploy_grams=0 works as regular transfer
        @param recipient_public_key Token wallet receiver owner public key
        @param recipient_address Token wallet receiver owner address
        @param tokens How much tokens to transfer
        @param deploy_grams How much TONs to attach to token wallet deploy
        @param transfer_grams How much TONs to attach to transfer
        @param send_gas_to Remaining TONs receiver
        @param notify_receiver Notify receiver on incoming transfer
        @param payload Notification payload
    */
    function transferToRecipient(
        uint256 recipient_public_key,
        address recipient_address,
        uint128 tokens,
        uint128 deploy_grams,
        uint128 transfer_grams,
        address send_gas_to,
        bool notify_receiver,
        TvmCell payload
    ) override external onlyOwner {
        require(tokens > 0);
        require(tokens <= balance_, TONTokenWalletErrors.error_not_enough_balance);
        require(recipient_address.value == 0 || recipient_public_key == 0, TONTokenWalletErrors.error_wrong_recipient);

        if (owner_address.value != 0 ) {
            uint128 reserve = math.max(TONTokenWalletConstants.target_gas_balance, address(this).balance - msg.value);
            require(address(this).balance > reserve + TONTokenWalletConstants.target_gas_balance + deploy_grams, TONTokenWalletErrors.error_low_message_value);
            require(recipient_address != owner_address, TONTokenWalletErrors.error_wrong_recipient);
            tvm.rawReserve(reserve, 2);
        } else {
            require(address(this).balance > deploy_grams + transfer_grams, TONTokenWalletErrors.error_low_message_value);
            require(transfer_grams > TONTokenWalletConstants.target_gas_balance, TONTokenWalletErrors.error_low_message_value);
            require(recipient_public_key != wallet_public_key);
            tvm.accept();
        }

        TvmCell stateInit = tvm.buildStateInit({
            contr: TONTokenWallet,
            varInit: {
                root_address: root_address,
                code: code,
                wallet_public_key: recipient_public_key,
                owner_address: recipient_address
            },
            pubkey: recipient_public_key,
            code: code
        });

        address to;

        if(deploy_grams > 0) {
            to = new TONTokenWallet{
                stateInit: stateInit,
                value: deploy_grams,
                wid: address(this).wid,
                flag: 1
            }(subscr_images[subscr_ver], subsmanAddr, configVersionsAddr);
            
        } else {
            to = address(tvm.hash(stateInit));
        }

        if (owner_address.value != 0 ) {
            balance_ -= tokens;
            ITONTokenWallet(to).internalTransfer{ value: 0, flag: 129, bounce: true }(
                tokens,
                wallet_public_key,
                owner_address,
                send_gas_to.value != 0 ? send_gas_to : owner_address,
                notify_receiver,
                payload
            );
        } else {
            balance_ -= tokens;
            ITONTokenWallet(to).internalTransfer{ value: transfer_grams, flag: 1, bounce: true }(
                tokens,
                wallet_public_key,
                owner_address,
                send_gas_to.value != 0 ? send_gas_to : address(this),
                notify_receiver,
                payload
            );
        }
    }

    /*
        @notice Transfer tokens to another token wallet contract
        @dev Can be called only by token wallet owner
        @dev grams ignored in case of internal message
        @param to Tokens receiver token wallet
        @param tokens How much tokens to transfer
        @param grams How much TONs to attach
        @param send_gas_to Remaining TONs receiver
        @param notify_receiver Notify receiver on incoming transfer
        @param payload Notification payload
    */
    function transferInline(
        address to,
        uint128 tokens,
        uint128 grams,
        address send_gas_to,
        bool notify_receiver,
        TvmCell payload
    ) private inline {
        require(tokens > 0);
        require(tokens <= balance_, TONTokenWalletErrors.error_not_enough_balance);
        require(to.value != 0, TONTokenWalletErrors.error_wrong_recipient);
        require(to != address(this), TONTokenWalletErrors.error_wrong_recipient);

        if (owner_address.value != 0 ) {
            uint128 reserve = math.max(TONTokenWalletConstants.target_gas_balance, address(this).balance - msg.value);
            require(address(this).balance > reserve + TONTokenWalletConstants.target_gas_balance, TONTokenWalletErrors.error_low_message_value);
            tvm.rawReserve(reserve, 2);
            balance_ -= tokens;

            Subscription(msg.sender).onPaySubscription(0); // TODO Move callback when we totally sure that subscription was paid
            
            ITONTokenWallet(to).internalTransfer{ value: 0, flag: 129, bounce: true }(
                tokens,
                wallet_public_key,
                owner_address,
                send_gas_to.value != 0 ? send_gas_to : owner_address,
                notify_receiver,
                payload
            );
        } else {
            require(address(this).balance > grams, TONTokenWalletErrors.error_low_message_value);
            require(grams > TONTokenWalletConstants.target_gas_balance, TONTokenWalletErrors.error_low_message_value);
            tvm.accept();
            balance_ -= tokens;

            ITONTokenWallet(to).internalTransfer{ value: grams, bounce: true, flag: 1 }(
                tokens,
                wallet_public_key,
                owner_address,
                send_gas_to.value != 0 ? send_gas_to : address(this),
                notify_receiver,
                payload
            );
        }
    }

    /*
        @notice Transfer tokens to another token wallet contract
        @dev Can be called only by token wallet owner
        @dev grams ignored in case of internal message
        @param to Tokens receiver token wallet
        @param tokens How much tokens to transfer
        @param grams How much TONs to attach
        @param send_gas_to Remaining TONs receiver
        @param notify_receiver Notify receiver on incoming transfer
        @param payload Notification payload
    */
    function transfer(
        address to,
        uint128 tokens,
        uint128 grams,
        address send_gas_to,
        bool notify_receiver,
        TvmCell payload
    ) override external onlyOwner {
        require(tokens > 0);
        require(tokens <= balance_, TONTokenWalletErrors.error_not_enough_balance);
        require(to.value != 0, TONTokenWalletErrors.error_wrong_recipient);
        require(to != address(this), TONTokenWalletErrors.error_wrong_recipient);

        if (owner_address.value != 0 ) {
            uint128 reserve = math.max(TONTokenWalletConstants.target_gas_balance, address(this).balance - msg.value);
            require(address(this).balance > reserve + TONTokenWalletConstants.target_gas_balance, TONTokenWalletErrors.error_low_message_value);
            tvm.rawReserve(reserve, 2);
            balance_ -= tokens;

            ITONTokenWallet(to).internalTransfer{ value: 0, flag: 129, bounce: true }(
                tokens,
                wallet_public_key,
                owner_address,
                send_gas_to.value != 0 ? send_gas_to : owner_address,
                notify_receiver,
                payload
            );
        } else {
            require(address(this).balance > grams, TONTokenWalletErrors.error_low_message_value);
            require(grams > TONTokenWalletConstants.target_gas_balance, TONTokenWalletErrors.error_low_message_value);
            tvm.accept();
            balance_ -= tokens;

            ITONTokenWallet(to).internalTransfer{ value: grams, bounce: true, flag: 1 }(
                tokens,
                wallet_public_key,
                owner_address,
                send_gas_to.value != 0 ? send_gas_to : address(this),
                notify_receiver,
                payload
            );
        }
    }

    /*
        @notice Transfer tokens from another token wallet
        @dev Can be called only by owner
        @param from Token wallet to transfer tokens from
        @param to Tokens receiver token wallet
        @param tokens How much tokens to transfer from
        @param grams How much TONs to attach
        @param send_gas_to Remaining TONs receiver
        @param notify_receiver Notify receiver on incoming transfer
        @param payload Notification payload
    */
    function transferFrom(
        address from,
        address to,
        uint128 tokens,
        uint128 grams,
        address send_gas_to,
        bool notify_receiver,
        TvmCell payload
    )
        override
        external
        onlyOwner
    {
        require(to.value != 0, TONTokenWalletErrors.error_wrong_recipient);
        require(tokens > 0);
        require(from != to, TONTokenWalletErrors.error_wrong_recipient);

        if (owner_address.value != 0 ) {
            uint128 reserve = math.max(TONTokenWalletConstants.target_gas_balance, address(this).balance - msg.value);
            require(address(this).balance > reserve + (TONTokenWalletConstants.target_gas_balance * 2), TONTokenWalletErrors.error_low_message_value);
            tvm.rawReserve(reserve, 2);

            ITONTokenWallet(from).internalTransferFrom{ value: 0, flag: 129 }(
                to,
                tokens,
                send_gas_to.value != 0 ? send_gas_to : owner_address,
                notify_receiver,
                payload
            );
        } else {
            require(address(this).balance > grams, TONTokenWalletErrors.error_low_message_value);
            require(grams > TONTokenWalletConstants.target_gas_balance * 2, TONTokenWalletErrors.error_low_message_value);
            tvm.accept();
            ITONTokenWallet(from).internalTransferFrom{ value: grams, flag: 1 }(
                to,
                tokens,
                send_gas_to.value != 0 ? send_gas_to : address(this),
                notify_receiver,
                payload
            );
        }
    }

    /*
        @notice Callback for transfer operation
        @dev Can be called only by correct token wallet contract
        @param tokens How much tokens to receive
        @param sender_public_key Sender token wallet owner public key
        @param sender_address Sender token wallet owner address
        @param send_gas_to Remaining TONs balance receiver
        @param notify_receiver Notify receiver on incoming transfer
        @param payload Notification payload
    */
    function internalTransfer(
        uint128 tokens,
        uint256 sender_public_key,
        address sender_address,
        address send_gas_to,
        bool notify_receiver,
        TvmCell payload
    )
        override
        external
    {
        require(notify_receiver || allow_non_notifiable || receive_callback.value == 0,
                TONTokenWalletErrors.error_recipient_has_disallow_non_notifiable);
        address expectedSenderAddress = getExpectedAddress(sender_public_key, sender_address);
        require(msg.sender == expectedSenderAddress, TONTokenWalletErrors.error_message_sender_is_not_good_wallet);
        require(sender_address != owner_address || sender_public_key != wallet_public_key, TONTokenWalletErrors.error_wrong_recipient);

        if (owner_address.value != 0 ) {
            uint128 reserve = math.max(TONTokenWalletConstants.target_gas_balance, address(this).balance - msg.value);
            require(address(this).balance > reserve, TONTokenWalletErrors.error_low_message_value);
            tvm.rawReserve(reserve, 2);
        } else {
            tvm.rawReserve(address(this).balance - msg.value, 2);
        }

        balance_ += tokens;

        if (notify_receiver && receive_callback.value != 0) {
            ITokensReceivedCallback(receive_callback).tokensReceivedCallback{ value: 0, flag: 128 }(
                address(this),
                root_address,
                tokens,
                sender_public_key,
                sender_address,
                msg.sender,
                send_gas_to,
                balance_,
                payload
            );
        } else {
            send_gas_to.transfer({ value: 0, flag: 128 });
        }
    }

    /*
        @notice Callback for transferFrom operation
        @dev Can be called only by correct token wallet
        @param to Tokens receiver
        @param tokens How much tokens to transfer
        @param send_gas_to Remaining balance receiver
        @param notify_receiver Notify receiver on incoming transfer
        @param payload Notification payload
    */
    function internalTransferFrom(
        address to,
        uint128 tokens,
        address send_gas_to,
        bool notify_receiver,
        TvmCell payload
    )
        override
        external
    {
        require(allowance_.hasValue(), TONTokenWalletErrors.error_no_allowance_set);
        require(msg.sender == allowance_.get().spender, TONTokenWalletErrors.error_wrong_spender);
        require(tokens <= allowance_.get().remaining_tokens, TONTokenWalletErrors.error_not_enough_allowance);
        require(tokens <= balance_, TONTokenWalletErrors.error_not_enough_balance);
        require(tokens > 0);
        require(to != address(this), TONTokenWalletErrors.error_wrong_recipient);

        if (owner_address.value != 0 ) {
            uint128 reserve = math.max(TONTokenWalletConstants.target_gas_balance, address(this).balance - msg.value);
            require(address(this).balance > reserve + TONTokenWalletConstants.target_gas_balance, TONTokenWalletErrors.error_low_message_value);
            tvm.rawReserve(reserve, 2);
            tvm.rawReserve(math.max(TONTokenWalletConstants.target_gas_balance, address(this).balance - msg.value), 2);
        } else {
            require(msg.value > TONTokenWalletConstants.target_gas_balance, TONTokenWalletErrors.error_low_message_value);
            tvm.rawReserve(address(this).balance - msg.value, 2);
        }

        balance_ -= tokens;

        allowance_.set(AllowanceInfo(allowance_.get().remaining_tokens - tokens, allowance_.get().spender));

        ITONTokenWallet(to).internalTransfer{ value: 0, bounce: true, flag: 129 }(
            tokens,
            wallet_public_key,
            owner_address,
            send_gas_to,
            notify_receiver,
            payload
        );
    }

    /*
        @notice Burn tokens
        @dev Can be called only by token wallet owner
        @param tokens How much tokens to burn
        @param grams How much TONs attach to tokensBurned in case called with owner public key
        @param send_gas_to Receiver of the remaining TONs balance, used in tokensBurned callback
        @param callback_address Part of root tokensBurned callback data
        @param callback_payload Part of root tokensBurned callback data
    */
    function burnByOwner(
        uint128 tokens,
        uint128 grams,
        address send_gas_to,
        address callback_address,
        TvmCell callback_payload
    ) override external onlyOwner {
        require(tokens > 0);
        require(tokens <= balance_, TONTokenWalletErrors.error_not_enough_balance);
        require((owner_address.value != 0 && msg.value > 0) ||
                (owner_address.value == 0 && grams <= address(this).balance && grams > 0), TONTokenWalletErrors.error_low_message_value);

        if (owner_address.value != 0 ) {
            tvm.rawReserve(math.max(TONTokenWalletConstants.target_gas_balance, address(this).balance - msg.value), 2);
            balance_ -= tokens;
            IBurnableTokenRootContract(root_address)
                .tokensBurned{ value: 0, flag: 128, bounce: true }(
                    tokens,
                    wallet_public_key,
                    owner_address,
                    send_gas_to.value != 0 ? send_gas_to : owner_address,
                    callback_address,
                    callback_payload
                );
        } else {
            tvm.accept();
            balance_ -= tokens;
            IBurnableTokenRootContract(root_address)
                .tokensBurned{ value: grams, bounce: true }(
                    tokens,
                    wallet_public_key,
                    owner_address,
                    send_gas_to.value != 0 ? send_gas_to : address(this),
                    callback_address,
                    callback_payload
                );
        }
    }

    /*
        @notice Burn tokens in case it's initiated by the root and execute callback
        @dev Can be called only by root token wallet
        @param tokens How much tokens to burn
        @param send_gas_to Part of root callback data
        @param callback_address Part of root callback data
        @param callback_payload Part of root callback data
    */
    function burnByRoot(
        uint128 tokens,
        address send_gas_to,
        address callback_address,
        TvmCell callback_payload
    ) override external onlyRoot {
        require(tokens > 0);
        require(tokens <= balance_, TONTokenWalletErrors.error_not_enough_balance);

        tvm.rawReserve(address(this).balance - msg.value, 2);

        balance_ -= tokens;

        IBurnableTokenRootContract(root_address)
            .tokensBurned{ value: 0, flag: 128, bounce: true }(
                tokens,
                wallet_public_key,
                owner_address,
                send_gas_to,
                callback_address,
                callback_payload
            );
    }

    // recurring payments logic
    function buildSubscriptionState(TvmCell subscriptionCode, address serviceOwner, TvmCell params, TvmCell indificator) private view returns (TvmCell) {
        TvmBuilder saltBuilder;
        saltBuilder.store(owner_address, subsmanAddr, tvm.hash(tvm.code()));
        TvmCell codeSalt = tvm.setCodeSalt(
            subscriptionCode,
            saltBuilder.toCell()
        );
        TvmCell newImage = tvm.buildStateInit({
            code: codeSalt,
            pubkey: 0,
            varInit: {
                serviceOwner: serviceOwner,
                user_wallet: address(this),
                params: params,
                subscription_indificator: indificator,
                owner_address: owner_address
            },
            contr: Subscription
        });
        return newImage;
    }

    function paySubscription(address serviceOwner, TvmCell params, TvmCell indificator) public {
        require(msg.value >= 0.2 ton, TONTokenWalletErrors.error_low_message_value);
        tvm.rawReserve(address(this).balance - msg.value, 2);
        (address service_owner_address, uint128 value) = params.toSlice().decode(address, uint128);
        address recipient = getExpectedAddress(0, service_owner_address);
        bool senderIsSubscription;
        address subsAddr;
        for ((uint8 k,) : subscr_images) {
            TvmCell image = subscr_images[k];
            TvmCell imageCode = image.toSlice().loadRef();
            subsAddr = address(tvm.hash(buildSubscriptionState(
                imageCode,
                serviceOwner, 
                params, 
                indificator
            )));
            if (msg.sender == subsAddr) {
                senderIsSubscription = true;
                break;
            } 
        }
        if (senderIsSubscription == true) {
            ITONTokenWalletConfigVersions(configVersionsAddr).getFees{value: 0, flag: 128, callback: TONTokenWallet.setFeesAndPay}(recipient, value, subsAddr);
        } else {
            // send change back
            msg.sender.transfer({value: 0, flag: 128});
        }
    }

    function setFeesAndPay(fees paramsFee, address recipient, uint128 value, address subsAddr) external {
        require(msg.sender == configVersionsAddr, TONTokenWalletErrors.error_message_sender_is_not_good_config_contract);
        tvm.rawReserve(address(this).balance - msg.value, 2);
        serviceFee = paramsFee.serviceFee;
        subscriberFee = paramsFee.subscriberFee;
        uint128 feeAmount = value * (serviceFee + subscriberFee) / 100; // TODO need to think where to send and how to swap
        uint128 serviceRevenue = value - feeAmount;
        TvmCell none;
        transferInline(recipient, serviceRevenue, 0, subsAddr, false, none);
    }

    /*
        @notice Set new receive callback receiver
        @dev Set 0:0 in case you want to disable receive callback
        @param receive_callback_ Receive callback receiver
        @param allow_non_notifiable_ Allow no notification
    */
    function setReceiveCallback(
        address receive_callback_,
        bool allow_non_notifiable_
    )
        override
        external
        onlyOwner
    {
        tvm.accept();
        receive_callback = receive_callback_;
        allow_non_notifiable = allow_non_notifiable_;
    }

    /*
        @notice Set new bounce callback receiver
        @dev Set 0:0 in case you want to disable bounced callback
        @param bounced_callback_ Callback receiver
    */
    function setBouncedCallback(
        address bounced_callback_
    )
        override
        external
        onlyOwner
    {
        tvm.accept();
        bounced_callback = bounced_callback_;
    }

    /*
        @notice Destroy token wallet and withdraw TONs balance
        @dev Requires 0 token balance
        @param gas_dest TONs receiver
    */
    function destroy(
        address gas_dest
    )
        override
        public
        onlyOwner
    {
        require(balance_ == 0);
        tvm.accept();
        selfdestruct(gas_dest);
    }

    // =============== Support functions ==================

    modifier onlyRoot() {
        require(root_address == msg.sender, TONTokenWalletErrors.error_message_sender_is_not_my_root);
        _;
    }

    modifier onlyOwner() {
        require((owner_address.value != 0 && owner_address == msg.sender) ||
                (wallet_public_key != 0 && wallet_public_key == msg.pubkey()) ||
                (msg.sender == address(this)),
                TONTokenWalletErrors.error_message_sender_is_not_my_owner);
        _;
    }

    modifier onlyInternalOwner() {
        require(owner_address.value != 0 && owner_address == msg.sender);
        _;
    }

    /*
        @notice Derive token wallet contract address from owner credentials
        @param wallet_public_key_ Token wallet owner public key
        @param owner_address_ Token wallet owner address
    */
    function getExpectedAddress(
        uint256 wallet_public_key_,
        address owner_address_
    )
        private
        inline
        view
    returns (
        address
    ) {
        TvmCell stateInit = tvm.buildStateInit({
            contr: TONTokenWallet,
            varInit: {
                root_address: root_address,
                code: code,
                wallet_public_key: wallet_public_key_,
                owner_address: owner_address_
            },
            pubkey: wallet_public_key_,
            code: code
        });

        return address(tvm.hash(stateInit));
    }

    /*
        @notice On-bounce handler
        @dev Catch bounce if internalTransfer or tokensBurned fails
        @dev If transfer fails - increase back tokens balance and notify bounced_callback
        @dev If tokens burn root token callback fails - increase back tokens balance
        @dev Withdraws gas to owner_address by default if internal ownership is used
        @dev Or sends gas to bounce_callback if it's enabled
    */
    onBounce(TvmSlice body) external {
        tvm.accept();

        uint32 functionId = body.decode(uint32);
        if (functionId == tvm.functionId(ITONTokenWallet.internalTransfer)) {
            uint128 tokens = body.decode(uint128);
            balance_ += tokens;

            if (bounced_callback.value != 0) {
                tvm.rawReserve(address(this).balance - msg.value, 2);
                ITokensBouncedCallback(bounced_callback).tokensBouncedCallback{ value: 0, flag: 128 }(
                    address(this),
                    root_address,
                    tokens,
                    msg.sender,
                    balance_
                );
            } else if (owner_address.value != 0) {
                tvm.rawReserve(math.max(TONTokenWalletConstants.target_gas_balance, address(this).balance - msg.value), 2);
                owner_address.transfer({ value: 0, flag: 128 });
            }
        } else if (functionId == tvm.functionId(IBurnableTokenRootContract.tokensBurned)) {
            balance_ += body.decode(uint128);
            if (owner_address.value != 0) {
                tvm.rawReserve(math.max(TONTokenWalletConstants.target_gas_balance, address(this).balance - msg.value), 2);
                owner_address.transfer({ value: 0, flag: 128 });
            }
        }
    }

    fallback() external {
    }
}
