module owner::NFTCollection {
    use aptos_framework::fungible_asset;
    use aptos_framework::object::{Self, Object};
    use aptos_framework::primary_fungible_store;
    use aptos_token_objects::collection;
    use aptos_token_objects::property_map;
    use aptos_token_objects::token;
    use aptos_framework::aptos_coin::AptosCoin;
    use std::math64::{pow};
    use aptos_framework::coin;
    use std::option::{Self, Option};
    use std::string::{Self, String};
    use std::debug;
    use std::signer;
    use owner::random;
    use owner::FURToken;

    //Error codes
    const ENOT_CREATOR: u64 = 0;
    const EALL_MINTED: u64 = 1;
    const EINSUFFICIENT_APT_BALANCE: u64 = 2;

    const CHARACTER_COLLECTION_NAME: vector<u8> = b"CHARACTER Collection Name";
    const CHARACTER_COLLECTION_DESCRIPTION: vector<u8> = b"CHARACTER Collection Description";
    const CHARACTER_COLLECTION_URI: vector<u8> = b"https://CHARACTER.collection.uri";
    
    const RABBIT_TOKEN_NAME: vector<u8> = b"Rabbit Token";
    const RABBIT_SYMBOL_NAME: vector<u8> = b"RB";

    const BABY_WOLFIE_TOKEN_NAME: vector<u8> = b"Baby Wolfie Token";
    const BABY_WOLFIE_SYMBOL_NAME: vector<u8> = b"BW";





    const Gen0_Max: u128 = 1u128;
    const Gen1_Max: u128 = 20u128;
    const Gen2_Max: u128 = 40u128;


    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Represents the common fields for a collection.
    struct Collection has key {
        /// The creator of this collection.
        // creator: {address},
        // A brief description of the collection.
        // description: String,
        //  An optional categorization of similar token.
        // name: String,
        // The Uniform Resource Identifier (uri) pointing to the JSON file stored in off-chain
        // storage; the URL length will likely need a maximum any suggestions?
        // uri: String,

        mutator_ref: collection::MutatorRef,
    }


    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Character has key {
        /// Used to mutate properties
        property_mutator_ref: property_map::MutatorRef,
        /// Used to mint fungible assets.
        fungible_asset_mint_ref: fungible_asset::MintRef,
        /// Used to burn fungible assets.
        fungible_asset_burn_ref: fungible_asset::BurnRef,
    }

    fun init_module(sender: &signer) {
        create_character_collection(sender);
        create_chracter_token_as_fungible_token(
            sender,
            string::utf8(b"Rabbit Token Description"),
            string::utf8(RABBIT_TOKEN_NAME),
            string::utf8(b"https://raw.githubusercontent.com/aptos-labs/aptos-core/main"),
            option::some(45000u128),
            string::utf8(b"Rabbit"),
            string::utf8(RABBIT_SYMBOL_NAME),
            string::utf8(b"https://raw.githubusercontent.com/aptos-labs/aptos-core/main"),
            string::utf8(b"https://www.aptoslabs.com"),
        );
        create_chracter_token_as_fungible_token(
            sender,
            string::utf8(b"Baby Wolfie Token Description"),
            string::utf8(BABY_WOLFIE_TOKEN_NAME),
            string::utf8(b"https://raw.githubusercontent.com/aptos-labs/aptos-core/main"),
            option::some(5000u128),
            string::utf8(b"Baby Wolfie"),
            string::utf8(BABY_WOLFIE_SYMBOL_NAME),
            string::utf8(b"https://raw.githubusercontent.com/aptos-labs/aptos-core/main"),
            string::utf8(b"https://www.aptoslabs.com"),
        )
    }

    fun create_character_collection(creator: &signer) {
        // Constructs the strings from the bytes.
        let description = string::utf8(CHARACTER_COLLECTION_DESCRIPTION);
        let name = string::utf8(CHARACTER_COLLECTION_NAME);
        let uri = string::utf8(CHARACTER_COLLECTION_URI);
        let maxSupply = 2;    // No of different tokens

        // Creates the collection with fixed supply
        let constructor_ref = collection::create_fixed_collection(
            creator,
            description,
            maxSupply,
            name,
            option::none(),
            uri,
        );

        let object_signer = object::generate_signer(&constructor_ref);
        let collection = Collection {
            mutator_ref : collection::generate_mutator_ref(&constructor_ref)
        };

        move_to(&object_signer, collection)
    }

