pragma ton-solidity >=0.56.0;

import "./EverduesRootSettings.sol";
import "../../interfaces/IEverduesService.sol";
import "../../interfaces/IEverduesAccount.sol";
import "../../interfaces/IEverduesSubscription.sol";

import "../../../ton-eth-bridge-token-contracts/contracts/interfaces/ITokenWallet.sol";

abstract contract EverduesRootBase is EverduesRootSettings {
	onBounce(TvmSlice slice) external view {
		// revert change to initial msg.sender in case of failure during deploy
		// TODO: after https://github.com/tonlabs/ton-labs-node/issues/140
		//uint32 functionId = slice.decode(uint32);
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
		IEverduesFeeProxy(fee_proxy_address).transferRevenue{
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
		IEverduesFeeProxy(fee_proxy_address).swapRevenueToMTDS{
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
		IEverduesFeeProxy(fee_proxy_address).syncBalance{
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
		EverduesRootBase.ContractParams latestVersion = versions[
			ContractTypes.FeeProxy
		][1];
		IEverduesFeeProxy(fee_proxy_address).upgrade{
			value: 0,
			bounce: true,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(latestVersion.contractCode, 1, msg.sender, upgrade_data);
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
		optional(uint32, ContractParams) latest_version_opt = versions[
			ContractTypes.Account
		].max();
		(
			uint32 latest_version,
			ContractParams latest_params
		) = latest_version_opt.get();
		IEverduesAccount(account_address).upgrade{
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(latest_params.contractCode, latest_version, update_data);
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
			tvm.hash(_buildAccountInitData(ContractTypes.Account, pubkey))
		);
		TvmCell update_data = abi.encode(dex_root_address, wever_root);
		require(
			msg.sender == account_address,
			EverduesErrors.error_message_sender_is_not_account_address
		);
		optional(uint32, ContractParams) latest_version_opt = versions[
			ContractTypes.Account
		].max();
		(
			uint32 latest_version,
			ContractParams latest_params
		) = latest_version_opt.get();
		IEverduesAccount(account_address).upgrade{
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(latest_params.contractCode, latest_version, update_data);
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
					ContractTypes.Subscription,
					_buildSubscriptionPlatformParams(
						msg.sender,
						service_address
					)
				)
			)
		);
		IEverduesSubscription(subscription_address).upgradeSubscriptionPlan{
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
					ContractTypes.Subscription,
					_buildSubscriptionPlatformParams(
						msg.sender,
						service_address
					)
				)
			)
		);
		TvmCell upgrade_data;
		optional(uint32, ContractParams) latest_version_opt = versions[
			ContractTypes.Subscription
		].max();
		(uint32 latest_version, ) = latest_version_opt.get();
		IEverduesSubscription(subscription_address).upgrade{
			value: 0,
			bounce: true, // TODO: need to revert balance back to current msg.sender in case of failure
			flag: MsgFlag.ALL_NOT_RESERVED
		}(subscription_code_salt, latest_version, msg.sender, upgrade_data);
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
		optional(uint32, ContractParams) latest_version_opt = versions[
			ContractTypes.Subscription
		].max();
		(uint32 latest_version, ) = latest_version_opt.get();
		IEverduesSubscription(subscription_address).upgrade{
			value: 0,
			bounce: true, // TODO: need to revert balance back to current msg.sender in case of failure
			flag: MsgFlag.ALL_NOT_RESERVED
		}(subscription_code_salt, latest_version, address(this), upgrade_data);
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
					ContractTypes.Service,
					_buildServicePlatformParams(msg.sender, service_name)
				)
			)
		);
		TvmCell upgrade_data;
		optional(uint32, ContractParams) latest_version_opt = versions[
			ContractTypes.Service
		].max();
		(uint32 latest_version, ) = latest_version_opt.get();
		IEverduesService(service_address).upgrade{
			value: 0,
			bounce: true,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(service_code_salt, latest_version, msg.sender, upgrade_data);
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
		optional(uint32, ContractParams) latest_version_opt = versions[
			ContractTypes.Service
		].max();
		(uint32 latest_version, ) = latest_version_opt.get();
		IEverduesService(service_address).upgrade{
			value: 0,
			bounce: true,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(service_code_salt, latest_version, address(this), upgrade_data);
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
		EverduesRootBase.ContractParams latestVersion = versions[
			ContractTypes.FeeProxy
		][1];
		Platform platform = new Platform{
			stateInit: _buildInitData(
				ContractTypes.FeeProxy,
				_buildPlatformParamsOwnerAddress(address(this))
			),
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(
			latestVersion.contractCode,
			fee_proxy_contract_params,
			1,
			msg.sender,
			0
		);
		fee_proxy_address = address(platform);
	}

	function deployAccount(uint256 pubkey) external view {
		address account_address = address(
			tvm.hash(_buildAccountInitData(ContractTypes.Account, pubkey))
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
		optional(uint32, ContractParams) latest_version_opt = versions[
			ContractTypes.Account
		].max();
		(
			uint32 latest_version,
			ContractParams latest_params
		) = latest_version_opt.get();
		Platform(msg.sender).initializeByRoot{
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(latest_params.contractCode, account_params, latest_version);
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
					EverduesGas.DEPLOY_SUBSCRIPTION_VALUE +
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
			tvm.hash(_buildAccountInitData(ContractTypes.Account, owner_pubkey))
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
		optional(uint32, ContractParams) latest_version_opt = versions[
			ContractTypes.Subscription
		].max();
		(uint32 latest_version, ) = latest_version_opt.get();
		Platform platform = new Platform{
			stateInit: _buildInitData(
				ContractTypes.Subscription,
				_buildSubscriptionPlatformParams(msg.sender, service_address)
			),
			value: EverduesGas.SUBSCRIPTION_INITIAL_BALANCE +
				EverduesGas.DEPLOY_SUBSCRIPTION_VALUE +
				EverduesGas.EXECUTE_SUBSCRIPTION_VALUE +
				(additional_gas / 3),
			flag: MsgFlag.SENDER_PAYS_FEES
		}(
			subscription_code_salt,
			subscription_params,
			latest_version,
			msg.sender,
			0
		);
		TvmCell index_owner = abi.encode(address(platform));
		new Index{
			value: EverduesGas.INDEX_INITIAL_BALANCE +
				(additional_gas / 3 - 100),
			flag: MsgFlag.SENDER_PAYS_FEES,
			bounce: false,
			stateInit: subsIndexStateInit
		}(index_owner, msg.sender);
		if (!identificator.toSlice().empty()) {
			new Index{
				value: EverduesGas.INDEX_INITIAL_BALANCE +
					(additional_gas / 3 - 100),
				flag: MsgFlag.SENDER_PAYS_FEES,
				bounce: false,
				stateInit: subsIndexIdentificatorStateInit
			}(index_owner, msg.sender);
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
	) private view returns (address) {
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
							ContractTypes.Service,
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
			address(tvm.hash(serviceIdentificatorIndexStateInit)),
			owner_pubkey
		);
		TvmCell service_params_cell_with_additional_params = abi.encode(
			service_params_cell,
			additional_params
		);
		optional(uint32, ContractParams) latest_version_opt = versions[
			ContractTypes.Service
		].max();
		(uint32 latest_version, ) = latest_version_opt.get();
		Platform platform = new Platform{
			stateInit: _buildInitData(
				ContractTypes.Service,
				_buildServicePlatformParams(msg.sender, service_name)
			),
			value: EverduesGas.DEPLOY_SERVICE_VALUE2,
			flag: MsgFlag.SENDER_PAYS_FEES
		}(
			service_code_salt,
			service_params_cell_with_additional_params,
			latest_version,
			msg.sender,
			0
		);
		TvmCell index_owner = abi.encode(address(platform));
		new Index{
			value: EverduesGas.INDEX_INITIAL_BALANCE +
				EverduesGas.MESSAGE_MIN_VALUE +
				(additional_gas / 3),
			flag: MsgFlag.SENDER_PAYS_FEES,
			bounce: false,
			stateInit: serviceIndexStateInit
		}(index_owner, msg.sender);
		if (!identificator.toSlice().empty()) {
			new Index{
				value: EverduesGas.INDEX_INITIAL_BALANCE +
					EverduesGas.MESSAGE_MIN_VALUE +
					(additional_gas / 3),
				flag: MsgFlag.SENDER_PAYS_FEES,
				bounce: false,
				stateInit: serviceIdentificatorIndexStateInit
			}(index_owner, msg.sender);
		}
		return address(platform);
	}

	function onAcceptTokensTransfer(
		address tokenRoot,
		uint128 amount,
		address sender,
		address, /*senderWallet*/
		address remainingGasTo,
		TvmCell payload
	) external view {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		optional(ServiceDeployParams) required_tokens_struct = wallets_mapping
			.fetch(tokenRoot);
		if (required_tokens_struct.hasValue()) {
			ServiceDeployParams service_deploy_params = required_tokens_struct
				.get();
			require(
				msg.sender == service_deploy_params.wallet_address,
				EverduesErrors.error_message_sender_is_not_root_wallet
			);
			if (amount >= service_deploy_params.required_amount) {
				(
					TvmCell service_params,
					TvmCell identificator,
					uint256 pubkey,
					bool publish_to_catalog,
					uint128 additional_gas
				) = abi.decode(
						payload,
						(TvmCell, TvmCell, uint256, bool, uint128)
					);
				address account_contract_address = address(
					tvm.hash(
						_buildAccountInitData(ContractTypes.Account, pubkey)
					)
				);
				require(
					sender == account_contract_address,
					EverduesErrors.error_message_sender_is_not_account_address
				);
				address service_address = deployService(
					service_params,
					identificator,
					pubkey,
					publish_to_catalog,
					additional_gas
				);
				ITokenWallet(service_deploy_params.wallet_address).transfer{
					value: 0,
					bounce: true,
					flag: MsgFlag.ALL_NOT_RESERVED
				}(amount, service_address, 0, remainingGasTo, true, payload);
			} else {
				// TODO rewrite payload to add error code - unsupported tip3 root
				ITokenWallet(service_deploy_params.wallet_address).transfer{
					value: 0,
					bounce: true,
					flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
				}(amount, sender, 0, remainingGasTo, false, payload);
			}
		}
	}
}
