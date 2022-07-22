pragma ton-solidity >=0.56.0;

import "./EverduesServiceStorage.sol";
import "../../libraries/EverduesErrors.sol";
import "../../interfaces/IEverduesIndex.sol";

import "../../../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenWallet.sol";
import "../../../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenRoot.sol";

abstract contract EverduesServiceBase is
	IEverduesService,
	EverduesServiceStorage
{
	constructor() public {
		revert();
	}

	modifier onlyRoot() {
		require(
			msg.sender == root,
			EverduesErrors.error_message_sender_is_not_everdues_root
		);
		_;
	}

	modifier onlyOwner() {
		require(
			msg.pubkey() == owner_pubkey,
			EverduesErrors.error_message_sender_is_not_owner
		);
		_;
	}

	function onAcceptTokensTransfer(
		address tokenRoot,
		uint128 amount,
		address, /*sender*/
		address, /*senderWallet*/
		address remainingGasTo,
		TvmCell /*payload*/
	) external {
		require(
			wallet_balance.wallet == address(0),
			EverduesErrors.error_service_tokens_already_locked
		);
		wallet_balance.wallet = msg.sender;
		wallet_balance.tokens = amount;
		wallet_balance.currency_root = tokenRoot;
		remainingGasTo.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.REMAINING_GAS + MsgFlag.IGNORE_ERRORS
		});
	}

	function updateServiceParams(TvmCell new_service_params)
		external
		onlyOwner
	{
		tvm.accept();
		TvmCell subscription_plans_cell;
		(service_params, subscription_plans_cell) = abi.decode(
			new_service_params,
			(TvmCell, TvmCell)
		);
		subscription_plans = abi.decode(
			subscription_plans_cell,
			mapping(uint8 => TvmCell)
		);
	}

	function updateIdentificator(TvmCell index_data) external view onlyOwner {
		tvm.accept();
		IEverduesIndex(subscription_service_index_identificator_address)
			.updateIndexData{value: 0, flag: MsgFlag.REMAINING_GAS}(
			index_data,
			address(this)
		);
	}

	function pause() external onlyOwner {
		tvm.accept();
		status = 1;
	}

	function resume() external onlyOwner {
		tvm.accept();
		status = 0;
	}

	function cancel() external override onlyOwner {
		tvm.accept();
		TvmCell payload;
		ITokenWallet(wallet_balance.wallet).transfer{
			value: EverduesGas.TRANSFER_MIN_VALUE,
			bounce: false,
			flag: 0
		}(
			wallet_balance.tokens,
			account_address,
			0,
			account_address,
			true,
			payload
		);
		IEverduesIndex(subscription_service_index_address).cancel{
			value: EverduesGas.MESSAGE_MIN_VALUE,
			bounce: false,
			flag: 0
		}();
		IEverduesIndex(subscription_service_index_identificator_address).cancel{
			value: EverduesGas.MESSAGE_MIN_VALUE,
			bounce: false,
			flag: 0
		}();
		selfdestruct(account_address);
		emit ServiceDeleted();
	}
}