    fun create_chracter_token_as_fungible_token(
        creator: &signer,
        description: String,
        name: String,
        uri: String,
        max_supply: Option<u128>,
        fungible_asset_name: String,
        fungible_asset_symbol: String,
        icon_uri: String,
        project_uri: String,
    ) {
        // The collection name is used to locate the collection object and to create a new token object.
        let collection = string::utf8(CHARACTER_COLLECTION_NAME);

        let constructor_ref = token::create_named_token(
            creator,
            collection,
            description,
            name,
            option::none(),
            uri,
        );

        // Generates the object signer and the refs. The object signer is used to publish a resource
        // under the token object address. The refs are used to manage the token.
        let object_signer = object::generate_signer(&constructor_ref);
        let property_mutator_ref = property_map::generate_mutator_ref(&constructor_ref);

        // Creates the fungible asset.
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            &constructor_ref,
            max_supply,
            fungible_asset_name,
            fungible_asset_symbol,
            0,
            icon_uri,
            project_uri,
        );

        let fungible_asset_mint_ref = fungible_asset::generate_mint_ref(&constructor_ref);
        let fungible_asset_burn_ref = fungible_asset::generate_burn_ref(&constructor_ref);

        // Publishes the Character resource with the refs.
        let character_token = Character {
            property_mutator_ref,
            fungible_asset_mint_ref,
            fungible_asset_burn_ref,
        };
        move_to(&object_signer, character_token);
    }

    #[view]
    public fun rabbit_token_address(): address {
        token::create_token_address(&@owner, &string::utf8(CHARACTER_COLLECTION_NAME), &string::utf8(RABBIT_TOKEN_NAME))
    }

    #[view]
    public fun baby_wolfie_token_address(): address {
        token::create_token_address(&@owner, &string::utf8(CHARACTER_COLLECTION_NAME), &string::utf8(BABY_WOLFIE_TOKEN_NAME))
    }
    
    const RABBIT_PROBABILITY: u64 = 90;
    public entry fun mint(creator: &signer, receiver: address, amount: u64) acquires Character {
        let i = 1;
        while (i <= amount) {
            
            let random_number = random::rand_u64_range_no_sender(0, 100);
            let is_sheep = random_number <= RABBIT_PROBABILITY;
            debug::print(&string::utf8(b"Random number generate: "));
            debug::print(&random_number);
            if(is_sheep) {
                let rabbit_token: Object<Character> = object::address_to_object<Character>(rabbit_token_address());
                mint_internal(creator, rabbit_token, receiver);
            } else {
                let baby_wolfie_token: Object<Character> = object::address_to_object<Character>(baby_wolfie_token_address());
                mint_internal(creator, baby_wolfie_token, receiver);
            };

            i = i + 1
        };
    }


    fun mint_internal(sender: &signer, token: Object<Character>, receiver: address) acquires Character {
        let token_address = object::object_address(&token);
        let character_token = borrow_global<Character>(token_address);
        
        //Total token supply 
        let token_current_supply = option::destroy_some<u128>(fungible_asset::supply(token));
        debug::print(&string::utf8(b"token supply outside if"));
        debug::print(&token_current_supply);

        if(token_current_supply < Gen0_Max) {
            debug::print(&string::utf8(b"token supply inside if"));
            debug::print(&token_current_supply);
            assert!(token_current_supply + 1u128 <= Gen0_Max, EALL_MINTED);
            let price = 1;
            debug::print(&price);
            assert!(coin::balance<AptosCoin>(receiver) >= price, EINSUFFICIENT_APT_BALANCE);
            coin::transfer<AptosCoin>(sender, @owner, price);
        }
        else {
            debug::print(&string::utf8(b"Supply greater than 10k"));
            let price = mint_cost(token_current_supply);
            debug::print(&string::utf8(b"Price"));
            debug::print(&price);
            
            let asset = FURToken::get_metadata();
            let decimals = fungible_asset::decimals(asset);
            let decimal_offset = pow(10u64, (decimals as u64)); 

            debug::print(&string::utf8(b"decimals"));
            debug::print(&decimals);
            debug::print(&string::utf8(b"decimal offset"));
            debug::print(&decimal_offset);
            let amount_with_decimals = price*decimal_offset;
            debug::print(&string::utf8(b"Metadata"));
            debug::print(&asset);

            primary_fungible_store::transfer(sender, asset, @owner, amount_with_decimals); 
        };

        let fa = fungible_asset::mint(&character_token.fungible_asset_mint_ref, 1);
        primary_fungible_store::deposit(receiver, fa);
        
    }

    fun mint_cost(current_supply: u128): u64 {
        if (current_supply < Gen0_Max) {
            return 0u64
        } else if (current_supply <= Gen1_Max) {
            return 20u64
        } else if (current_supply <= Gen2_Max) {
            return 40u64
        };
        80u64
    }

    #[view]
    public fun get_metadata(token_name: vector<u8>): Object<Character> {
        let asset_address: address = token::create_token_address(&@owner, &string::utf8(CHARACTER_COLLECTION_NAME), &string::utf8(token_name));
        let token = object::address_to_object<Character>(asset_address);
        return token
    }


    #[test_only]
    use aptos_framework::block;

    #[test_only]
    use aptos_framework::timestamp;

    #[test_only]
    use aptos_framework::account;

    #[test(creator=@owner)]
    public fun init_module_for_test(creator: &signer) {
        init_module(creator);
    }
     
    #[test(creator=@owner, framework=@0x1, user1=@0xcafe)] 
    fun test_mint(creator: &signer, framework: &signer, user1: &signer) acquires Character {
        // Setup accounts
        let framework_addr = signer::address_of(framework);
        let framework_acc = &account::create_account_for_test(framework_addr);

        let creator_addr = signer::address_of(creator);
        let _creator_acc = &account::create_account_for_test(creator_addr);

        // Initialise aptos parameters
        block::initialize_for_test(framework_acc, 10000);
        timestamp::set_time_has_started_for_testing(framework);
        debug::print(&string::utf8(b"time initially: "));
        debug::print(&timestamp::now_seconds());

        init_module(creator);

        let account_addr = signer::address_of(user1);
        account::create_account_for_test(account_addr);


        //---------Set up for AptosCoin(APT) transfer---------
        coin::register<AptosCoin>(user1);
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<AptosCoin>(
            framework,
            string::utf8(b"APT"),
            string::utf8(b"APT"),
            8,
            false,
        );
        let coins = coin::mint<AptosCoin>(1000000000, &mint_cap);
        coin::deposit(signer::address_of(user1), coins);
        let balance = coin::balance<AptosCoin>(signer::address_of(user1));
        debug::print(&string::utf8(b"Balance after AptosCoin Deposit"));
        debug::print(&balance);

        coin::register<AptosCoin>(creator);
        let owner_balance = coin::balance<AptosCoin>(signer::address_of(creator));
        debug::print(&string::utf8(b"Owner Balance before mint"));
        debug::print(&owner_balance);
        
        coin::destroy_mint_cap(mint_cap);
        coin::destroy_freeze_cap(freeze_cap);
        coin::destroy_burn_cap(burn_cap);
        mint(user1, signer::address_of(user1), 1u64);

        let owner_balance = coin::balance<AptosCoin>(signer::address_of(creator));
        debug::print(&string::utf8(b"Owner Balance after mint"));
        debug::print(&owner_balance);

        // -----------*--------------


        // -------------Set up for FurToken transfer --------
        FURToken::initialize(creator);
        FURToken::mint(signer::address_of(user1), 900000_0000_0000);
        
        let owner_furToken_before = primary_fungible_store::balance(signer::address_of(creator), FURToken::get_metadata());
        debug::print(&string::utf8(b"Owner balance before FurToken mint"));
        debug::print(&owner_furToken_before);

        let balance_furToken_before = primary_fungible_store::balance(signer::address_of(user1), FURToken::get_metadata());
        let balance_character_before = primary_fungible_store::balance(signer::address_of(user1), get_metadata(RABBIT_TOKEN_NAME));

        debug::print(&string::utf8(b"Furtoken Balance before character mint"));
        debug::print(&balance_furToken_before);
        debug::print(&string::utf8(b"Character Balance before character mint"));
        debug::print(&balance_character_before);

        // Minting 1 token in gen 1
        mint(user1, signer::address_of(user1), 1u64);

        let owner_furToken_after = primary_fungible_store::balance(signer::address_of(creator), FURToken::get_metadata());
        debug::print(&string::utf8(b"Owner balance after FurToken mint"));
        debug::print(&owner_furToken_after);
        
        let balance_furToken_after = primary_fungible_store::balance(signer::address_of(user1), FURToken::get_metadata());
        let balance_character_after = primary_fungible_store::balance(signer::address_of(user1), get_metadata(RABBIT_TOKEN_NAME));
        
        debug::print(&string::utf8(b"Furtoken Balance after character mint"));
        debug::print(&balance_furToken_after);
        debug::print(&string::utf8(b"Character Balance after character mint"));
        debug::print(&balance_character_after);
        // --------------------*------------------


    
        timestamp::update_global_time_for_test_secs(100);
        debug::print(&string::utf8(b"time afterwards: "));
        debug::print(&timestamp::now_seconds());

    }
}