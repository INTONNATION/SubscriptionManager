pragma ton-solidity >=0.56.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

import "./EverduesServiceStorage.sol";
import "../../libraries/EverduesErrors.sol";
import "../../interfaces/IEverduesIndex.sol";

import "../../../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenWallet.sol";
import "../../../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenRoot.sol";

abstract contract EverduesServiceBase is
	EverduesServiceStorage
{
	constructor() public {
		revert();
	}

	event ServiceDeployed(
		address subscription_service_index_address,
		address subscription_service_index_identificator_address
	);

	event ServiceDeleted();
	modifier onlyRoot() {
		require(
			msg.sender == root,
			EverduesErrors.error_message_sender_is_not_everdues_root
		);
		_;
	}

	modifier onlyOwner() {
		require(
			(msg.pubkey() == owner_pubkey),
			EverduesErrors.error_message_sender_is_not_owner
		);
		_;
	}

	modifier onlyRootOrOwner() {
		require(
			(msg.sender == root ||
				msg.pubkey() == owner_pubkey),
			EverduesErrors.error_message_sender_is_not_owner
		);
		_;
	}
	
	modifier onlyAccount() {
		require(
			msg.sender == account_address,
			EverduesErrors.error_message_sender_is_not_owner
		);
		_;
	}

	function onAcceptTokensTransfer(
		address tokenRoot,
		uint128 amount,
		address /*sender*/,
		address /*senderWallet*/,
		address remainingGasTo,
		TvmCell /*payload*/
	) external {
		require(
			wallet_balance.wallet == address(0),
			EverduesErrors.error_service_tokens_already_locked
		);
		tvm.rawReserve(EverduesGas.SERVICE_INITIAL_BALANCE, 2);
		wallet_balance.wallet = msg.sender;
		wallet_balance.tokens = amount;
		wallet_balance.currency_root = tokenRoot;
		remainingGasTo.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}

	function updateServiceParams(
		TvmCell new_service_params
	) external onlyOwner {
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

	function updateGasCompenstationProportion(
		uint8 service_gas_compenstation_,
		uint8 subscription_gas_compenstation_
	) external onlyOwner {
		tvm.accept();
		service_gas_compenstation = service_gas_compenstation_;
		subscription_gas_compenstation = subscription_gas_compenstation_;
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

	function cancel() external onlyOwner {
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
		}(account_address);
		TvmCell empty;
		if (
			subscription_service_index_identificator_address !=
			address(tvm.hash(empty))
		) {
			IEverduesIndex(subscription_service_index_identificator_address)
				.cancel{
				value: EverduesGas.MESSAGE_MIN_VALUE,
				bounce: false,
				flag: 0
			}(account_address);
		}
		selfdestruct(account_address);
		emit ServiceDeleted();
	}
}
