# ERC-1155-style NFT on Sui

This repository contains an implementation of an ERC-1155-style NFT contract on the Sui blockchain using the Move programming language. The contract supports token minting, transfers, revenue deposit, and revenue withdrawal functionalities.

## Prerequisites

Before getting started, ensure you have the following prerequisites installed:

- [Sui CLI](https://docs.sui.io/build/install#install-sui-binaries)
- [Move compiler](https://docs.sui.io/build/move/install)

## Building the Contract

To build the ERC-1155-style NFT contract, follow these steps:

1. Clone this repository:
   To build the erc1155_revenue NFT contract, follow these steps:

```sh
   git clone https://github.com/lehongvo/erc1155_revenue.git
   cd erc1155_revenue
```

2. Compile the contract using the Move compiler:

```sh
   sui move build
```

This command will compile the erc1155_revenue contract-module and generate the compiled binary in the build directory.

## Testing the Contract

The contract includes a comprehensive set of test cases to verify its functionality. To run the tests, follow these steps:

1. Execute the test cases using the Sui CLI

```sh
   sui move test
```

This command will run all the test cases defined in the erc1155_tests.move module and display the test results.
Review the test output to ensure that all test cases pass successfully.

## Deploying the Contract Locally

To deploy the ERC-1155-style NFT contract locally using the Sui CLI, follow these steps:

### Deploy the contract at localhost

1. Start a local Sui network(Open another terminal)

```sh
   sui start
```

This command will start a local Sui network on your machine.

2. Deploy the contract

```sh
   sui client publish --gas-budget 300000000
```

This command will publish the erc1155_revenue module to the local Sui network.

### Deploy the contract at devnet

To deploy the ERC-1155 NFT contract on the Sui devnet, follow these steps:

1. Check the available network environments.

```sh
   sui client envs
```

This command will display the list of configured network environments.

2. Switch to the devnet environment

```sh
   sui client switch --env devnet
```

3. Create a new account(Node that, after create new account, please transfer SUI devnet to new account)

```sh
   sui client new-address ed25519
```

4. Switch to account just new created

```sh
   sui client switch --address <<ADDRESS>>
```

5. Deploy the contract

```sh
   sui client publish --gas-budget 300000000
```
