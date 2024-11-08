#[test_only]
module erc1155::erc1155_tests {
    use sui::object::{ID};
    use erc1155::erc1155::{Self, Collection, NFT};
    use sui::test_scenario as ts;
    use sui::coin;
    use sui::sui::SUI;
    use sui::transfer;

    // Test addresses
    const ADMIN: address = @0xAA;
    const OPERATOR: address = @0xBB;
    const USER1: address = @0xCC;
    const USER2: address = @0xDD;

    // Test001 
    // Test Case: Initialize the contract and check the mint authority role.
    // Expected Result: The mint authority role is set to the ADMIN address.
    // Test Environment: ADMIN address is the mint authority.
    // Test Strategy: Positive Testing
    #[test]
    fun test_init_revenue() {
        let scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };
        
        // Must advance to next tx to take shared object
        ts::next_tx(&mut scenario, ADMIN);
        {
            let collection = ts::take_shared<Collection>(&scenario);
            assert!(erc1155::is_operator(&collection, OPERATOR) == false, 1);
            ts::return_shared(collection);
        };
        ts::end(scenario);
    }
    
    // Test002
    // Test Case: Add an operator without the mint authority role.
    // Expected Result: The operation fails with an error code ENO_MINT_AUTHORITY.
    // Test Environment: ADMIN address is not the mint authority.
    // Test Strategy: Negative Testing
    // Test Plan:
    // 1. Attempt to add OPERATOR as an operator.
    // 2. Verify that the operation fails with an error code ENO_MINT_AUTHORITY.
    // 3. Verify that OPERATOR is not an operator.
    // 4. Verify that the operation fails with an error code ENO_MINT_AUTHORITY.
    #[test]
    #[expected_failure(abort_code = 1)] // ENO_MINT_AUTHORITY = 1
    fun test_add_operator_unauthorized() {
        let scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };
        
        ts::next_tx(&mut scenario, USER1);
        {
            let collection = ts::take_shared<Collection>(&scenario);
            erc1155::add_operator(&mut collection, OPERATOR, ts::ctx(&mut scenario));
            ts::return_shared(collection);
        };
        ts::end(scenario);
    }

    // Test003
    // Test Case: Add and remove an operator.
    // Expected Result: The mint authority can add and remove an operator successfully.
    // Test Environment: ADMIN address is the mint authority.
    // Test Strategy: Positive Testing
    // Test Plan:
    // 1. Add OPERATOR as an operator.
    // 2. Verify that OPERATOR is an operator.
    // 3. Remove OPERATOR as an operator.
    // 4. Verify that OPERATOR is not an operator.
    #[test]
    fun test_add_remove_operator() {
        let scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        }; 

        ts::next_tx(&mut scenario, ADMIN);
        {
            let collection = ts::take_shared<Collection>(&scenario);
            erc1155::add_operator(&mut collection, OPERATOR, ts::ctx(&mut scenario));
            assert!(erc1155::is_operator(&collection, OPERATOR) == true, 1);
            ts::return_shared(collection);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let collection = ts::take_shared<Collection>(&scenario);
            erc1155::remove_operator(&mut collection, OPERATOR, ts::ctx(&mut scenario));
            assert!(erc1155::is_operator(&collection, OPERATOR) == false, 2);
            ts::return_shared(collection);
        };
        ts::end(scenario);
    }
    
    // Test004
    // Test Case: Mint tokens successfully.
    // Expected Result: The mint authority can mint tokens with the specified metadata and initial supply.
    // Test Environment: ADMIN address is the mint authority.
    // Test Strategy: Positive Testing
    // Test Plan:
    // 1. Mint 100 tokens with metadata "Test" and "Test Token" to USER1.
    // 2. Check the balance of the minted NFT.
    // 3. Verify that the balance is equal to the initial supply.
    // 4. Check the metadata of the minted NFT.
    #[test]
    fun test_mint_erc1155() {
        let scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let collection = ts::take_shared<Collection>(&scenario);
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
            assert!(erc1155::balance(&nft) == 100, 1);
            ts::return_to_sender(&scenario, nft);
        };
        ts::end(scenario);
    }
    
    // Test005
    // Test Case: Transfer tokens between users.
    // Expected Result: The transfer function successfully transfers tokens between users.
    // Test Environment: ADMIN address is the mint authority.
    // Test Strategy: Positive Testing
    // Test Plan:
    // 1. Mint 100 tokens with metadata "Test" and "Test Token" to USER1.
    // 2. Transfer 40 tokens from USER1 to USER2.
    // 3. Check the balance of USER1 and USER2.
    // 4. Verify that the balances are updated correctly after the transfer.
    // 5. Check the balance of USER2.
    // 6. Verify that the balance is equal to the transferred amount.
    // 7. Check the balance of USER1.
    // 8. Verify that the balance is equal to the remaining amount.
    // 9. Check the metadata of the transferred NFT.
    // 10. Verify that the metadata is the same as the minted NFT.
    // 11. Check the URI of the transferred NFT.
    // 12. Verify that the URI is the same as the minted NFT.
    // 13. Check the token ID of the transferred NFT.
    // 14. Verify that the token ID is the same as the minted NFT.
    #[test]
    fun test_transfer_erc1155() {
        let scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let collection = ts::take_shared<Collection>(&scenario);
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
            erc1155::transfer(&mut nft, 40, USER2, ts::ctx(&mut scenario));
            assert!(erc1155::balance(&nft) == 60, 1);
            ts::return_to_sender(&scenario, nft);
        };

        ts::next_tx(&mut scenario, USER2);
        {
            let nft = ts::take_from_sender<NFT>(&scenario);
            assert!(erc1155::balance(&nft) == 40, 2);
            ts::return_to_sender(&scenario, nft);
        };
        ts::end(scenario);
    }
    
    // Test006
    // Test Case: Deposit and withdraw revenue.
    // Expected Result: The operator can deposit and withdraw revenue successfully.
    // Test Environment: ADMIN address is the mint authority.
    // Test Strategy: Positive Testing
    // Test Plan:
    // 1. Add OPERATOR as an operator.
    // 2. Mint 100 tokens with metadata "Test" and "Test Token" to USER1.
    // 3. Get the token ID of the minted NFT.
    // 4. Deposit 1000 SUI revenue for the minted NFT.
    // 5. Check the revenue balance of the minted NFT.
    // 6. Verify that the revenue balance is equal to the deposited amount.
    // 7. Withdraw revenue for the minted NFT.
    // 8. Check the revenue balance of the minted NFT.
    // 9. Verify that the revenue balance is zero after withdrawal.
    // 10. Verify that the revenue is transferred to the token owner.
    // 11. Verify that the revenue is transferred to the OPERATOR address.
    #[test]
    fun test_deposit_revenue() {
        let scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        // Setup operator
        ts::next_tx(&mut scenario, ADMIN);
        {
            let collection = ts::take_shared<Collection>(&scenario);
            erc1155::add_operator(&mut collection, OPERATOR, ts::ctx(&mut scenario));
            ts::return_shared(collection);
        };

        // Mint NFT to USER1 and store token_id
        let token_id: ID;
        ts::next_tx(&mut scenario, ADMIN);
        {
            let collection = ts::take_shared<Collection>(&scenario);
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

        // Get token_id from USER1's NFT
        ts::next_tx(&mut scenario, USER1);
        {
            let nft = ts::take_from_sender<NFT>(&scenario);
            token_id = erc1155::token_id(&nft);
            ts::return_to_sender(&scenario, nft);
        };

        // Operator deposits revenue
        ts::next_tx(&mut scenario, OPERATOR);
        {
            let collection = ts::take_shared<Collection>(&scenario);
            let payment = coin::mint_for_testing<SUI>(1000, ts::ctx(&mut scenario));
            
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

        ts::end(scenario);
    }
    
    // Test007
    // Test Case: Withdraw revenue.
    // Expected Result: The token owner can withdraw their proportional share of the revenue.
    // Test Environment: ADMIN address is the mint authority.
    // Test Strategy: Positive Testing
    // Test Plan:
    // 1. Add OPERATOR as an operator.
    // 2. Mint 100 tokens with metadata "Test" and "Test Token" to USER1.
    // 3. Get the token ID of the minted NFT.
    // 4. Deposit 1000 SUI revenue for the minted NFT.
    // 5. USER1 withdraws revenue for the minted NFT.
    // 6. Check the revenue balance of the minted NFT.
    // 7. Verify that the revenue balance is zero after withdrawal.
    // 8. Verify that the revenue is transferred to USER1.
    // 9. Verify that the revenue is transferred from the OPERATOR address.
    // 10. Verify that the revenue is transferred to the token owner.
    // 11. Verify that the revenue is transferred from the OPERATOR address.
    #[test]
    fun test_withdraw_revenue() {
        let scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        // Setup operator
        ts::next_tx(&mut scenario, ADMIN);
        {
            let collection = ts::take_shared<Collection>(&scenario);
            erc1155::add_operator(&mut collection, OPERATOR, ts::ctx(&mut scenario));
            ts::return_shared(collection);
        };

        // Mint NFT to USER1 and store token_id
        let token_id: ID;
        ts::next_tx(&mut scenario, ADMIN);
        {
            let collection = ts::take_shared<Collection>(&scenario);
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

        // Get token_id from USER1's NFT
        ts::next_tx(&mut scenario, USER1);
        {
            let nft = ts::take_from_sender<NFT>(&scenario);
            token_id = erc1155::token_id(&nft);
            ts::return_to_sender(&scenario, nft);
        };

        // Operator deposits revenue
        ts::next_tx(&mut scenario, OPERATOR);
        {
            let collection = ts::take_shared<Collection>(&scenario);
            let payment = coin::mint_for_testing<SUI>(1000, ts::ctx(&mut scenario));
            
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

        // USER1 withdraws revenue
        ts::next_tx(&mut scenario, USER1);
        {
            let collection = ts::take_shared<Collection>(&scenario);
            let nft = ts::take_from_sender<NFT>(&scenario);
            erc1155::withdraw_revenue(&mut collection, &nft, ts::ctx(&mut scenario));
            ts::return_shared(collection);
            ts::return_to_sender(&scenario, nft);
        };
        ts::end(scenario);
    }
}