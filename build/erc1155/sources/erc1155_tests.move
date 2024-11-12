// SPDX-License-Identifier: MIT
#[test_only]
module erc1155::erc1155_tests {
    use erc1155::erc1155::{Self, Collection, NFT};
    use sui::test_scenario as ts;
    use sui::coin;
    use sui::sui::SUI;

    /* Test Addresses */
    const ADMIN: address = @0xAA; 
    const OPERATOR: address = @0xBB;
    const USER1: address = @0xCC;
    const USER2: address = @0xDD;

    /* Error codes */
    const ASSERTION_FAILED: u64 = 0;

    /*
    * @notice Test initialization of collection
    * Test Scenario:
    * 1. Deploy contract from ADMIN
    * 2. Verify OPERATOR is not registered
    */
    #[test]
    fun test_init_collection() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            let collection = ts::take_shared<Collection>(&scenario);
            assert!(erc1155::is_operator(&collection, OPERATOR) == false, ASSERTION_FAILED);
            ts::return_shared(collection);
        };
        ts::end(scenario);
    }

    /*
    * @notice Test unauthorized operator addition
    * Test Scenario:
    * 1. Deploy contract from ADMIN
    * 2. Try to add operator from USER1 (should fail)
    * Expected: Failure with ENO_MINT_AUTHORITY
    */
    #[test]
    #[expected_failure(abort_code = erc1155::ENO_MINT_AUTHORITY)]
    fun test_add_operator_unauthorized() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };
        
        ts::next_tx(&mut scenario, USER1);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::add_operator(&mut collection, OPERATOR, ts::ctx(&mut scenario));
            ts::return_shared(collection);
        };
        ts::end(scenario);
    }

    /*
    * @notice Test operator addition and removal
    * Test Scenario:
    * 1. Deploy contract and add operator
    * 2. Verify operator status
    * 3. Remove operator
    * 4. Verify removal
    */
    #[test]
    fun test_add_remove_operator() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        }; 

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::add_operator(&mut collection, OPERATOR, ts::ctx(&mut scenario));
            assert!(erc1155::is_operator(&collection, OPERATOR) == true, ASSERTION_FAILED);
            ts::return_shared(collection);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::remove_operator(&mut collection, OPERATOR, ts::ctx(&mut scenario));
            assert!(erc1155::is_operator(&collection, OPERATOR) == false, ASSERTION_FAILED);
            ts::return_shared(collection);
        };
        ts::end(scenario);
    }

    /*
    * @notice Test token minting
    * Test Scenario:
    * 1. Deploy contract from ADMIN
    * 2. Mint 100 tokens to USER1
    * 3. Verify USER1's balance is 100
    */
    #[test]
    fun test_mint() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::mint(
                &mut collection,
                b"Test",
                b"Test Token",
                b"https://test.uri",
                100,
                USER1,
                ts::ctx(&mut scenario)
            );
            ts::return_shared(collection);
        };

        ts::next_tx(&mut scenario, USER1);
        {
            let nft = ts::take_from_sender<NFT>(&scenario);
            assert!(erc1155::balance(&nft) == 100, ASSERTION_FAILED);
            ts::return_to_sender(&scenario, nft);
        };
        ts::end(scenario);
    }

    /*
    * @notice Test successful token transfer
    * Test Scenario:
    * 1. Deploy contract
    * 2. Mint tokens to USER1
    * 3. Transfer tokens to USER2
    * 4. Verify balances
    */
    #[test]
    fun test_transfer() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        // Mint tokens to USER1
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::mint(
                &mut collection,
                b"Test",
                b"Test Token",
                b"https://test.uri",
                100,
                USER1,
                ts::ctx(&mut scenario)
            );
            ts::return_shared(collection);
        };

        // Transfer tokens from USER1 to USER2
        ts::next_tx(&mut scenario, USER1);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut nft = ts::take_from_sender<NFT>(&scenario);
            erc1155::transfer(
                &mut collection,
                &mut nft,
                40,
                USER2,
                ts::ctx(&mut scenario)
            );
            assert!(erc1155::balance(&nft) == 60, ASSERTION_FAILED);
            ts::return_shared(collection);
            ts::return_to_sender(&scenario, nft);
        };

        // Verify USER2's balance
        ts::next_tx(&mut scenario, USER2);
        {
            let nft = ts::take_from_sender<NFT>(&scenario);
            assert!(erc1155::balance(&nft) == 40, ASSERTION_FAILED);
            ts::return_to_sender(&scenario, nft);
        };
        ts::end(scenario);
    }

    /*
    * @notice Test successful revenue withdrawal
    * Test Scenario:
    * 1. Deploy contract and setup operator
    * 2. Mint tokens and deposit revenue
    * 3. Withdraw revenue once
    */
    #[test]
    fun test_withdraw_success() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        // Setup operator
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::add_operator(&mut collection, OPERATOR, ts::ctx(&mut scenario));
            ts::return_shared(collection);
        };

        // Mint tokens and get token_id
        let token_id: ID;
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::mint(
                &mut collection,
                b"Test",
                b"Test Token",
                b"https://test.uri",
                100,
                USER1,
                ts::ctx(&mut scenario)
            );
            ts::return_shared(collection);
        };

        // Get token ID
        ts::next_tx(&mut scenario, USER1);
        {
            let nft = ts::take_from_sender<NFT>(&scenario);
            token_id = erc1155::token_id(&nft);
            ts::return_to_sender(&scenario, nft);
        };

        // Deposit revenue
        ts::next_tx(&mut scenario, OPERATOR);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut payment = coin::mint_for_testing<SUI>(1000, ts::ctx(&mut scenario));
            
            erc1155::deposit_revenue(
                &mut collection,
                token_id,
                &mut payment,
                1000,
                ts::ctx(&mut scenario)
            );

            assert!(erc1155::get_revenue_balance(&collection, token_id) == 1000, ASSERTION_FAILED);
            ts::return_shared(collection);
            transfer::public_transfer(payment, OPERATOR);
        };

        // Withdraw revenue
        ts::next_tx(&mut scenario, USER1);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut nft = ts::take_from_sender<NFT>(&scenario);
            erc1155::withdraw_revenue(&mut collection, &mut nft, ts::ctx(&mut scenario));
            ts::return_shared(collection);
            ts::return_to_sender(&scenario, nft);
        };

        ts::end(scenario);
    }

    /*
    * @notice Test revenue withdrawal failure case
    * Test Scenario:
    * 1. Setup same as test_withdraw_success
    * 2. Attempt second withdrawal (should fail)
    */
    #[test]
    #[expected_failure(abort_code = erc1155::ENO_NEW_REVENUE)]
    fun test_double_withdrawal() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        // Setup operator
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::add_operator(&mut collection, OPERATOR, ts::ctx(&mut scenario));
            ts::return_shared(collection);
        };

        // Mint tokens and get token_id
        let token_id: ID;
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::mint(
                &mut collection,
                b"Test",
                b"Test Token",
                b"https://test.uri",
                100,
                USER1,
                ts::ctx(&mut scenario)
            );
            ts::return_shared(collection);
        };

        // Get token ID
        ts::next_tx(&mut scenario, USER1);
        {
            let nft = ts::take_from_sender<NFT>(&scenario);
            token_id = erc1155::token_id(&nft);
            ts::return_to_sender(&scenario, nft);
        };

        // Deposit revenue
        ts::next_tx(&mut scenario, OPERATOR);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut payment = coin::mint_for_testing<SUI>(1000, ts::ctx(&mut scenario));
            
            erc1155::deposit_revenue(
                &mut collection,
                token_id,
                &mut payment,
                1000,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(collection);
            transfer::public_transfer(payment, OPERATOR);
        };

        // First withdrawal
        ts::next_tx(&mut scenario, USER1);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut nft = ts::take_from_sender<NFT>(&scenario);
            erc1155::withdraw_revenue(&mut collection, &mut nft, ts::ctx(&mut scenario));
            ts::return_shared(collection);
            ts::return_to_sender(&scenario, nft);
        };

        // Second withdrawal (should fail)
        ts::next_tx(&mut scenario, USER1);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut nft = ts::take_from_sender<NFT>(&scenario);
            erc1155::withdraw_revenue(&mut collection, &mut nft, ts::ctx(&mut scenario));
            ts::return_shared(collection);
            ts::return_to_sender(&scenario, nft);
        };

        ts::end(scenario);
    }
}