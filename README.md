# Stocksd.app Solidity contracts monorepo
### built with Truffle, oz and Chainlink

## Contribution Guide (gitflow)

Current agenda is represented in the form of project cards (https://github.com/stocksdapp/contracts/projects/1) and issues (https://github.com/stocksdapp/contracts/issues), which are discussed in our Discord server (relevant link can be found on https://stocksd.app)

1) Developer clones the repo locally, checks out a new branch based on master, naming it `ISSUE_NUM/some-description`, e.g. for the third issue in this repo a branch name can be `3/add-gitflow-something-else`

2) When it's ready to be merged, the developer pushes it to remote and opens a new PR against master

3) 1 approving review is required before a pull request can be merged (we use squash and merge workflow powered by GH merge button)

## Testing (Ropsten)

### Existing Ropsten contracts 

- Ropsten Exchange (main): `0x14adC323328fAC6D01F9af83720C10b8Ed2F3a80`
- Ropsten Token (linked to Exchange): `0x1E9da3d650AC02D4f65f8ae0D655347Ab9FF63fa`
- Ropsten DAI: `0xc2118d4d90b274016cB7a54c03EF52E6c537D957`
- Ropsten LINK:  `0x20fe562d797a42dcb3399062ae9546cd06f63280`
- Ropsten oracle (node down):  `0xd3d4f566b8e0de2dcde877b1954c2d759cc395a6`
- Ropsten tickerJobIdString: `51df1946d454408b90f15530d35c134a`

### Launching Ropsten Truffle tests with Infura (E2E test)

1. Setup `.env` file with `MNEMONIC` and `INFURA_ID`
2. Obtain testnet LINK (https://ropsten.chain.link/) and DAI (https://app.compound.finance/). E2E test uses first two accounts from `MNEMONIC` wallet and consumes 300 DAI and 10 LINK from first account and about 2000 DAI from second account, depending on $TSLA price returned by testnet oracle
3. Run `truffle test --network ropsten` 

For running on other testnets and general documentation refer to https://www.trufflesuite.com/docs/truffle/quickstart
