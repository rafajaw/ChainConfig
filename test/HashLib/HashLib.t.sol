// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { AddressEntry, Bytes32Entry, Config, UintEntry } from "../../src/Definitions.sol";
import { HashLib } from "../../src/HashLib.sol";
import { IHashLibTests } from "../TestManifest.sol";
import { ChainConfigTestBase } from "../helpers/ChainConfigTestBase.sol";


contract HashLibHarness {

    function calc_config_struct_hash( Config calldata config )
    external pure returns ( bytes32 )
    {
        return HashLib.calc_config_struct_hash( config );
    }

    function hash_address_entries( AddressEntry[] calldata entries )
    external pure returns ( bytes32 )
    {
        return HashLib.hash_address_entries( entries );
    }

    function hash_bytes32_entries( Bytes32Entry[] calldata entries )
    external pure returns ( bytes32 )
    {
        return HashLib.hash_bytes32_entries( entries );
    }

    function hash_uint_entries( UintEntry[] calldata entries )
    external pure returns ( bytes32 )
    {
        return HashLib.hash_uint_entries( entries );
    }

    function hash_address_entry( AddressEntry calldata entry )
    external pure returns ( bytes32 )
    {
        return HashLib.hash_address_entry( entry );
    }

    function hash_bytes32_entry( Bytes32Entry calldata entry )
    external pure returns ( bytes32 )
    {
        return HashLib.hash_bytes32_entry( entry );
    }

    function hash_uint_entry( UintEntry calldata entry )
    external pure returns ( bytes32 )
    {
        return HashLib.hash_uint_entry( entry );
    }
}


