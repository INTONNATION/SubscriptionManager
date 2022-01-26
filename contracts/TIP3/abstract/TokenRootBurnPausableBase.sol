pragma ton-solidity >= 0.39.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./TokenRootDisableableMintBase.sol";
import "../interfaces/IBurnPausableTokenRoot.sol";
import "../libraries/TokenMsgFlag.sol";


abstract contract TokenRootBurnPausableBase is TokenRootDisableableMintBase, IBurnPausableTokenRoot {

    bool burnPaused_;

    function burnPaused() override external view responsible returns (bool) {
        return { value: 0, flag: TokenMsgFlag.REMAINING_GAS, bounce: false } burnPaused_;
    }

    function setBurnPaused(bool paused) override external responsible onlyRootOwner returns (bool) {
        burnPaused_ = paused;
        return { value: 0, flag: TokenMsgFlag.REMAINING_GAS, bounce: false } burnPaused_;
    }

    function _burnEnabled() override internal view returns (bool) {
        return !burnPaused_;
    }

}
