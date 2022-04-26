pragma ton-solidity >=0.56.0;

library DexOperationTypes {
	uint8 constant EXCHANGE = 1;
	uint8 constant DEPOSIT_LIQUIDITY = 2;
	uint8 constant WITHDRAW_LIQUIDITY = 3;
	uint8 constant CROSS_PAIR_EXCHANGE = 4;
}