contract HashLibTest is ChainConfigTestBase, IHashLibTests {

    HashLibHarness internal hash_lib;

    function setUp( )
    public override
    {
        super.setUp( );

        hash_lib  =  new HashLibHarness();
    }

    function test_calc_config_struct_hash_matches_solidity_reference( )
    external view
    {
        Config memory config  =  _mixed_config( DEFAULT_TIMESTAMP );

        assertEq( hash_lib.calc_config_struct_hash( config ), _hash_config_struct_reference( config ), "Config struct hash should match Solidity reference." );
    }

    function test_calc_config_struct_hash_empty_arrays_matches_reference( )
    external view
    {
        Config memory config  =  _empty_config( DEFAULT_TIMESTAMP );

        assertEq( hash_lib.calc_config_struct_hash( config ), _hash_config_struct_reference( config ), "Empty arrays should hash per EIP-712 array rules." );
    }

    function test_calc_config_struct_hash_multiple_entries_matches_reference( )
    external view
    {
        Config memory config  =  _multi_entry_config( DEFAULT_TIMESTAMP );

        assertEq( hash_lib.calc_config_struct_hash( config ), _hash_config_struct_reference( config ), "Multiple entries should match reference hash." );
    }

    function test_calc_config_struct_hash_deterministic( )
    external view
    {
        Config memory config  =  _multi_entry_config( DEFAULT_TIMESTAMP );

        bytes32 first_hash   =  hash_lib.calc_config_struct_hash( config );
        bytes32 second_hash  =  hash_lib.calc_config_struct_hash( config );

        assertEq( first_hash, second_hash, "Config struct hash should be deterministic." );
    }

    function test_calc_config_struct_hash_different_chain_id_different_hash( )
    external view
    {
        Config memory config       =  _mixed_config( DEFAULT_TIMESTAMP );
        Config memory other_config =  _mixed_config( DEFAULT_TIMESTAMP );
        other_config.chain_id      =  config.chain_id + 1;

        assertTrue( hash_lib.calc_config_struct_hash( config ) != hash_lib.calc_config_struct_hash( other_config ), "Struct hash should bind chain_id." );
    }

    function test_calc_config_struct_hash_different_timestamp_different_hash( )
    external view
    {
        Config memory config        =  _mixed_config( DEFAULT_TIMESTAMP );
        Config memory newer_config  =  _mixed_config( DEFAULT_TIMESTAMP + 1 );

        assertTrue( hash_lib.calc_config_struct_hash( config ) != hash_lib.calc_config_struct_hash( newer_config ), "Struct hash should bind timestamp." );
    }

    function test_hash_address_entries_matches_solidity_reference_single( )
    external view
    {
        AddressEntry[] memory entries  =  new AddressEntry[](1);
        entries[0]  =  AddressEntry({ key: "USDC", value: address(0x1111) });

        assertEq( hash_lib.hash_address_entries( entries ), _hash_address_entries_reference( entries ), "Single address entry array should match reference." );
    }

    function test_hash_address_entries_matches_solidity_reference_multiple( )
    external view
    {
        AddressEntry[] memory entries  =  _address_entries();

        assertEq( hash_lib.hash_address_entries( entries ), _hash_address_entries_reference( entries ), "Multiple address entries should match reference." );
    }

    function test_hash_address_entries_empty_matches_reference( )
    external view
    {
        AddressEntry[] memory entries  =  new AddressEntry[](0);

        assertEq( hash_lib.hash_address_entries( entries ), _hash_address_entries_reference( entries ), "Empty address entry array should match reference." );
    }

    function test_hash_address_entries_different_order_different_hash( )
    external view
    {
        AddressEntry[] memory first_entries   =  _address_entries();
        AddressEntry[] memory second_entries  =  new AddressEntry[](2);
        second_entries[0]  =  first_entries[1];
        second_entries[1]  =  first_entries[0];

        assertTrue( hash_lib.hash_address_entries( first_entries ) != hash_lib.hash_address_entries( second_entries ), "Address entry hash should bind order." );
    }

    function test_hash_address_entries_reverts_on_empty_key( )
    external
    {
        AddressEntry[] memory entries  =  new AddressEntry[](1);
        entries[0]  =  AddressEntry({ key: "", value: address(0x1111) });

        _expect_empty_key_revert( );
        hash_lib.hash_address_entries( entries );
    }

    function test_hash_address_entries_reverts_on_key_longer_than_32_bytes( )
    external
    {
        string memory key              =  "THIS_KEY_IS_LONGER_THAN_THIRTY_TWO_BYTES";
        AddressEntry[] memory entries  =  new AddressEntry[](1);
        entries[0]  =  AddressEntry({ key: key, value: address(0x1111) });

        _expect_key_too_long_revert( key );
        hash_lib.hash_address_entries( entries );
    }

    function test_hash_bytes32_entries_matches_solidity_reference_single( )
    external view
    {
        Bytes32Entry[] memory entries  =  new Bytes32Entry[](1);
        entries[0]  =  Bytes32Entry({ key: "POOL", value: bytes32("POOL_1") });

        assertEq( hash_lib.hash_bytes32_entries( entries ), _hash_bytes32_entries_reference( entries ), "Single bytes32 entry array should match reference." );
    }

    function test_hash_bytes32_entries_matches_solidity_reference_multiple( )
    external view
    {
        Bytes32Entry[] memory entries  =  _bytes32_entries();

        assertEq( hash_lib.hash_bytes32_entries( entries ), _hash_bytes32_entries_reference( entries ), "Multiple bytes32 entries should match reference." );
    }

    function test_hash_bytes32_entries_empty_matches_reference( )
    external view
    {
        Bytes32Entry[] memory entries  =  new Bytes32Entry[](0);

        assertEq( hash_lib.hash_bytes32_entries( entries ), _hash_bytes32_entries_reference( entries ), "Empty bytes32 entry array should match reference." );
    }

    function test_hash_bytes32_entries_different_order_different_hash( )
    external view
    {
        Bytes32Entry[] memory first_entries   =  _bytes32_entries();
        Bytes32Entry[] memory second_entries  =  new Bytes32Entry[](2);
        second_entries[0]  =  first_entries[1];
        second_entries[1]  =  first_entries[0];

        assertTrue( hash_lib.hash_bytes32_entries( first_entries ) != hash_lib.hash_bytes32_entries( second_entries ), "Bytes32 entry hash should bind order." );
    }

    function test_hash_bytes32_entries_reverts_on_empty_key( )
    external
    {
        Bytes32Entry[] memory entries  =  new Bytes32Entry[](1);
        entries[0]  =  Bytes32Entry({ key: "", value: bytes32("POOL_1") });

        _expect_empty_key_revert( );
        hash_lib.hash_bytes32_entries( entries );
    }

    function test_hash_bytes32_entries_reverts_on_key_longer_than_32_bytes( )
    external
    {
        string memory key              =  "THIS_KEY_IS_LONGER_THAN_THIRTY_TWO_BYTES";
        Bytes32Entry[] memory entries  =  new Bytes32Entry[](1);
        entries[0]  =  Bytes32Entry({ key: key, value: bytes32("POOL_1") });

        _expect_key_too_long_revert( key );
        hash_lib.hash_bytes32_entries( entries );
    }

    function test_hash_uint_entries_matches_solidity_reference_single( )
    external view
    {
        UintEntry[] memory entries  =  new UintEntry[](1);
        entries[0]  =  UintEntry({ key: "FEE", value: 30 });

        assertEq( hash_lib.hash_uint_entries( entries ), _hash_uint_entries_reference( entries ), "Single uint entry array should match reference." );
    }

    function test_hash_uint_entries_matches_solidity_reference_multiple( )
    external view
    {
        UintEntry[] memory entries  =  _uint_entries();

        assertEq( hash_lib.hash_uint_entries( entries ), _hash_uint_entries_reference( entries ), "Multiple uint entries should match reference." );
    }

    function test_hash_uint_entries_empty_matches_reference( )
    external view
    {
        UintEntry[] memory entries  =  new UintEntry[](0);

        assertEq( hash_lib.hash_uint_entries( entries ), _hash_uint_entries_reference( entries ), "Empty uint entry array should match reference." );
    }

    function test_hash_uint_entries_different_order_different_hash( )
    external view
    {
        UintEntry[] memory first_entries   =  _uint_entries();
        UintEntry[] memory second_entries  =  new UintEntry[](2);
        second_entries[0]  =  first_entries[1];
        second_entries[1]  =  first_entries[0];

        assertTrue( hash_lib.hash_uint_entries( first_entries ) != hash_lib.hash_uint_entries( second_entries ), "Uint entry hash should bind order." );
    }

    function test_hash_uint_entries_reverts_on_empty_key( )
    external
    {
        UintEntry[] memory entries  =  new UintEntry[](1);
        entries[0]  =  UintEntry({ key: "", value: 30 });

        _expect_empty_key_revert( );
        hash_lib.hash_uint_entries( entries );
    }

    function test_hash_uint_entries_reverts_on_key_longer_than_32_bytes( )
    external
    {
        string memory key           =  "THIS_KEY_IS_LONGER_THAN_THIRTY_TWO_BYTES";
        UintEntry[] memory entries  =  new UintEntry[](1);
        entries[0]  =  UintEntry({ key: key, value: 30 });

        _expect_key_too_long_revert( key );
        hash_lib.hash_uint_entries( entries );
    }

    function test_hash_address_entry_matches_solidity_reference( )
    external view
    {
        AddressEntry memory entry  =  AddressEntry({ key: "USDC", value: address(0x1111) });

        assertEq( hash_lib.hash_address_entry( entry ), _hash_address_entry_reference( entry ), "Address entry hash should match reference." );
    }

    function test_hash_address_entry_hashes_string_key_per_eip712( )
    external view
    {
        AddressEntry memory entry  =  AddressEntry({ key: "USDC", value: address(0x1111) });
        bytes32 wrong_key_hash     =  _key_to_bytes32( "USDC" );
        bytes32 wrong_hash         =  keccak256( abi.encode( ADDRESS_ENTRY_TYPEHASH, wrong_key_hash, entry.value ) );

        assertTrue( hash_lib.hash_address_entry( entry ) != wrong_hash, "EIP-712 string key should be keccak256(bytes(key)), not bytes32(key)." );
    }

    function test_hash_address_entry_different_value_different_hash( )
    external view
    {
        AddressEntry memory first_entry   =  AddressEntry({ key: "USDC", value: address(0x1111) });
        AddressEntry memory second_entry  =  AddressEntry({ key: "USDC", value: address(0x2222) });

        assertTrue( hash_lib.hash_address_entry( first_entry ) != hash_lib.hash_address_entry( second_entry ), "Address entry hash should bind value." );
    }

    function test_hash_bytes32_entry_matches_solidity_reference( )
    external view
    {
        Bytes32Entry memory entry  =  Bytes32Entry({ key: "POOL", value: bytes32("POOL_1") });

        assertEq( hash_lib.hash_bytes32_entry( entry ), _hash_bytes32_entry_reference( entry ), "Bytes32 entry hash should match reference." );
    }

    function test_hash_bytes32_entry_hashes_string_key_per_eip712( )
    external view
    {
        Bytes32Entry memory entry  =  Bytes32Entry({ key: "POOL", value: bytes32("POOL_1") });
        bytes32 wrong_key_hash     =  _key_to_bytes32( "POOL" );
        bytes32 wrong_hash         =  keccak256( abi.encode( BYTES32_ENTRY_TYPEHASH, wrong_key_hash, entry.value ) );

        assertTrue( hash_lib.hash_bytes32_entry( entry ) != wrong_hash, "EIP-712 string key should be keccak256(bytes(key)), not bytes32(key)." );
    }

    function test_hash_bytes32_entry_different_value_different_hash( )
    external view
    {
        Bytes32Entry memory first_entry   =  Bytes32Entry({ key: "POOL", value: bytes32("POOL_1") });
        Bytes32Entry memory second_entry  =  Bytes32Entry({ key: "POOL", value: bytes32("POOL_2") });

        assertTrue( hash_lib.hash_bytes32_entry( first_entry ) != hash_lib.hash_bytes32_entry( second_entry ), "Bytes32 entry hash should bind value." );
    }

    function test_hash_uint_entry_matches_solidity_reference( )
    external view
    {
        UintEntry memory entry  =  UintEntry({ key: "FEE", value: 30 });

        assertEq( hash_lib.hash_uint_entry( entry ), _hash_uint_entry_reference( entry ), "Uint entry hash should match reference." );
    }

    function test_hash_uint_entry_hashes_string_key_per_eip712( )
    external view
    {
        UintEntry memory entry  =  UintEntry({ key: "FEE", value: 30 });
        bytes32 wrong_key_hash  =  _key_to_bytes32( "FEE" );
        bytes32 wrong_hash      =  keccak256( abi.encode( UINT_ENTRY_TYPEHASH, wrong_key_hash, entry.value ) );

        assertTrue( hash_lib.hash_uint_entry( entry ) != wrong_hash, "EIP-712 string key should be keccak256(bytes(key)), not bytes32(key)." );
    }

    function test_hash_uint_entry_different_value_different_hash( )
    external view
    {
        UintEntry memory first_entry   =  UintEntry({ key: "FEE", value: 30 });
        UintEntry memory second_entry  =  UintEntry({ key: "FEE", value: 31 });

        assertTrue( hash_lib.hash_uint_entry( first_entry ) != hash_lib.hash_uint_entry( second_entry ), "Uint entry hash should bind value." );
    }

    function _multi_entry_config( uint256 timestamp ) private view returns ( Config memory config )
    {
        config.chain_id   =  block.chainid;
        config.timestamp  =  timestamp;
        config.addresses  =  _address_entries();
        config.bytes32s   =  _bytes32_entries();
        config.uints      =  _uint_entries();
    }

    function _address_entries( ) private pure returns ( AddressEntry[] memory entries )
    {
        entries     =  new AddressEntry[](2);
        entries[0]  =  AddressEntry({ key: "USDC", value: address(0x1111) });
        entries[1]  =  AddressEntry({ key: "WETH", value: address(0x2222) });
    }

    function _bytes32_entries( ) private pure returns ( Bytes32Entry[] memory entries )
    {
        entries     =  new Bytes32Entry[](2);
        entries[0]  =  Bytes32Entry({ key: "POOL_A", value: bytes32("POOL_1") });
        entries[1]  =  Bytes32Entry({ key: "POOL_B", value: bytes32("POOL_2") });
    }

    function _uint_entries( ) private pure returns ( UintEntry[] memory entries )
    {
        entries     =  new UintEntry[](2);
        entries[0]  =  UintEntry({ key: "FEE_A", value: 30 });
        entries[1]  =  UintEntry({ key: "FEE_B", value: 50 });
    }
}
