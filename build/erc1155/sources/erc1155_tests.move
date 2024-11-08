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