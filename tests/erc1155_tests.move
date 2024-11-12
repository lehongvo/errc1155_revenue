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
   // Expected Result: The mint authority can mint tokens with metadata and initial supply.
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
   // Expected Result: Transfer function successfully transfers tokens between users.
   // Test Environment: ADMIN address is the mint authority.
   // Test Strategy: Positive Testing
   // Test Plan:  
   // 1. Mint 100 tokens to USER1
   // 2. Transfer 40 tokens from USER1 to USER2
   // 3. Check balances are updated correctly
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
   // Test Case: Deposit revenue as operator.
   // Expected Result: Operator can successfully deposit revenue.
   // Test Environment: ADMIN address is the mint authority, OPERATOR is operator.
   // Test Strategy: Positive Testing
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
   // Test Case: Withdraw revenue
   // Expected Result: Token holder can withdraw their proportional share.
   // Test Environment: ADMIN is mint authority, USER1 is holder
   // Test Strategy: Positive Testing
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
           erc1155::withdraw_revenue(&mut collection, &mut nft, ts::ctx(&mut scenario));
           
           // Verify last_withdrawn_revenue is updated
           assert!(erc1155::get_last_withdrawn_revenue(&nft) == 1000, 1);
           
           ts::return_shared(collection);
           ts::return_to_sender(&scenario, nft);
       };
       ts::end(scenario);
   }

   // Test008
   // Test Case: Prevent double withdrawal of same revenue 
   // Expected Result: Second withdrawal should fail with ENO_NEW_REVENUE
   // Test Environment: USER1 attempts to withdraw twice
   // Test Strategy: Negative Testing
   #[test]
   #[expected_failure(abort_code = erc1155::ENO_NEW_REVENUE)]
   fun test_prevent_double_withdrawal() {
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

       // First withdrawal - should succeed
       ts::next_tx(&mut scenario, USER1);
       {
           let collection = ts::take_shared<Collection>(&scenario);
           let nft = ts::take_from_sender<NFT>(&scenario);
           erc1155::withdraw_revenue(&mut collection, &mut nft, ts::ctx(&mut scenario));
           ts::return_shared(collection);
           ts::return_to_sender(&scenario, nft);
       };

       // Second withdrawal - should fail
       ts::next_tx(&mut scenario, USER1);
       {
           let collection = ts::take_shared<Collection>(&scenario);
           let nft = ts::take_from_sender<NFT>(&scenario);
           erc1155::withdraw_revenue(&mut collection, &mut nft, ts::ctx(&mut scenario));
           ts::return_shared(collection);
           ts::return_to_sender(&scenario, nft);
       };
       ts::end(scenario);
   }

   // Test009  
   // Test Case: Test withdrawal tracking through transfers
   // Expected Result: NFT withdrawal history persists through transfers 
   // Test Environment: Transfer NFT between users after withdrawal
   // Test Strategy: Positive Testing
   #[test]
   fun test_transfer_withdrawal_tracking() {
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

        // Mint NFT to USER1
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

        // Get token_id
        ts::next_tx(&mut scenario, USER1);
        {
            let nft = ts::take_from_sender<NFT>(&scenario);
            token_id = erc1155::token_id(&nft);
            ts::return_to_sender(&scenario, nft);
        };

        // Deposit 1000 SUI
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

        // USER1 withdraws and transfers to USER2
        ts::next_tx(&mut scenario, USER1);  
        {
            let collection = ts::take_shared<Collection>(&scenario);
            let nft = ts::take_from_sender<NFT>(&scenario);
            erc1155::withdraw_revenue(&mut collection, &mut nft, ts::ctx(&mut scenario));
            
            // Save withdrawal history before transfer
            let last_withdrawn = erc1155::get_last_withdrawn_revenue(&nft);
            assert!(last_withdrawn == 1000, 1);
            
            // Transfer half to USER2
            erc1155::transfer(&mut nft, 50, USER2, ts::ctx(&mut scenario));
            ts::return_shared(collection);
            ts::return_to_sender(&scenario, nft);
        };
        
        // Verify USER2's NFT has inherited withdrawal history
        ts::next_tx(&mut scenario, USER2);
        {  
            let nft = ts::take_from_sender<NFT>(&scenario);
            assert!(erc1155::get_last_withdrawn_revenue(&nft) == 1000, 2);
            ts::return_to_sender(&scenario, nft);
        };
        ts::end(scenario);
    }

    // Test010
    // Test Case: Test withdrawal after multiple deposits
    // Expected Result: Can only withdraw new revenue
    // Test Environment: Multiple deposits and withdrawals
    // Test Strategy: Positive Testing
    #[test]
    fun test_multiple_deposits_withdrawal() {
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

        // Mint NFT to USER1 
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

        // Get token_id
        ts::next_tx(&mut scenario, USER1);
        {
            let nft = ts::take_from_sender<NFT>(&scenario);
            token_id = erc1155::token_id(&nft);
            ts::return_to_sender(&scenario, nft);
        };

        // First deposit - 1000 SUI
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

        // First withdrawal
        ts::next_tx(&mut scenario, USER1);
        {
            let collection = ts::take_shared<Collection>(&scenario);
            let nft = ts::take_from_sender<NFT>(&scenario);
            erc1155::withdraw_revenue(&mut collection, &mut nft, ts::ctx(&mut scenario));
            
            // Should be 1000 after first withdrawal
            assert!(erc1155::get_last_withdrawn_revenue(&nft) == 1000, 1);
            
            ts::return_shared(collection);
            ts::return_to_sender(&scenario, nft);
        };

        // Second deposit - 500 SUI
        ts::next_tx(&mut scenario, OPERATOR);
        {
            let collection = ts::take_shared<Collection>(&scenario);
            let payment = coin::mint_for_testing<SUI>(500, ts::ctx(&mut scenario));
            
            erc1155::deposit_revenue(
                &mut collection,
                token_id,
                &mut payment,
                500,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(collection);
            transfer::public_transfer(payment, OPERATOR);
        };

        // Second withdrawal - only new revenue
        ts::next_tx(&mut scenario, USER1);
        {
            let collection = ts::take_shared<Collection>(&scenario);
            let nft = ts::take_from_sender<NFT>(&scenario);
            erc1155::withdraw_revenue(&mut collection, &mut nft, ts::ctx(&mut scenario));
            
            // Should be 1500 after second withdrawal (1000 + 500)
            assert!(erc1155::get_last_withdrawn_revenue(&nft) == 1500, 2);
            
            ts::return_shared(collection);
            ts::return_to_sender(&scenario, nft);
        };

        ts::end(scenario);
    }
}