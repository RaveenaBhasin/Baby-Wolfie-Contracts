module owner::new_stake {

    use std::signer;
    use aptos_std::smart_table;
    use aptos_framework::object;
    use aptos_framework::object::{ConstructorRef, ExtendRef, DeleteRef, Object};
    use aptos_framework::primary_fungible_store;
    use std::string::{Self};
    use std::debug;
    use owner::config;
    use owner::NFTCollection::{ get_metadata, Character };

    struct StakePoolRegistry has key {                      
        fungible_asset_to_stake_pool: smart_table::SmartTable<address, address>
    }

    /// Any pool metadata that's associated here
    /// This is not necessary if you want to use a bare secondary fungible store
    struct Pool has key {
        extend_ref: ExtendRef,
        delete_ref: DeleteRef,
        rabbit_staked_amount: u64,
        baby_wolf_staked_amount: u64,
    }

    /// Staking not initialized for this account
    const E_NO_STAKE_REGISTRY: u64 = 1;

    /// Pool not found at object address
    const E_NO_POOL_AT_ADDRESS: u64 = 2;

    /// Not enough funds in account to stake the amount given
    const E_NOT_ENOUGH_FUNDS_TO_STAKE: u64 = 3;
    /// Not enough funds in the pool to unstake the amount given
    const E_NOT_ENOUGH_FUNDS_TO_UNSTAKE: u64 = 4;

    /// Adds stake to a pool
    public entry fun stake(
        staker: &signer,
        asset_metadata_object: Object<Character>,
        amount: u64
    ) acquires StakePoolRegistry, Pool {
        let staker_addr = signer::address_of(staker);

        // Ensure you can actually stake this amount
        assert!(
            primary_fungible_store::balance(staker_addr, asset_metadata_object) >= amount,
            E_NOT_ENOUGH_FUNDS_TO_STAKE
        );

        let asset_metadata_address = object::object_address(&asset_metadata_object);

        // Ensure stake pool registry exists
        if (!exists<StakePoolRegistry>(staker_addr)) {
            debug::print(&string::utf8(b"No stake registry found, creating!!"));
            create_stake_registry(staker);
        };

        // Use the existing pool if it exists or create a new one
        let (pool_address, pool_signer)= create_or_retrieve_stake_pool_address(staker, asset_metadata_address);
        debug::print(&string::utf8(b"Pool address: "));
        debug::print(&pool_address);

        if(!exists<Pool>(signer::address_of(&pool_signer))) {
            debug::print(&string::utf8(b"Pool does not exists !!"));
        }
        else {
            debug::print(&string::utf8(b"Pool exists !!!"));
            let pool = borrow_global_mut<Pool>(signer::address_of(&pool_signer));
            // Now that we have the pool address, add stake
            primary_fungible_store::transfer(staker, asset_metadata_object, pool_address, amount);

            if(get_metadata(config::rabbit_token_name()) == asset_metadata_object) {
                pool.rabbit_staked_amount = pool.rabbit_staked_amount+amount;
                // debug::print(&string::utf8(b"Rabbit amount after staking: "));
                // debug::print(&pool.rabbit_staked_amount);
                let staker_nft_balance_after_staking = primary_fungible_store::balance(staker_addr, asset_metadata_object);
                debug::print(&string::utf8(b"Staker Rabbit NFT balance after staking: "));
                debug::print(&staker_nft_balance_after_staking);
            }
            else if (get_metadata(config::baby_wolfie_token_name()) == asset_metadata_object) {
                pool.baby_wolf_staked_amount = pool.rabbit_staked_amount+amount;
                // debug::print(&string::utf8(b"Baby Wolfie amount after staking: "));
                // debug::print(&pool.baby_wolf_staked_amount);
                let staker_nft_balance_after_staking = primary_fungible_store::balance(staker_addr, asset_metadata_object);
                debug::print(&string::utf8(b"Staker Wolf NFT balance after staking: "));
                debug::print(&staker_nft_balance_after_staking);
            }
        };
        
    }

    /// Removes stake from the pool
    public entry fun unstake(
        staker: &signer,
        asset_metadata_object: Object<Character>,
        amount: u64
    ) acquires StakePoolRegistry, Pool {
        let asset_metadata_address = object::object_address(&asset_metadata_object);
        let pool_address = retrieve_stake_pool_address(staker, asset_metadata_address);

        let pool = borrow_global_mut<Pool>(pool_address);
        let pool_signer = object::generate_signer_for_extending(&pool.extend_ref);

        // Check that we have enough to remove
        assert!(
            primary_fungible_store::balance(pool_address, asset_metadata_object) >= amount,
            E_NOT_ENOUGH_FUNDS_TO_UNSTAKE
        );

        // Now that we have the pool address, remove stake
        let staker_addr = signer::address_of(staker);
        primary_fungible_store::transfer(&pool_signer, asset_metadata_object, staker_addr, amount);

        if(get_metadata(config::rabbit_token_name()) == asset_metadata_object) {
            pool.rabbit_staked_amount = pool.rabbit_staked_amount-amount;
            // debug::print(&string::utf8(b"Rabbit amount after unstaking: "));
            // debug::print(&pool.rabbit_staked_amount);

            let staker_nft_balance_after_unstaking = primary_fungible_store::balance(staker_addr, asset_metadata_object);
            debug::print(&string::utf8(b"Staker Rabbit NFT balance after unstaking: "));
            debug::print(&staker_nft_balance_after_unstaking);
        }
        else if (get_metadata(config::baby_wolfie_token_name()) == asset_metadata_object) {
            pool.baby_wolf_staked_amount = pool.rabbit_staked_amount-amount;
            // debug::print(&string::utf8(b"Baby Wolfie amount after unstaking: "));
            // debug::print(&pool.baby_wolf_staked_amount);

            let staker_nft_balance_after_unstaking = primary_fungible_store::balance(staker_addr, asset_metadata_object);
            debug::print(&string::utf8(b"Staker Wolf NFT balance after unstaking: "));
            debug::print(&staker_nft_balance_after_unstaking);
        }
    }

    fun create_stake_registry(staker: &signer) {
        let stake_pool_registry = StakePoolRegistry {
            fungible_asset_to_stake_pool: smart_table::new()
        };
        move_to<StakePoolRegistry>(staker, stake_pool_registry);
    }
    
    fun retrieve_stake_pool_address(
        staker: &signer,
        asset_metadata_address: address
    ): address acquires StakePoolRegistry {
        let staker_addr = signer::address_of(staker);

        // // Ensure stake pool registry exists
        assert!(exists<StakePoolRegistry>(staker_addr), E_NO_STAKE_REGISTRY);
        let stake_info = borrow_global<StakePoolRegistry>(staker_addr);

        assert!(smart_table::contains(
            &stake_info.fungible_asset_to_stake_pool,
            asset_metadata_address
        ), E_NO_POOL_AT_ADDRESS);

        *smart_table::borrow(&stake_info.fungible_asset_to_stake_pool, asset_metadata_address)
    }

    fun create_or_retrieve_stake_pool_address(
        staker: &signer,
        asset_metadata_address: address
    ): (address, signer) acquires StakePoolRegistry {
        let staker_addr = signer::address_of(staker);
        let stake_info = borrow_global_mut<StakePoolRegistry>(staker_addr);

        // //If it already exists, use it, otherwise create a pool
        // if (smart_table::contains(
        //     &stake_info.fungible_asset_to_stake_pool,
        //     asset_metadata_address
        // )) {
        //    *smart_table::borrow(&stake_info.fungible_asset_to_stake_pool, asset_metadata_address)
        // } else {
        //     // Create the pool
        //     let pool_constructor: ConstructorRef = object::create_object_from_account(staker);
        //     let pool_signer = object::generate_signer(&pool_constructor);
        //     let extend_ref = object::generate_extend_ref(&pool_constructor);
        //     let delete_ref = object::generate_delete_ref(&pool_constructor);

        //     let pool_address = object::address_from_constructor_ref(&pool_constructor);
        //     let pool = Pool {
        //         extend_ref,
        //         delete_ref,
        //         rabbit_staked_amount: 0u64, 
        //         baby_wolf_staked_amount: 0u64,
        //     };

        //     smart_table::add(
        //         &mut stake_info.fungible_asset_to_stake_pool,
        //         asset_metadata_address,
        //         pool_address
        //     );

        //     move_to<Pool>(&pool_signer, pool);
        //     if(!exists<Pool>(signer::address_of(&pool_signer))) {
        //         debug::print(&string::utf8(b"Pool does not exists !!"));
        //     };
        //     (pool_address, pool_signer)
        // }
        let pool_constructor: ConstructorRef = object::create_object_from_account(staker);
        let pool_signer = object::generate_signer(&pool_constructor);
        let extend_ref = object::generate_extend_ref(&pool_constructor);
        let delete_ref = object::generate_delete_ref(&pool_constructor);

        let pool_address = object::address_from_constructor_ref(&pool_constructor);
        let pool = Pool {
            extend_ref,
            delete_ref,
            rabbit_staked_amount: 0u64, 
            baby_wolf_staked_amount: 0u64,
        };
        if(smart_table::contains(
            &stake_info.fungible_asset_to_stake_pool,
            asset_metadata_address
        )) {
            debug::print(&string::utf8(b"Pool already exists (inside) !!"));
        }else {
            smart_table::add(
                &mut stake_info.fungible_asset_to_stake_pool,
                asset_metadata_address,
                pool_address
            )
        };
        move_to<Pool>(&pool_signer, pool);
        // let table_info = *smart_table::borrow(&stake_info.fungible_asset_to_stake_pool, asset_metadata_address);
        // debug::print(&string::utf8(b"Table info: "));
        // debug::print(&table_info);
        (pool_address, pool_signer)
    }
}