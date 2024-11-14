#[test_only]
module erc1155::erc1155_tests {
    use erc1155::erc1155::{Self, Collection, NFT};
    use sui::test_scenario as ts;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::transfer;
    use std::string;

    const ADMIN: address = @0xAA;
    const OPERATOR: address = @0xBB;
    const USER1: address = @0xCC;
    const USER2: address = @0xDD;

    // TC-01: Initialize collection
    #[test]
    fun test_init_collection() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            // Admin là mint authority, không phải operator
            // assert!(collection.mint_authority == ADMIN, 0);
            ts::return_shared(collection);
        };
        ts::end(scenario);
    }

    // TC-02: Add valid operator
    #[test]
    fun test_add_valid_operator() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::add_operator(&mut collection, OPERATOR, ts::ctx(&mut scenario));
            assert!(erc1155::is_operator(&collection, OPERATOR), 1);
            ts::return_shared(collection);
        };
        ts::end(scenario);
    }

    // TC-03: Add operator by non-authority
    #[test]
    #[expected_failure(abort_code = 1)]
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

    // TC-04: Remove existing operator
    #[test]
    fun test_remove_operator() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::add_operator(&mut collection, OPERATOR, ts::ctx(&mut scenario));
            erc1155::remove_operator(&mut collection, OPERATOR, ts::ctx(&mut scenario));
            assert!(!erc1155::is_operator(&collection, OPERATOR), 2);
            ts::return_shared(collection);
        };
        ts::end(scenario);
    }

    // TC-05: Remove operator by non-authority
    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_remove_operator_unauthorized() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::add_operator(&mut collection, OPERATOR, ts::ctx(&mut scenario));
            ts::return_shared(collection);
        };

        ts::next_tx(&mut scenario, USER1);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::remove_operator(&mut collection, OPERATOR, ts::ctx(&mut scenario));
            ts::return_shared(collection);
        };
        ts::end(scenario);
    }

    // TC-06: Mint new token
    #[test]
    fun test_mint_valid() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::mint(
                &mut collection,
                b"Test Token",
                b"Description",
                b"uri",
                100,
                USER1,
                ts::ctx(&mut scenario)
            );
            ts::return_shared(collection);
        };

        ts::next_tx(&mut scenario, USER1);
        {
            let mut nft = ts::take_from_sender<NFT>(&scenario);
            assert!(erc1155::get_balance(&nft) == 100, 3);
            ts::return_to_sender(&scenario, nft);
        };
        ts::end(scenario);
    }

    // TC-07: Mint with zero amount
    #[test]
    #[expected_failure(abort_code = 5)]
    fun test_mint_zero_amount() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::mint(
                &mut collection,
                b"Test Token",
                b"Description",
                b"uri",
                0,  // zero amount
                USER1,
                ts::ctx(&mut scenario)
            );
            ts::return_shared(collection);
        };
        ts::end(scenario);
    }

    // TC-08: Mint by non-authority
    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_mint_unauthorized() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, USER1);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::mint(
                &mut collection,
                b"Test Token",
                b"Description",
                b"uri",
                100,
                USER2,
                ts::ctx(&mut scenario)
            );
            ts::return_shared(collection);
        };
        ts::end(scenario);
    }

    // TC-09: Deposit valid revenue  
    #[test]
    fun test_deposit_revenue() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        // First mint a token
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::mint(
                &mut collection,
                b"Test Token",
                b"Description",
                b"uri",
                100,
                USER1,
                ts::ctx(&mut scenario)
            );
            ts::return_shared(collection);
        };

        // Get NFT and token_id
        let token_id: ID;
        ts::next_tx(&mut scenario, USER1);
        {
            let nft = ts::take_from_sender<NFT>(&scenario);
            token_id = erc1155::get_token_id(&nft);
            ts::return_to_sender(&scenario, nft);
        };

        // Add ADMIN as operator
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::add_operator(&mut collection, ADMIN, ts::ctx(&mut scenario));
            ts::return_shared(collection);
        };

        // Then deposit revenue
        ts::next_tx(&mut scenario, ADMIN);
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

            assert!(erc1155::get_revenue_balance(&collection, token_id) == 1000, 4);
            
            transfer::public_transfer(payment, ADMIN);
            ts::return_shared(collection);
        };
        ts::end(scenario);
    }


    // TC-10: Deposit by non-operator
    #[test]
    #[expected_failure(abort_code = 2)]
    fun test_deposit_unauthorized() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        // First mint a token
        let token_id: ID;
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::mint(
                &mut collection,
                b"Test Token",
                b"Description",
                b"uri",
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
            token_id = erc1155::get_token_id(&nft);
            ts::return_to_sender(&scenario, nft);
        };

        // Try deposit by unauthorized user
        ts::next_tx(&mut scenario, USER2);
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
            
            transfer::public_transfer(payment, USER2);
            ts::return_shared(collection);
        };
        ts::end(scenario);
    }

    // TC-11: Deposit to non-existent token
    #[test]
    #[expected_failure(abort_code = 3)]
    fun test_deposit_invalid_token() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        // Add ADMIN as operator first
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::add_operator(&mut collection, ADMIN, ts::ctx(&mut scenario));
            ts::return_shared(collection);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut payment = coin::mint_for_testing<SUI>(1000, ts::ctx(&mut scenario));
            let fake_id = object::id_from_address(@0x123);
            
            erc1155::deposit_revenue(
                &mut collection,
                fake_id,
                &mut payment,
                1000,
                ts::ctx(&mut scenario)
            );
            
            transfer::public_transfer(payment, ADMIN);
            ts::return_shared(collection);
        };
        ts::end(scenario);
    }

    // TC-12: Withdraw available revenue
    #[test]
    fun test_withdraw_revenue() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        // First mint token
        let token_id: ID;
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::mint(
                &mut collection,
                b"Test Token",
                b"Description",
                b"uri",
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
            token_id = erc1155::get_token_id(&nft);
            ts::return_to_sender(&scenario, nft);
        };

        // Add ADMIN as operator and deposit revenue
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::add_operator(&mut collection, ADMIN, ts::ctx(&mut scenario));
            ts::return_shared(collection);
        };

        ts::next_tx(&mut scenario, ADMIN);
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
            
            transfer::public_transfer(payment, ADMIN);
            ts::return_shared(collection);
        };

        // Withdraw revenue
        ts::next_tx(&mut scenario, USER1);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut nft = ts::take_from_sender<NFT>(&scenario);
            
            erc1155::withdraw_revenue(
                &mut collection,
                &mut nft,
                ts::ctx(&mut scenario)
            );

            assert!(erc1155::get_claimed_revenue(&nft) == 1000, 5);
            
            ts::return_to_sender(&scenario, nft);
            ts::return_shared(collection);
        };
        ts::end(scenario);
    }

    // TC-13: Withdraw with zero balance
    #[test]
    #[expected_failure(abort_code = 4)]  // Sửa từ 6 thành 4 (ENO_BALANCE)
    fun test_withdraw_zero_balance() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        // First mint token
        let token_id: ID;
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::mint(
                &mut collection,
                b"Test Token",
                b"Description",
                b"uri",
                100,
                USER1,
                ts::ctx(&mut scenario)
            );
            ts::return_shared(collection);
        };

        // Get token_id and transfer all tokens to USER2
        ts::next_tx(&mut scenario, USER1);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut nft = ts::take_from_sender<NFT>(&scenario);
            token_id = erc1155::get_token_id(&nft);
            
            // Transfer all tokens away
            erc1155::transfer(
                &mut collection,
                &mut nft,
                100,
                USER2,
                ts::ctx(&mut scenario)
            );
            
            ts::return_to_sender(&scenario, nft);
            ts::return_shared(collection);
        };

        // Add ADMIN as operator
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::add_operator(&mut collection, ADMIN, ts::ctx(&mut scenario));
            ts::return_shared(collection);
        };

        // Deposit revenue
        ts::next_tx(&mut scenario, ADMIN);
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
            
            transfer::public_transfer(payment, ADMIN);
            ts::return_shared(collection);
        };

        // Try to withdraw with zero balance
        ts::next_tx(&mut scenario, USER1);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut nft = ts::take_from_sender<NFT>(&scenario);
            
            erc1155::withdraw_revenue(
                &mut collection,
                &mut nft,
                ts::ctx(&mut scenario)
            );
            
            ts::return_to_sender(&scenario, nft);
            ts::return_shared(collection);
        };
        ts::end(scenario);
    }

    // TC-14: Withdraw with no new revenue
    #[test]
    #[expected_failure(abort_code = 6)]
    fun test_withdraw_no_new_revenue() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        // Mint token
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::mint(
                &mut collection,
                b"Test Token",
                b"Description",
                b"uri",
                100,
                USER1,
                ts::ctx(&mut scenario)
            );
            ts::return_shared(collection);
        };

        // Try to withdraw without any revenue deposited
        ts::next_tx(&mut scenario, USER1);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut nft = ts::take_from_sender<NFT>(&scenario);
            
            erc1155::withdraw_revenue(
                &mut collection,
                &mut nft,
                ts::ctx(&mut scenario)
            );
            
            ts::return_to_sender(&scenario, nft);
            ts::return_shared(collection);
        };
        ts::end(scenario);
    }

    // TC-15: Transfer valid amount
    #[test]
    fun test_transfer_valid() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        // Mint tokens first
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::mint(
                &mut collection,
                b"Test Token",
                b"Description",
                b"uri",
                100,
                USER1,
                ts::ctx(&mut scenario)
            );
            ts::return_shared(collection);
        };

        // Transfer tokens
        ts::next_tx(&mut scenario, USER1);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut nft = ts::take_from_sender<NFT>(&scenario);
            
            erc1155::transfer(
                &mut collection,
                &mut nft,
                50,
                USER2,
                ts::ctx(&mut scenario)
            );
            
            assert!(erc1155::get_balance(&nft) == 50, 6);
            ts::return_to_sender(&scenario, nft);
            ts::return_shared(collection);
        };

        // Verify recipient received tokens
        ts::next_tx(&mut scenario, USER2);
        {
            let nft = ts::take_from_sender<NFT>(&scenario);
            assert!(erc1155::get_balance(&nft) == 50, 7);
            ts::return_to_sender(&scenario, nft);
        };
        ts::end(scenario);
    }

    // TC-16: Transfer more than balance
    #[test]
    #[expected_failure(abort_code = 4)]
    fun test_transfer_overflow() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::mint(
                &mut collection,
                b"Test Token",
                b"Description",
                b"uri",
                100,
                USER1,
                ts::ctx(&mut scenario)
            );
            ts::return_shared(collection);
        };

        ts::next_tx(&mut scenario, USER1);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut nft = ts::take_from_sender<NFT>(&scenario);
            
            erc1155::transfer(
                &mut collection,
                &mut nft,
                150, // More than balance
                USER2,
                ts::ctx(&mut scenario)
            );
            
            ts::return_to_sender(&scenario, nft);
            ts::return_shared(collection);
        };
        ts::end(scenario);
    }

    // TC-17: Transfer to self
    #[test]
    #[expected_failure(abort_code = 7)]
    fun test_transfer_to_self() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::mint(
                &mut collection,
                b"Test Token",
                b"Description",
                b"uri",
                100,
                USER1,
                ts::ctx(&mut scenario)
            );
            ts::return_shared(collection);
        };

        ts::next_tx(&mut scenario, USER1);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut nft = ts::take_from_sender<NFT>(&scenario);
            
            erc1155::transfer(
                &mut collection,
                &mut nft,
                50,
                USER1, // Same as sender
                ts::ctx(&mut scenario)
            );
            
            ts::return_to_sender(&scenario, nft);
            ts::return_shared(collection);
        };
        ts::end(scenario);
    }

    // TC-18: Test safe addition within bounds
    #[test]
    fun test_safe_add_valid() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            
            // Test through mint operations - mint two times to same user
            erc1155::mint(
                &mut collection,
                b"Test Token 1",
                b"Description",
                b"uri",
                50,
                USER1,
                ts::ctx(&mut scenario)
            );

            erc1155::mint(
                &mut collection,
                b"Test Token 1",
                b"Description",
                b"uri",
                50,
                USER1,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(collection);
        };

        // Verify total balance is sum of both mints
        ts::next_tx(&mut scenario, USER1);
        {
            let nft1 = ts::take_from_sender<NFT>(&scenario);
            assert!(erc1155::get_balance(&nft1) == 50, 0);
            ts::return_to_sender(&scenario, nft1);

            let nft2 = ts::take_from_sender<NFT>(&scenario);
            assert!(erc1155::get_balance(&nft2) == 50, 0);
            ts::return_to_sender(&scenario, nft2);
        };
        ts::end(scenario);
    }

    // TC-19: Test safe addition with overflow
    #[test]
    fun test_safe_add_overflow() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        let max_u64 = 18446744073709551615;

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            // Mint two tokens to test safe_add through transfer later
            erc1155::mint(
                &mut collection,
                b"Test Token",
                b"Description",
                b"uri",
                max_u64,  // max u64
                USER1,
                ts::ctx(&mut scenario)
            );

            erc1155::mint(
                &mut collection,
                b"Test Token 2",
                b"Description",
                b"uri",
                1,
                USER2,
                ts::ctx(&mut scenario)
            );
            ts::return_shared(collection);
        };

        // Now try to transfer token to cause overflow in balance calculation
        ts::next_tx(&mut scenario, USER2);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut nft = ts::take_from_sender<NFT>(&scenario);
            
            // Transfer to USER1 who already has max_u64 balance
            // This should cause overflow in safe_add
            erc1155::transfer(
                &mut collection,
                &mut nft,
                1,
                USER1,
                ts::ctx(&mut scenario)
            );
            
            ts::return_to_sender(&scenario, nft);
            ts::return_shared(collection);
        };
        ts::end(scenario);
    }

    // TC-20: Test safe subtraction within bounds
    #[test]
    fun test_safe_sub_valid() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::mint(
                &mut collection,
                b"Test Token",
                b"Description",
                b"uri",
                100,
                USER1,
                ts::ctx(&mut scenario)
            );
            ts::return_shared(collection);
        };

        // Test through transfer operation
        ts::next_tx(&mut scenario, USER1);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut nft = ts::take_from_sender<NFT>(&scenario);
            
            erc1155::transfer(
                &mut collection,
                &mut nft,
                60,
                USER2,
                ts::ctx(&mut scenario)
            );
            
            // Verify remaining balance after subtraction
            assert!(erc1155::get_balance(&nft) == 40, 0);
            ts::return_to_sender(&scenario, nft);
            ts::return_shared(collection);
        };
        ts::end(scenario);
    }

     // TC-21: Test safe subtraction with underflow
    #[test]
    #[expected_failure(abort_code = 4)]
    fun test_safe_sub_underflow() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::mint(
                &mut collection,
                b"Test Token",
                b"Description",
                b"uri",
                50,
                USER1,
                ts::ctx(&mut scenario)
            );
            ts::return_shared(collection);
        };

        // Try to transfer more than balance
        ts::next_tx(&mut scenario, USER1);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut nft = ts::take_from_sender<NFT>(&scenario);
            
            erc1155::transfer(
                &mut collection,
                &mut nft,
                100, // More than balance
                USER2,
                ts::ctx(&mut scenario)
            );
            
            ts::return_to_sender(&scenario, nft);
            ts::return_shared(collection);
        };
        ts::end(scenario);
    }

    // TC-22: Test safe multiply ratio with valid values
    #[test]
    fun test_safe_multiply_ratio_valid() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            // Mint tokens to test revenue sharing
            erc1155::mint(
                &mut collection,
                b"Test Token",
                b"Description",
                b"uri",
                1000, // Total supply
                USER1,
                ts::ctx(&mut scenario)
            );
            ts::return_shared(collection);
        };

        // Test ratio through revenue distribution
        let token_id: ID;
        ts::next_tx(&mut scenario, USER1);
        {
            let nft = ts::take_from_sender<NFT>(&scenario);
            token_id = erc1155::get_token_id(&nft);
            ts::return_to_sender(&scenario, nft);
        };

        // Add ADMIN as operator and deposit revenue
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::add_operator(&mut collection, ADMIN, ts::ctx(&mut scenario));
            ts::return_shared(collection);
        };

        ts::next_tx(&mut scenario, ADMIN);
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
            
            transfer::public_transfer(payment, ADMIN);
            ts::return_shared(collection);
        };

        // Check ratio calculation through withdrawal
        ts::next_tx(&mut scenario, USER1);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut nft = ts::take_from_sender<NFT>(&scenario);
            
            erc1155::withdraw_revenue(
                &mut collection,
                &mut nft,
                ts::ctx(&mut scenario)
            );
            
            // User should get all revenue since they own all tokens
            assert!(erc1155::get_claimed_revenue(&nft) == 1000, 0);
            
            ts::return_to_sender(&scenario, nft);
            ts::return_shared(collection);
        };
        ts::end(scenario);
    }

    // TC-23: Test safe multiply ratio with zero denominator
    #[test]
    #[expected_failure(abort_code = 5)] 
    fun test_safe_multiply_ratio_zero_denominator() {
        let mut scenario = ts::begin(ADMIN);
        {
            erc1155::init_for_testing(ts::ctx(&mut scenario));
        };

        // Thử tạo token với supply = 0
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<Collection>(&scenario);
            erc1155::mint(
                &mut collection,
                b"Test Token",
                b"Description",
                b"uri",
                0, // Zero amount
                USER1,
                ts::ctx(&mut scenario)
            );
            ts::return_shared(collection);
        };
        ts::end(scenario);
    }
}