// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { InvalidSignature, StaleConfig } from "../../src/Core.sol";
import { Config } from "../../src/Definitions.sol";
import { IFuzzTests } from "../TestManifest.sol";
import { ChainConfigTestBase } from "../helpers/ChainConfigTestBase.sol";


contract FuzzTest is ChainConfigTestBase, IFuzzTests {

    uint256 private constant _SECP256K1_ORDER  =  0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

    function testFuzz_write_config_round_trips_address_value( string calldata key, address value, uint256 timestamp )
    external
    {
        string memory valid_key        =  _valid_key_or_default( key );
        uint256 valid_timestamp        =  bound( timestamp, 1, block.timestamp );
        Config memory config           =  _single_address_config( valid_key, value, valid_timestamp );

        vm.prank( signer );
        chain_config.write_config( config );

        assertEq( _read_address( signer, valid_key ), value, "Fuzzed address value should round trip." );
    }

    function testFuzz_write_config_round_trips_bytes32_value( string calldata key, bytes32 value, uint256 timestamp )
    external
    {
        string memory valid_key        =  _valid_key_or_default( key );
        uint256 valid_timestamp        =  bound( timestamp, 1, block.timestamp );
        Config memory config           =  _single_bytes32_config( valid_key, value, valid_timestamp );

        vm.prank( signer );
        chain_config.write_config( config );

        assertEq( _read_bytes32( signer, valid_key ), value, "Fuzzed bytes32 value should round trip." );
    }

    function testFuzz_write_config_round_trips_uint_value( string calldata key, uint256 value, uint256 timestamp )
    external
    {
        string memory valid_key        =  _valid_key_or_default( key );
        uint256 valid_timestamp        =  bound( timestamp, 1, block.timestamp );
        Config memory config           =  _single_uint_config( valid_key, value, valid_timestamp );

        vm.prank( signer );
        chain_config.write_config( config );

        assertEq( _read_uint( signer, valid_key ), value, "Fuzzed uint value should round trip." );
    }

    function testFuzz_write_config_accepts_keys_up_to_32_bytes( string calldata key )
    external
    {
        string memory valid_key  =  _valid_key_or_default( key );
        Config memory config     =  _single_uint_config( valid_key, 30, DEFAULT_TIMESTAMP );

        vm.prank( signer );
        chain_config.write_config( config );

        assertEq( _read_uint( signer, valid_key ), 30, "Any non-empty key up to 32 bytes should be accepted." );
    }

    function testFuzz_write_config_rejects_keys_longer_than_32_bytes( string calldata key )
    external
    {
        string memory invalid_key  =  key;

        if(  bytes(invalid_key).length <= 32  )  invalid_key  =  "THIS_KEY_IS_LONGER_THAN_THIRTY_TWO_BYTES";

        Config memory config  =  _single_uint_config( invalid_key, 30, DEFAULT_TIMESTAMP );

        _expect_key_too_long_revert( invalid_key );
        chain_config.write_config( config );
    }

    function testFuzz_write_config_rejects_non_increasing_timestamps( uint256 older_timestamp, uint256 newer_timestamp )
    external
    {
        uint256 first_timestamp   =  bound( newer_timestamp, 1, block.timestamp );
        uint256 second_timestamp  =  bound( older_timestamp, 0, first_timestamp );

        Config memory first_config   =  _single_uint_config( "FEE_BPS", 30, first_timestamp );
        Config memory second_config  =  _single_uint_config( "FEE_BPS", 31, second_timestamp );

        vm.startPrank( signer );
        chain_config.write_config( first_config );

        vm.expectRevert( abi.encodeWithSelector( StaleConfig.selector, signer, _key_to_bytes32( "FEE_BPS" ), second_timestamp, first_timestamp ) );
        chain_config.write_config( second_config );
        vm.stopPrank( );
    }

    function testFuzz___OFF_CHAIN__hash_config_matches_reference_for_arbitrary_values( address address_value, bytes32 bytes32_value, uint256 uint_value, uint256 timestamp )
    external view
    {
        Config memory config      =  _mixed_config( bound( timestamp, 1, block.timestamp ) );
        config.addresses[0].value =  address_value;
        config.bytes32s[0].value  =  bytes32_value;
        config.uints[0].value     =  uint_value;

        assertEq( chain_config.__OFF_CHAIN__hash_config( config ), _hash_config_reference( config ), "Fuzzed config digest should match reference EIP-712 digest." );
    }

    function testFuzz_write_config_as_accepts_signatures_from_expected_signer( uint256 signer_private_key, uint256 timestamp )
    external
    {
        uint256 valid_private_key  =  _valid_private_key( signer_private_key );
        address expected_signer    =  vm.addr( valid_private_key );
        uint256 valid_timestamp    =  bound( timestamp, 1, block.timestamp );
        Config memory config       =  _single_uint_config( "FEE_BPS", 30, valid_timestamp );
        bytes memory signature     =  _sign_config( config, valid_private_key );

        chain_config.write_config_as( config, expected_signer, signature, false );

        assertEq( _read_uint( expected_signer, "FEE_BPS" ), 30, "Expected signer signature should authorize write." );
    }

    function testFuzz_write_config_as_rejects_signatures_from_wrong_signer( uint256 signer_private_key, uint256 wrong_private_key, uint256 timestamp )
    external
    {
        uint256 valid_private_key       =  _valid_private_key( signer_private_key );
        uint256 valid_wrong_private_key =  _valid_private_key( wrong_private_key );

        vm.assume( valid_private_key != valid_wrong_private_key );

        address expected_signer   =  vm.addr( valid_private_key );
        uint256 valid_timestamp   =  bound( timestamp, 1, block.timestamp );
        Config memory config      =  _single_uint_config( "FEE_BPS", 30, valid_timestamp );
        bytes memory signature    =  _sign_config( config, valid_wrong_private_key );
        bytes32 digest            =  chain_config.__OFF_CHAIN__hash_config( config );

        vm.expectRevert( abi.encodeWithSelector( InvalidSignature.selector, expected_signer, digest, signature ) );
        chain_config.write_config_as( config, expected_signer, signature, false );
    }

    function _valid_key_or_default( string calldata key ) private pure returns ( string memory )
    {
        uint256 key_length  =  bytes(key).length;
        if(  key_length > 0  &&  key_length <= 32  )  return key;

        return "FUZZ_KEY";
    }

    function _valid_private_key( uint256 private_key ) private pure returns ( uint256 )
    {
        return bound( private_key, 1, _SECP256K1_ORDER - 1 );
    }
}
