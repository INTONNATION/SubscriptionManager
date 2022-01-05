pragma ton-solidity >= 0.51.0;

import "interfaces/IRootTokenContract.sol";
import "interfaces/ITONTokenWallet.sol";
import "interfaces/IBurnableByRootTokenRootContract.sol";
import "TIP-3/TONTokenWallet.sol";
import "libraries/ConvertTIP3Errors.sol";


contract convertTIP3 {

    address public tip3_token_root;
    address public mtip3_token_root;
    address public tip3_token_wallet;
    address public mtip3_token_wallet;    
    TvmCell static tip3_wallet_code;

    modifier onlyOwner() {
        require(msg.pubkey() == tvm.pubkey(), ConvertTIP3Errors.error_message_sender_is_not_my_owner);
        tvm.accept();
        _;
    }

    constructor(
        address tip3_token_root_, 
        address mtip3_token_root_, 
        address tip3_token_wallet_, 
        address mtip3_token_wallet_
    ) public 
    {
        require(msg.pubkey() == tvm.pubkey(), ConvertTIP3Errors.error_message_sender_is_not_my_owner);
        tvm.accept();
        tip3_token_wallet = tip3_token_wallet_;
        mtip3_token_wallet = mtip3_token_wallet_;
        tip3_token_root = tip3_token_root_;
        mtip3_token_root = mtip3_token_root_;
    }

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
                root_address: tip3_token_root,
                code: tip3_wallet_code,
                wallet_public_key: wallet_public_key_,
                owner_address: owner_address_
            },
            pubkey: wallet_public_key_,
            code: tip3_wallet_code
        });
        return address(tvm.hash(stateInit));
    }

    function setReceiveCallback() public onlyOwner {
        ITONTokenWallet(tip3_token_wallet).setReceiveCallback{
            value: 0.1 ton,
            flag: 0
        }(
            address(this),
            true
        );
        ITONTokenWallet(mtip3_token_wallet).setReceiveCallback{
            value: 0.1 ton,
            flag: 0
        }(
            address(this),
            true
        );
    }

    function tokensReceivedCallback(
        address token_wallet,
        address token_root,
        uint128 tokens_amount,
        uint256 sender_public_key,
        address sender_address,
        address sender_wallet,
        address original_gas_to,
        uint128 /*updated_balance*/,
        TvmCell payload
    ) external {
        require(msg.sender == token_wallet, ConvertTIP3Errors.error_message_sender_wallet_is_incorrect);
        // TIP3 -> mTIP3
        if (token_wallet == tip3_token_wallet) {
            IRootTokenContract(mtip3_token_root).deployWallet{
                    value: 2 ton,
                    flag: 1
                }(
                    tokens_amount,
                    1 ton,
                    sender_public_key,
                    sender_address,
                    original_gas_to
                );
        // mTIP3 -> TIP3
        } else if (token_wallet == mtip3_token_wallet) {
            address senderAddress = getExpectedAddress(sender_public_key, sender_address);
            TvmCell payload_; 
            ITONTokenWallet(tip3_token_wallet).transfer{
                value: 2 ton,
                flag: 1
            }(
                senderAddress,
                tokens_amount,
                1 ton,
                tip3_token_wallet,
                false,
                payload
            );
            // need to ensure that tokens transfered and only after that burn mTIP3 tokens (important!)
            IBurnableByRootTokenRootContract(mtip3_token_root).proxyBurn{
                    value: 2 ton,
                    flag: 1
                }(
                    tokens_amount,
                    token_wallet,
                    original_gas_to,
                    address.makeAddrStd(0, 0),
                    payload_ // temp
                );
            // verify that tokens were burn
        }
    }
}