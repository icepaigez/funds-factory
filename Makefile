-include .env

build:; forge build

sepolia-deploy:
	forge script script/DeployFundFactory.s.sol:DeployFundFactory --rpc-url $(OP_SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(OP_ETHERSCAN_API_KEY) -vvvv