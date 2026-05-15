// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { AddressWritten, Bytes32Written, ChainIdMismatch, EmptyConfig, InvalidSignature, KeyNotSet, KeyTypeMismatch, StaleConfig, TimestampInFuture, UintWritten } from "../../src/Core.sol";
import { AddressEntry, Config, UintEntry, ValueType } from "../../src/Definitions.sol";
import { IChainConfigTests } from "../TestManifest.sol";
import { ChainConfigTestBase } from "../helpers/ChainConfigTestBase.sol";
import { MockEIP1271Wallet } from "../mocks/MockEIP1271Wallet.sol";


contract ChainConfigTest is ChainConfigTestBase, IChainConfigTests {

    function test_write_config_writes_address( )
    external
    {
        Config memory config  =  _single_address_config( "USDC_ADDRESS", address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48), DEFAULT_TIMESTAMP );

        vm.prank( signer );
        chain_config.write_config( config );

        address value  =  _read_address( signer, "USDC_ADDRESS" );

        assertEq( value, config.addresses[0].value, "Address value should round trip through ChainConfig." );
    }

    function test_write_config_writes_bytes32( )
    external
    {
        Config memory config  =  _single_bytes32_config( "POOL_ID", bytes32("POOL_1"), DEFAULT_TIMESTAMP );

        vm.prank( signer );
        chain_config.write_config( config );

        bytes32 value  =  _read_bytes32( signer, "POOL_ID" );

        assertEq( value, bytes32("POOL_1"), "Bytes32 value should round trip through ChainConfig." );
    }

    function test_write_config_writes_uint( )
    external
    {
        Config memory config  =  _single_uint_config( "FEE_BPS", 30, DEFAULT_TIMESTAMP );

        vm.prank( signer );
        chain_config.write_config( config );

        uint256 value  =  _read_uint( signer, "FEE_BPS" );

        assertEq( value, 30, "Uint value should round trip through ChainConfig." );
    }

    function test_write_config_writes_multiple_types( )
    external
    {
        Config memory config  =  _mixed_config( DEFAULT_TIMESTAMP );

        vm.prank( signer );
        chain_config.write_config( config );

        assertEq( _read_address( signer, "USDC_ADDRESS" ), config.addresses[0].value, "Address entry should be written." );
        assertEq( _read_bytes32( signer, "SALT" ), bytes32("SALT_VALUE"), "Bytes32 entry should be written." );
        assertEq( _read_uint( signer, "FEE_BPS" ), 30, "Uint entry should be written." );
    }

    function test_write_config_writes_under_msg_sender( )
    external
    {
        Config memory config  =  _single_uint_config( "FEE_BPS", 30, DEFAULT_TIMESTAMP );

        vm.prank( signer );
        chain_config.write_config( config );

        assertEq( _read_uint( signer, "FEE_BPS" ), 30, "Direct write should store under msg.sender." );

        vm.expectRevert( abi.encodeWithSelector( KeyNotSet.selector, relayer, _key_to_bytes32( "FEE_BPS" ) ) );
        _read_uint( relayer, "FEE_BPS" );
    }

    function test_write_config_emits_address_written( )
    external
    {
        Config memory config  =  _single_address_config( "USDC_ADDRESS", address(0x1111), DEFAULT_TIMESTAMP );
        bytes32 key           =  _key_to_bytes32( "USDC_ADDRESS" );

        vm.expectEmit( true, true, false, true, address(chain_config) );
        emit AddressWritten( signer, key, address(0x1111) );

        vm.prank( signer );
        chain_config.write_config( config );
    }

    function test_write_config_emits_bytes32_written( )
    external
    {
        Config memory config  =  _single_bytes32_config( "POOL_ID", bytes32("POOL_1"), DEFAULT_TIMESTAMP );
        bytes32 key           =  _key_to_bytes32( "POOL_ID" );

        vm.expectEmit( true, true, false, true, address(chain_config) );
        emit Bytes32Written( signer, key, bytes32("POOL_1") );

        vm.prank( signer );
        chain_config.write_config( config );
    }

    function test_write_config_emits_uint_written( )
    external
    {
        Config memory config  =  _single_uint_config( "FEE_BPS", 30, DEFAULT_TIMESTAMP );
        bytes32 key           =  _key_to_bytes32( "FEE_BPS" );

        vm.expectEmit( true, true, false, true, address(chain_config) );
        emit UintWritten( signer, key, 30 );

        vm.prank( signer );
        chain_config.write_config( config );
    }

    function test_write_config_reverts_on_empty_config( )
    external
    {
        Config memory config  =  _empty_config( DEFAULT_TIMESTAMP );

        vm.expectRevert( EmptyConfig.selector );
        chain_config.write_config( config );
    }

    function test_write_config_reverts_on_wrong_chain_id( )
    external
    {
        Config memory config  =  _single_uint_config( "FEE_BPS", 30, DEFAULT_TIMESTAMP );
        config.chain_id       =  block.chainid + 1;

        vm.expectRevert( abi.encodeWithSelector( ChainIdMismatch.selector, config.chain_id, block.chainid ) );
        chain_config.write_config( config );
    }

    function test_write_config_reverts_on_future_timestamp( )
    external
    {
        Config memory config  =  _single_uint_config( "FEE_BPS", 30, block.timestamp + 1 );

        vm.expectRevert( abi.encodeWithSelector( TimestampInFuture.selector, config.timestamp, block.timestamp ) );
        chain_config.write_config( config );
    }

    function test_write_config_reverts_on_stale_timestamp( )
    external
    {
        Config memory config  =  _single_uint_config( "FEE_BPS", 30, DEFAULT_TIMESTAMP );

        vm.startPrank( signer );
        chain_config.write_config( config );

        Config memory stale_config  =  _single_uint_config( "FEE_BPS", 31, DEFAULT_TIMESTAMP - 1 );

        vm.expectRevert( abi.encodeWithSelector( StaleConfig.selector, signer, _key_to_bytes32( "FEE_BPS" ), DEFAULT_TIMESTAMP - 1, DEFAULT_TIMESTAMP ) );
        chain_config.write_config( stale_config );
        vm.stopPrank( );
    }

    function test_write_config_reverts_on_same_timestamp( )
    external
    {
        Config memory config  =  _single_uint_config( "FEE_BPS", 30, DEFAULT_TIMESTAMP );

        vm.startPrank( signer );
        chain_config.write_config( config );

        Config memory same_timestamp_config  =  _single_uint_config( "FEE_BPS", 31, DEFAULT_TIMESTAMP );

        vm.expectRevert( abi.encodeWithSelector( StaleConfig.selector, signer, _key_to_bytes32( "FEE_BPS" ), DEFAULT_TIMESTAMP, DEFAULT_TIMESTAMP ) );
        chain_config.write_config( same_timestamp_config );
        vm.stopPrank( );
    }

    function test_write_config_allows_newer_timestamp( )
    external
    {
        Config memory config  =  _single_uint_config( "FEE_BPS", 30, DEFAULT_TIMESTAMP );

        vm.startPrank( signer );
        chain_config.write_config( config );

        Config memory newer_config  =  _single_uint_config( "FEE_BPS", 31, DEFAULT_TIMESTAMP + 1 );
        chain_config.write_config( newer_config );
        vm.stopPrank( );

        assertEq( _read_uint( signer, "FEE_BPS" ), 31, "Newer timestamp should overwrite the previous value." );
    }

    function test_write_config_reverts_on_empty_key( )
    external
    {
        Config memory config  =  _single_uint_config( "", 30, DEFAULT_TIMESTAMP );

        _expect_empty_key_revert( );
        chain_config.write_config( config );
    }

    function test_write_config_reverts_on_key_longer_than_32_bytes( )
    external
    {
        string memory key      =  "THIS_KEY_IS_LONGER_THAN_THIRTY_TWO_BYTES";
        Config memory config  =  _single_uint_config( key, 30, DEFAULT_TIMESTAMP );

        _expect_key_too_long_revert( key );
        chain_config.write_config( config );
    }

    function test_write_config_allows_type_change_with_newer_timestamp( )
    external
    {
        Config memory address_config  =  _single_address_config( "USDC", address(0x1111), DEFAULT_TIMESTAMP );
        Config memory uint_config     =  _single_uint_config( "USDC", 30, DEFAULT_TIMESTAMP + 1 );
        bytes32 key                   =  _key_to_bytes32( "USDC" );

        vm.startPrank( signer );
        chain_config.write_config( address_config );
        chain_config.write_config( uint_config );
        vm.stopPrank( );

        assertEq( _read_uint( signer, "USDC" ), 30, "Type change should overwrite with new uint value." );

        vm.expectRevert( abi.encodeWithSelector( KeyTypeMismatch.selector, signer, key, ValueType.UINT, ValueType.ADDRESS ) );
        _read_address( signer, "USDC" );
    }

    function test_write_config_reverts_on_type_change_with_stale_timestamp( )
    external
    {
        Config memory address_config  =  _single_address_config( "USDC", address(0x1111), DEFAULT_TIMESTAMP );
        Config memory stale_uint      =  _single_uint_config( "USDC", 30, DEFAULT_TIMESTAMP );
        bytes32 key                   =  _key_to_bytes32( "USDC" );

        vm.startPrank( signer );
        chain_config.write_config( address_config );

        vm.expectRevert( abi.encodeWithSelector( StaleConfig.selector, signer, key, DEFAULT_TIMESTAMP, DEFAULT_TIMESTAMP ) );
        chain_config.write_config( stale_uint );
        vm.stopPrank( );
    }

    function test_write_config_allows_same_key_for_different_signers( )
    external
    {
        Config memory signer_config        =  _single_uint_config( "FEE_BPS", 30, DEFAULT_TIMESTAMP );
        Config memory wrong_signer_config  =  _single_uint_config( "FEE_BPS", 50, DEFAULT_TIMESTAMP );

        vm.prank( signer );
        chain_config.write_config( signer_config );

        vm.prank( wrong_signer );
        chain_config.write_config( wrong_signer_config );

        assertEq( _read_uint( signer, "FEE_BPS" ), 30, "First signer should keep its own value." );
        assertEq( _read_uint( wrong_signer, "FEE_BPS" ), 50, "Second signer should keep its own value." );
    }

    function test_write_config_reverts_on_duplicate_key_same_type_in_payload( )
    external
    {
        bytes32 key  =  _key_to_bytes32( "X" );

        Config memory config   =  _empty_config( DEFAULT_TIMESTAMP );
        config.addresses       =  new AddressEntry[](2);
        config.addresses[0]    =  AddressEntry({ key: "X", value: address(0xA001) });
        config.addresses[1]    =  AddressEntry({ key: "X", value: address(0xA002) });

        vm.prank( signer );
        vm.expectRevert( abi.encodeWithSelector( StaleConfig.selector, signer, key, DEFAULT_TIMESTAMP, DEFAULT_TIMESTAMP ) );
        chain_config.write_config( config );
    }

    function test_write_config_reverts_on_duplicate_key_across_type_arrays_in_payload( )
    external
    {
        bytes32 key  =  _key_to_bytes32( "X" );

        Config memory config   =  _empty_config( DEFAULT_TIMESTAMP );
        config.addresses       =  new AddressEntry[](1);
        config.uints           =  new UintEntry[](1);
        config.addresses[0]    =  AddressEntry({ key: "X", value: address(0xA001) });
        config.uints[0]        =  UintEntry({ key: "X", value: 42 });

        vm.prank( signer );
        vm.expectRevert( abi.encodeWithSelector( StaleConfig.selector, signer, key, DEFAULT_TIMESTAMP, DEFAULT_TIMESTAMP ) );
        chain_config.write_config( config );
    }

    function test_write_config_reverts_atomically_on_partial_stale_config( )
    external
    {
        // Seed Z at a high timestamp so any later write at a lower timestamp is stale.
        Config memory seed_config  =  _single_address_config( "Z", address(0xCCCC), DEFAULT_TIMESTAMP + 100 );
        vm.prank( signer );
        chain_config.write_config( seed_config );

        // Partial-stale payload: Y is fresh (never written), Z is stale.
        Config memory partial_config   =  _empty_config( DEFAULT_TIMESTAMP + 50 );
        partial_config.addresses       =  new AddressEntry[](2);
        partial_config.addresses[0]    =  AddressEntry({ key: "Y", value: address(0xAAAA) });
        partial_config.addresses[1]    =  AddressEntry({ key: "Z", value: address(0xBBBB) });

        bytes32 key_z  =  _key_to_bytes32( "Z" );
        vm.prank( signer );
        vm.expectRevert( abi.encodeWithSelector( StaleConfig.selector, signer, key_z, DEFAULT_TIMESTAMP + 50, DEFAULT_TIMESTAMP + 100 ) );
        chain_config.write_config( partial_config );

        // Y must NOT have been written — the tx reverted atomically.
        bytes32 key_y  =  _key_to_bytes32( "Y" );
        vm.expectRevert( abi.encodeWithSelector( KeyNotSet.selector, signer, key_y ) );
        _read_address( signer, "Y" );
    }

    function test_write_config_as_accepts_valid_ecdsa_signature( )
    external
    {
        Config memory config       =  _single_address_config( "USDC_ADDRESS", address(0x1111), DEFAULT_TIMESTAMP );
        bytes memory signature     =  _sign_config( config, SIGNER_PRIVATE_KEY );

        vm.prank( relayer );
        chain_config.write_config_as( config, signer, signature, false );

        assertEq( _read_address( signer, "USDC_ADDRESS" ), address(0x1111), "Valid ECDSA signature should authorize config write." );
    }

    function test_write_config_as_accepts_valid_eip1271_signature( )
    external
    {
        MockEIP1271Wallet wallet  =  new MockEIP1271Wallet();
        Config memory config      =  _single_uint_config( "FEE_BPS", 30, DEFAULT_TIMESTAMP );
        bytes memory signature    =  "VALID_SIGNATURE";
        bytes32 digest            =  chain_config.__OFF_CHAIN__hash_config( config );

        wallet.set_valid_signature( digest, signature );

        chain_config.write_config_as( config, address(wallet), signature, true );

        assertEq( _read_uint( address(wallet), "FEE_BPS" ), 30, "Valid EIP-1271 signature should authorize config write." );
    }

    function test_write_config_as_writes_under_signer_not_relayer( )
    external
    {
        Config memory config    =  _single_uint_config( "FEE_BPS", 30, DEFAULT_TIMESTAMP );
        bytes memory signature  =  _sign_config( config, SIGNER_PRIVATE_KEY );

        vm.prank( relayer );
        chain_config.write_config_as( config, signer, signature, false );

        assertEq( _read_uint( signer, "FEE_BPS" ), 30, "Relayed write should store under signer." );

        vm.expectRevert( abi.encodeWithSelector( KeyNotSet.selector, relayer, _key_to_bytes32( "FEE_BPS" ) ) );
        _read_uint( relayer, "FEE_BPS" );
    }

    function test_write_config_as_reverts_on_invalid_signature( )
    external
    {
        Config memory config    =  _single_uint_config( "FEE_BPS", 30, DEFAULT_TIMESTAMP );
        bytes memory signature  =  hex"deadbeef";
        bytes32 digest          =  chain_config.__OFF_CHAIN__hash_config( config );

        vm.expectRevert( abi.encodeWithSelector( InvalidSignature.selector, signer, digest, signature ) );
        chain_config.write_config_as( config, signer, signature, false );
    }

    function test_write_config_as_reverts_on_wrong_signer( )
    external
    {
        Config memory config    =  _single_uint_config( "FEE_BPS", 30, DEFAULT_TIMESTAMP );
        bytes memory signature  =  _sign_config( config, SIGNER_PRIVATE_KEY );
        bytes32 digest          =  chain_config.__OFF_CHAIN__hash_config( config );

        vm.expectRevert( abi.encodeWithSelector( InvalidSignature.selector, wrong_signer, digest, signature ) );
        chain_config.write_config_as( config, wrong_signer, signature, false );
    }

    function test_write_config_as_reverts_on_wrong_chain_id_even_with_valid_signature( )
    external
    {
        Config memory config  =  _single_uint_config( "FEE_BPS", 30, DEFAULT_TIMESTAMP );
        config.chain_id       =  block.chainid + 1;

        bytes memory signature  =  _sign_config( config, SIGNER_PRIVATE_KEY );

        vm.expectRevert( abi.encodeWithSelector( ChainIdMismatch.selector, config.chain_id, block.chainid ) );
        chain_config.write_config_as( config, signer, signature, false );
    }

    function test_write_config_as_reverts_on_future_timestamp_even_with_valid_signature( )
    external
    {
        Config memory config    =  _single_uint_config( "FEE_BPS", 30, block.timestamp + 1 );
        bytes memory signature  =  _sign_config( config, SIGNER_PRIVATE_KEY );

        vm.expectRevert( abi.encodeWithSelector( TimestampInFuture.selector, config.timestamp, block.timestamp ) );
        chain_config.write_config_as( config, signer, signature, false );
    }

    function test_write_config_as_rejects_invalid_signature_before_writing( )
    external
    {
        Config memory config    =  _single_uint_config( "FEE_BPS", 30, DEFAULT_TIMESTAMP );
        bytes memory signature  =  hex"deadbeef";

        vm.expectRevert( );
        chain_config.write_config_as( config, signer, signature, false );

        vm.expectRevert( abi.encodeWithSelector( KeyNotSet.selector, signer, _key_to_bytes32( "FEE_BPS" ) ) );
        _read_uint( signer, "FEE_BPS" );
    }

    function test_read_address_with_string_key_returns_value( )
    external
    {
        Config memory config  =  _single_address_config( "USDC_ADDRESS", address(0x1111), DEFAULT_TIMESTAMP );

        vm.prank( signer );
        chain_config.write_config( config );

        assertEq( _read_address( signer, "USDC_ADDRESS" ), address(0x1111), "String key read should return address value." );
    }

    function test_read_address_with_bytes32_key_returns_value( )
    external
    {
        Config memory config  =  _single_address_config( "USDC_ADDRESS", address(0x1111), DEFAULT_TIMESTAMP );
        bytes32 key           =  _key_to_bytes32( "USDC_ADDRESS" );

        vm.prank( signer );
        chain_config.write_config( config );

        assertEq( _read_address_key( signer, key ), address(0x1111), "Bytes32 key read should return address value." );
    }

    function test_read_address_reverts_if_key_not_set( )
    external
    {
        bytes32 key  =  _key_to_bytes32( "USDC_ADDRESS" );

        vm.expectRevert( abi.encodeWithSelector( KeyNotSet.selector, signer, key ) );
        _read_address( signer, "USDC_ADDRESS" );
    }

    function test_read_address_reverts_on_type_mismatch( )
    external
    {
        Config memory config  =  _single_uint_config( "USDC_ADDRESS", 30, DEFAULT_TIMESTAMP );
        bytes32 key           =  _key_to_bytes32( "USDC_ADDRESS" );

        vm.prank( signer );
        chain_config.write_config( config );

        vm.expectRevert( abi.encodeWithSelector( KeyTypeMismatch.selector, signer, key, ValueType.UINT, ValueType.ADDRESS ) );
        _read_address( signer, "USDC_ADDRESS" );
    }

    function test_read_address_reverts_on_empty_string_key( )
    external
    {
        _expect_empty_key_revert( );
        _read_address( signer, "" );
    }

    function test_read_address_reverts_on_string_key_longer_than_32_bytes( )
    external
    {
        string memory key  =  "THIS_KEY_IS_LONGER_THAN_THIRTY_TWO_BYTES";

        _expect_key_too_long_revert( key );
        _read_address( signer, key );
    }

    function test_read_bytes32_with_string_key_returns_value( )
    external
    {
        Config memory config  =  _single_bytes32_config( "POOL_ID", bytes32("POOL_1"), DEFAULT_TIMESTAMP );

        vm.prank( signer );
        chain_config.write_config( config );

        assertEq( _read_bytes32( signer, "POOL_ID" ), bytes32("POOL_1"), "String key read should return bytes32 value." );
    }

    function test_read_bytes32_with_bytes32_key_returns_value( )
    external
    {
        Config memory config  =  _single_bytes32_config( "POOL_ID", bytes32("POOL_1"), DEFAULT_TIMESTAMP );
        bytes32 key           =  _key_to_bytes32( "POOL_ID" );

        vm.prank( signer );
        chain_config.write_config( config );

        assertEq( _read_bytes32_key( signer, key ), bytes32("POOL_1"), "Bytes32 key read should return bytes32 value." );
    }

    function test_read_bytes32_reverts_if_key_not_set( )
    external
    {
        bytes32 key  =  _key_to_bytes32( "POOL_ID" );

        vm.expectRevert( abi.encodeWithSelector( KeyNotSet.selector, signer, key ) );
        _read_bytes32( signer, "POOL_ID" );
    }

    function test_read_bytes32_reverts_on_type_mismatch( )
    external
    {
        Config memory config  =  _single_uint_config( "POOL_ID", 30, DEFAULT_TIMESTAMP );
        bytes32 key           =  _key_to_bytes32( "POOL_ID" );

        vm.prank( signer );
        chain_config.write_config( config );

        vm.expectRevert( abi.encodeWithSelector( KeyTypeMismatch.selector, signer, key, ValueType.UINT, ValueType.BYTES32 ) );
        _read_bytes32( signer, "POOL_ID" );
    }

    function test_read_bytes32_reverts_on_empty_string_key( )
    external
    {
        _expect_empty_key_revert( );
        _read_bytes32( signer, "" );
    }

    function test_read_bytes32_reverts_on_string_key_longer_than_32_bytes( )
    external
    {
        string memory key  =  "THIS_KEY_IS_LONGER_THAN_THIRTY_TWO_BYTES";

        _expect_key_too_long_revert( key );
        _read_bytes32( signer, key );
    }

    function test_read_uint_with_string_key_returns_value( )
    external
    {
        Config memory config  =  _single_uint_config( "FEE_BPS", 30, DEFAULT_TIMESTAMP );

        vm.prank( signer );
        chain_config.write_config( config );

        assertEq( _read_uint( signer, "FEE_BPS" ), 30, "String key read should return uint value." );
    }

    function test_read_uint_with_bytes32_key_returns_value( )
    external
    {
        Config memory config  =  _single_uint_config( "FEE_BPS", 30, DEFAULT_TIMESTAMP );
        bytes32 key           =  _key_to_bytes32( "FEE_BPS" );

        vm.prank( signer );
        chain_config.write_config( config );

        assertEq( _read_uint_key( signer, key ), 30, "Bytes32 key read should return uint value." );
    }

    function test_read_uint_reverts_if_key_not_set( )
    external
    {
        bytes32 key  =  _key_to_bytes32( "FEE_BPS" );

        vm.expectRevert( abi.encodeWithSelector( KeyNotSet.selector, signer, key ) );
        _read_uint( signer, "FEE_BPS" );
    }

    function test_read_uint_reverts_on_type_mismatch( )
    external
    {
        Config memory config  =  _single_address_config( "FEE_BPS", address(0x1111), DEFAULT_TIMESTAMP );
        bytes32 key           =  _key_to_bytes32( "FEE_BPS" );

        vm.prank( signer );
        chain_config.write_config( config );

        vm.expectRevert( abi.encodeWithSelector( KeyTypeMismatch.selector, signer, key, ValueType.ADDRESS, ValueType.UINT ) );
        _read_uint( signer, "FEE_BPS" );
    }

    function test_read_uint_reverts_on_empty_string_key( )
    external
    {
        _expect_empty_key_revert( );
        _read_uint( signer, "" );
    }

    function test_read_uint_reverts_on_string_key_longer_than_32_bytes( )
    external
    {
        string memory key  =  "THIS_KEY_IS_LONGER_THAN_THIRTY_TWO_BYTES";

        _expect_key_too_long_revert( key );
        _read_uint( signer, key );
    }

    function test_DOMAIN_SEPARATOR_returns_nonzero_domain_separator( )
    external view
    {
        assertTrue( chain_config.DOMAIN_SEPARATOR( ) != bytes32(0), "Domain separator should be initialized." );
    }

    function test_DOMAIN_SEPARATOR_changes_across_chain_ids( )
    external
    {
        bytes32 first_domain_separator  =  chain_config.DOMAIN_SEPARATOR( );

        vm.chainId( block.chainid + 1 );

        bytes32 second_domain_separator  =  chain_config.DOMAIN_SEPARATOR( );

        assertTrue( first_domain_separator != second_domain_separator, "Domain separator should bind block.chainid." );
    }

    function test___OFF_CHAIN__hash_config_matches_reference_eip712_digest( )
    external view
    {
        Config memory config  =  _mixed_config( DEFAULT_TIMESTAMP );

        assertEq( chain_config.__OFF_CHAIN__hash_config( config ), _hash_config_reference( config ), "Config digest should match reference EIP-712 digest." );
    }

    function test___OFF_CHAIN__hash_config_changes_with_chain_id_field( )
    external view
    {
        Config memory config       =  _mixed_config( DEFAULT_TIMESTAMP );
        Config memory other_config =  _mixed_config( DEFAULT_TIMESTAMP );
        other_config.chain_id      =  config.chain_id + 1;

        assertTrue( chain_config.__OFF_CHAIN__hash_config( config ) != chain_config.__OFF_CHAIN__hash_config( other_config ), "Config digest should bind explicit chain_id field." );
    }

    function test___OFF_CHAIN__hash_config_changes_with_timestamp( )
    external view
    {
        Config memory config        =  _mixed_config( DEFAULT_TIMESTAMP );
        Config memory newer_config  =  _mixed_config( DEFAULT_TIMESTAMP + 1 );

        assertTrue( chain_config.__OFF_CHAIN__hash_config( config ) != chain_config.__OFF_CHAIN__hash_config( newer_config ), "Config digest should bind timestamp." );
    }

    function test___OFF_CHAIN__hash_config_changes_with_entry_value( )
    external view
    {
        Config memory config       =  _mixed_config( DEFAULT_TIMESTAMP );
        Config memory other_config =  _mixed_config( DEFAULT_TIMESTAMP );
        other_config.uints[0].value  =  31;

        assertTrue( chain_config.__OFF_CHAIN__hash_config( config ) != chain_config.__OFF_CHAIN__hash_config( other_config ), "Config digest should bind entry values." );
    }

    function test___OFF_CHAIN__hash_config_changes_with_entry_order( )
    external view
    {
        Config memory first_config   =  _mixed_config( DEFAULT_TIMESTAMP );
        Config memory second_config  =  _mixed_config( DEFAULT_TIMESTAMP );

        first_config.addresses   =  new AddressEntry[](2);
        second_config.addresses  =  new AddressEntry[](2);

        first_config.addresses[0]   =  AddressEntry({ key: "A_TOKEN", value: address(0xAAAA) });
        first_config.addresses[1]   =  AddressEntry({ key: "B_TOKEN", value: address(0xBBBB) });
        second_config.addresses[0]  =  AddressEntry({ key: "B_TOKEN", value: address(0xBBBB) });
        second_config.addresses[1]  =  AddressEntry({ key: "A_TOKEN", value: address(0xAAAA) });

        assertTrue( chain_config.__OFF_CHAIN__hash_config( first_config ) != chain_config.__OFF_CHAIN__hash_config( second_config ), "Config digest should bind entry order." );
    }

    function test___OFF_CHAIN__hash_config_reverts_on_empty_key( )
    external
    {
        Config memory config   =  _empty_config( DEFAULT_TIMESTAMP );
        config.addresses       =  new AddressEntry[](1);
        config.addresses[0]    =  AddressEntry({ key: "", value: address(0xAAAA) });

        _expect_empty_key_revert( );
        chain_config.__OFF_CHAIN__hash_config( config );
    }

    function test___OFF_CHAIN__hash_config_reverts_on_key_longer_than_32_bytes( )
    external
    {
        string memory too_long_key  =  "this_key_is_definitely_longer_than_32_bytes";

        Config memory config   =  _empty_config( DEFAULT_TIMESTAMP );
        config.addresses       =  new AddressEntry[](1);
        config.addresses[0]    =  AddressEntry({ key: too_long_key, value: address(0xAAAA) });

        _expect_key_too_long_revert( too_long_key );
        chain_config.__OFF_CHAIN__hash_config( config );
    }

}
