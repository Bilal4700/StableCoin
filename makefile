-include .env

.PHONY: install  run-test deploy

install:; forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 && forge install transmissions11/solmate@v6 && forge install Cyfrin/foundry-devops && forge install transmissions11/solmate@v6

build:; forge build




# Target that runs the given test
run-test:
	forge test --match-test $(NAME) -vvvv

deploy-sepolia:
	@forge script script/DeployRaffle.s.sol:DeployRaffle --broadcast --rpc-url $(SEPOLIA_RPC_URL) --account myaccount --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
 