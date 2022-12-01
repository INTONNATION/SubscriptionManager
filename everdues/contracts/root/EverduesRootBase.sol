pragma ton-solidity >=0.56.0;

pragma AbiHeader expire;
pragma AbiHeader pubkey;

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
		}(dues_revenue_accumulator_address, owner);
	}

	function swapRevenueToEver(uint128 amount, address currency_root, address dex_ever_pair_address) external view onlyOwner {
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
		IEverduesFeeProxy(fee_proxy_address).swapTIP3ToEver{
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(amount, currency_root, dex_ever_pair_address, tip3_to_ever_address);		
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
		IEverduesFeeProxy(fee_proxy_address).swapRevenueToDUES{
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

	function forceDestroyAccount(address account_address) // temp function
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
		IEverduesAccount(account_address).destroyAccount{
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(address(this));
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

	function depositCrossChainTokens(address recipient, address remainingGasTo, uint128 amount) private view {
		TvmCell payload;

		ITokenWallet(wallets_mapping[cross_chain_token].wallet_address).transfer{
			value: 0,
			bounce: true,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		}(amount, recipient, EverduesGas.DEPLOY_EMPTY_WALLET_GRAMS, remainingGasTo, true, payload);		
	}



	function addOrUpdateExternalSubscriber(uint8 chain_id, uint256 pubkey, string customer, string payee, address everdues_service_address, uint8 subscription_plan, string tokenAddress, string email, uint128 paid_amount, bool status, uint128 additional_gas) external onlyOwner {
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		ExternalSubscription external_subscription_event;
		external_subscription_event.Customer = customer;
		external_subscription_event.Payee = payee;
		external_subscription_event.SubscriptionPlan = subscription_plan;
		external_subscription_event.TokenAddress = tokenAddress;
		external_subscription_event.PubKey = pubkey;
		external_subscription_event.Email = email;
		external_subscription_event.PaidAmount = paid_amount;
		external_subscription_event.IsActive = true;
		uint256 sid = tvm.hash(abi.encode(pubkey, everdues_service_address));
		optional(ExternalSubscription) chain_subscriptions = cross_chain_subscriptions[chain_id].getAdd(sid, external_subscription_event);
        address account_address = address(
			tvm.hash(_buildAccountInitData(ContractTypes.Account, pubkey))
		); 
		TvmCell identificator = abi.encode(email);
		if (chain_subscriptions.hasValue()) {
            ExternalSubscription existing_user_subscriptions = chain_subscriptions.get();
            external_subscription_event.IsActive = status;
			uint128 value = existing_user_subscriptions.PaidAmount - external_subscription_event.PaidAmount;
            cross_chain_subscriptions[chain_id].replace(pubkey, external_subscription_event);
			if (value > 0) {
				depositCrossChainTokens(account_address, msg.sender, value);
			}
        } else {
			deployExternalAccount(pubkey);
			depositCrossChainTokens(account_address, msg.sender, paid_amount);
			deployExternalSubscription(chain_id, customer, payee, tokenAddress, everdues_service_address, identificator, pubkey, subscription_plan, additional_gas);
		}
		msg.sender.transfer({
			value: 0,
			bounce: false,
			flag: MsgFlag.ALL_NOT_RESERVED + MsgFlag.IGNORE_ERRORS
		});
	}

	function deployExternalAccount(uint256 pubkey) private view {
		optional(uint32, ContractParams) latest_version_opt = versions[
			ContractTypes.Account
		].max();
		(
			uint32 latest_version,
			ContractParams latest_params
		) = latest_version_opt.get();
		TvmCell account_params = abi.encode(
			dex_root_address,
			wever_root,
			tip3_to_ever_address,
			account_threshold,
			tvm.hash(latest_params.contractAbi)
		);
		new Platform{
			stateInit: _buildAccountInitData(
				ContractTypes.Account,
				pubkey
			),
			value: EverduesGas.ACCOUNT_INITIAL_BALANCE + EverduesGas.MESSAGE_MIN_VALUE,
			flag: MsgFlag.SENDER_PAYS_FEES
		}(
			latest_params.contractCode,
			account_params,
			latest_version,
			msg.sender,
			0
		);
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
		optional(uint32, ContractParams) latest_version_opt = versions[
			ContractTypes.Account
		].max();
		(
			uint32 latest_version,
			ContractParams latest_params
		) = latest_version_opt.get();
		TvmCell account_params = abi.encode(
			dex_root_address,
			wever_root,
			tip3_to_ever_address,
			account_threshold,
			tvm.hash(latest_params.contractAbi)
		);
		Platform(msg.sender).initializeByRoot{
			value: 0,
			flag: MsgFlag.ALL_NOT_RESERVED
		}(latest_params.contractCode, account_params, latest_version);
	}

	function deployExternalSubscription(
		uint8 chain_id,
		string external_account_address,
		string external_payee,
		string external_token_address,
		address service_address,
		TvmCell identificator,
		uint256 owner_pubkey,
		uint8 subscription_plan,
		uint128 additional_gas
	) private view {
		if (additional_gas != 0) {
			additional_gas = additional_gas / 3;
		}
		address owner_account_address = address(
			tvm.hash(_buildAccountInitData(ContractTypes.Account, owner_pubkey))
		);
		TvmCell subsIndexStateInit = _buildSubscriptionIndex(
			service_address,
			owner_account_address
		);
		TvmCell subsIndexIdentificatorStateInit;
		if (!identificator.toSlice().empty()) {
			subsIndexIdentificatorStateInit = _buildSubscriptionIdentificatorIndex(
				service_address,
				identificator,
				owner_account_address
			);
		}
		TvmCell subscription_code_salt = _buildSubscriptionCode(owner_account_address);
		address subs_index = address(tvm.hash(subsIndexStateInit));
		address subs_index_identificator = address(
			tvm.hash(subsIndexIdentificatorStateInit)
		);
		optional(uint32, ContractParams) latest_version_opt = versions[
			ContractTypes.Subscription
		].max();
		(uint32 latest_version, ContractParams latest_version_params) = latest_version_opt.get();
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
			subscription_plan,
			identificator,
			tvm.hash(latest_version_params.contractAbi),
			true,
	        chain_id,
	        external_account_address,
	        external_token_address,
			external_payee,
			cross_chain_token
		);
		Platform platform = new Platform{
			stateInit: _buildInitData(
				ContractTypes.Subscription,
				_buildSubscriptionPlatformParams(owner_account_address, service_address)
			),
			value: EverduesGas.SUBSCRIPTION_INITIAL_BALANCE +
				EverduesGas.DEPLOY_SUBSCRIPTION_VALUE +
				EverduesGas.EXECUTE_SUBSCRIPTION_VALUE +
				additional_gas,
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
			value: EverduesGas.MESSAGE_MIN_VALUE + additional_gas,
			flag: MsgFlag.SENDER_PAYS_FEES,
			bounce: false,
			stateInit: subsIndexStateInit
		}(index_owner, msg.sender);
		if (!identificator.toSlice().empty()) {
			new Index{
				value: EverduesGas.MESSAGE_MIN_VALUE + additional_gas,
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
		tvm.rawReserve(
			math.max(
				EverduesGas.ROOT_INITIAL_BALANCE,
				address(this).balance - msg.value
			),
			2
		);
		if (additional_gas != 0) {
			additional_gas = additional_gas / 3;
		}
		TvmCell subsIndexStateInit = _buildSubscriptionIndex(
			service_address,
			msg.sender
		);
		TvmCell subsIndexIdentificatorStateInit;
		if (!identificator.toSlice().empty()) {
			subsIndexIdentificatorStateInit = _buildSubscriptionIdentificatorIndex(
				service_address,
				identificator,
				msg.sender
			);
		}
		TvmCell subscription_code_salt = _buildSubscriptionCode(msg.sender);
		address owner_account_address = address(
			tvm.hash(_buildAccountInitData(ContractTypes.Account, owner_pubkey))
		);
		address subs_index = address(tvm.hash(subsIndexStateInit));
		address subs_index_identificator = address(
			tvm.hash(subsIndexIdentificatorStateInit)
		);
		optional(uint32, ContractParams) latest_version_opt = versions[
			ContractTypes.Subscription
		].max();
		(uint32 latest_version, ContractParams latest_version_params) = latest_version_opt.get();
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
			subscription_plan,
			identificator,
			tvm.hash(latest_version_params.contractAbi),
			false,
			uint8(0),
			uint256(0),
			uint256(0),
			address(0)
		);
		Platform platform = new Platform{
			stateInit: _buildInitData(
				ContractTypes.Subscription,
				_buildSubscriptionPlatformParams(msg.sender, service_address)
			),
			value: EverduesGas.SUBSCRIPTION_INITIAL_BALANCE +
				EverduesGas.DEPLOY_SUBSCRIPTION_VALUE +
				EverduesGas.EXECUTE_SUBSCRIPTION_VALUE +
				additional_gas,
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
			value: EverduesGas.MESSAGE_MIN_VALUE + additional_gas,
			flag: MsgFlag.SENDER_PAYS_FEES,
			bounce: false,
			stateInit: subsIndexStateInit
		}(index_owner, msg.sender);
		if (!identificator.toSlice().empty()) {
			new Index{
				value: EverduesGas.MESSAGE_MIN_VALUE + additional_gas,
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
		address owner_address,
		TvmCell service_params_cell,
		TvmCell identificator,
		uint256 owner_pubkey,
		bool publish_to_catalog,
		uint128 additional_gas
	) private view returns (address) {
		if (additional_gas != 0) {
			additional_gas = additional_gas / 3;
		}
		(
			TvmCell service_params, /*TvmCell subscription_plans*/

		) = abi.decode(service_params_cell, (TvmCell, TvmCell));
		(
			,
			/*address account*/
			string service_name, /*string description*/ /*string image*/
			,
			,
			string category,
			,
		) = abi.decode(
				service_params,
				(address, string, string, string, string, uint256, string)
			);
		TvmCell service_code_salt;
		if (publish_to_catalog) {
			service_code_salt = _buildPublicServiceCode(category);
		} else {
			uint256 nonce = rnd.next();
			service_code_salt = _buildPrivateServiceCode(nonce);
		}
		TvmCell serviceIndexStateInit = _buildServiceIndex(
			owner_address,
			service_name
		);
		TvmCell serviceIdentificatorIndexStateInit;
		if (!identificator.toSlice().empty()) {
			serviceIdentificatorIndexStateInit = _buildServiceIdentificatorIndex(
				owner_address,
				identificator,
				address(
					tvm.hash(
						_buildInitData(
							ContractTypes.Service,
							_buildServicePlatformParams(
								owner_address,
								service_name
							)
						)
					)
				)
			);
		}
		optional(uint32, ContractParams) latest_version_opt = versions[
			ContractTypes.Service
		].max();
		(uint32 latest_version, ContractParams latest_version_params) = latest_version_opt.get();
		TvmCell additional_params = abi.encode(
			address(tvm.hash(serviceIndexStateInit)),
			address(tvm.hash(serviceIdentificatorIndexStateInit)),
			owner_pubkey,
			service_gas_compenstation,
			subscription_gas_compenstation,
			identificator,
			tvm.hash(latest_version_params.contractAbi)
		);
		TvmCell service_params_cell_with_additional_params = abi.encode(
			service_params_cell,
			additional_params
		);

		Platform platform = new Platform{
			stateInit: _buildInitData(
				ContractTypes.Service,
				_buildServicePlatformParams(owner_address, service_name)
			),
			value: EverduesGas.SERVICE_INITIAL_BALANCE + EverduesGas.MESSAGE_MIN_VALUE + additional_gas,
			flag: MsgFlag.SENDER_PAYS_FEES
		}(
			service_code_salt,
			service_params_cell_with_additional_params,
			latest_version,
			owner_address,
			0
		);
		TvmCell index_owner = abi.encode(address(platform));
		new Index{
			value: EverduesGas.MESSAGE_MIN_VALUE + additional_gas,
			flag: MsgFlag.SENDER_PAYS_FEES,
			bounce: false,
			stateInit: serviceIndexStateInit
		}(index_owner, owner_address);
		if (!identificator.toSlice().empty()) {
			new Index{
				value: EverduesGas.MESSAGE_MIN_VALUE + additional_gas,
				flag: MsgFlag.SENDER_PAYS_FEES,
				bounce: false,
				stateInit: serviceIdentificatorIndexStateInit
			}(index_owner, owner_address);
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
					sender,
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
				}(
					amount,
					service_address,
					EverduesGas.DEPLOY_EMPTY_WALLET_GRAMS,
					remainingGasTo,
					true,
					payload
				);
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
