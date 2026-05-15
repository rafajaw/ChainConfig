// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";
import { ChainConfig } from "../../src/ChainConfig.sol";
import { AddressEntry, Bytes32Entry, Config, EIP712_DOMAIN_NAME, EIP712_DOMAIN_VERSION, EmptyKey, KeyTooLong, UintEntry } from "../../src/Definitions.sol";


contract ChainConfigTestBase is Test {

    bytes32 internal constant ADDRESS_ENTRY_TYPEHASH  =  keccak256("AddressEntry(string key,address value)");
    bytes32 internal constant BYTES32_ENTRY_TYPEHASH  =  keccak256("Bytes32Entry(string key,bytes32 value)");
    bytes32 internal constant UINT_ENTRY_TYPEHASH     =  keccak256("UintEntry(string key,uint256 value)");
    bytes32 internal constant CONFIG_TYPEHASH         =  keccak256("Config(uint256 chain_id,uint256 timestamp,AddressEntry[] addresses,Bytes32Entry[] bytes32s,UintEntry[] uints)AddressEntry(string key,address value)Bytes32Entry(string key,bytes32 value)UintEntry(string key,uint256 value)");
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH  =  keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    uint256 internal constant SIGNER_PRIVATE_KEY       =  0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
    uint256 internal constant WRONG_SIGNER_PRIVATE_KEY =  0x2234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;
    uint256 internal constant DEFAULT_TIMESTAMP        =  1_700_000_000;

    ChainConfig internal chain_config;
    address internal signer;
    address internal wrong_signer;
    address internal relayer;

    function setUp( )
    public virtual
    {
        vm.chainId( 31_337 );
        vm.warp( DEFAULT_TIMESTAMP + 1 days );

        chain_config  =  new ChainConfig();
        signer        =  vm.addr( SIGNER_PRIVATE_KEY );
        wrong_signer  =  vm.addr( WRONG_SIGNER_PRIVATE_KEY );
        relayer       =  address(0xA11CE);
    }

    function _single_address_config( string memory key, address value, uint256 timestamp ) internal view returns ( Config memory config )
    {
        config.chain_id   =  block.chainid;
        config.timestamp  =  timestamp;
        config.addresses  =  new AddressEntry[](1);
        config.bytes32s   =  new Bytes32Entry[](0);
        config.uints      =  new UintEntry[](0);

        config.addresses[0]  =  AddressEntry({ key: key, value: value });
    }

    function _single_bytes32_config( string memory key, bytes32 value, uint256 timestamp ) internal view returns ( Config memory config )
    {
        config.chain_id   =  block.chainid;
        config.timestamp  =  timestamp;
        config.addresses  =  new AddressEntry[](0);
        config.bytes32s   =  new Bytes32Entry[](1);
        config.uints      =  new UintEntry[](0);

        config.bytes32s[0]  =  Bytes32Entry({ key: key, value: value });
    }

    function _single_uint_config( string memory key, uint256 value, uint256 timestamp ) internal view returns ( Config memory config )
    {
        config.chain_id   =  block.chainid;
        config.timestamp  =  timestamp;
        config.addresses  =  new AddressEntry[](0);
        config.bytes32s   =  new Bytes32Entry[](0);
        config.uints      =  new UintEntry[](1);

        config.uints[0]  =  UintEntry({ key: key, value: value });
    }

    function _mixed_config( uint256 timestamp ) internal view returns ( Config memory config )
    {
        config.chain_id   =  block.chainid;
        config.timestamp  =  timestamp;
        config.addresses  =  new AddressEntry[](1);
        config.bytes32s   =  new Bytes32Entry[](1);
        config.uints      =  new UintEntry[](1);

        config.addresses[0]  =  AddressEntry({ key: "USDC_ADDRESS", value: address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48) });
        config.bytes32s[0]   =  Bytes32Entry({ key: "SALT", value: bytes32("SALT_VALUE") });
        config.uints[0]      =  UintEntry({ key: "FEE_BPS", value: 30 });
    }

    function _empty_config( uint256 timestamp ) internal view returns ( Config memory config )
    {
        config.chain_id   =  block.chainid;
        config.timestamp  =  timestamp;
        config.addresses  =  new AddressEntry[](0);
        config.bytes32s   =  new Bytes32Entry[](0);
        config.uints      =  new UintEntry[](0);
    }

    function _key_to_bytes32( string memory key ) internal pure returns ( bytes32 key_bytes32 )
    {
        bytes memory key_bytes  =  bytes(key);

        // Casting is safe in tests when callers pass keys of at most 32 bytes.
        // forge-lint: disable-next-line(unsafe-typecast)
        key_bytes32  =  bytes32(key_bytes);
    }

    function _read_address( address config_signer, string memory key ) internal view returns ( address )
    {
        return chain_config.read_address( config_signer, key );
    }

    function _read_address_key( address config_signer, bytes32 key ) internal view returns ( address )
    {
        return chain_config.read_address( config_signer, key );
    }

    function _read_bytes32( address config_signer, string memory key ) internal view returns ( bytes32 )
    {
        return chain_config.read_bytes32( config_signer, key );
    }

    function _read_bytes32_key( address config_signer, bytes32 key ) internal view returns ( bytes32 )
    {
        return chain_config.read_bytes32( config_signer, key );
    }

    function _read_uint( address config_signer, string memory key ) internal view returns ( uint256 )
    {
        return chain_config.read_uint( config_signer, key );
    }

    function _read_uint_key( address config_signer, bytes32 key ) internal view returns ( uint256 )
    {
        return chain_config.read_uint( config_signer, key );
    }

    function _sign_config( Config memory config, uint256 private_key ) internal view returns ( bytes memory signature )
    {
        bytes32 digest  =  chain_config.__OFF_CHAIN__hash_config( config );

        ( uint8 v, bytes32 r, bytes32 s )  =  vm.sign( private_key, digest );

        signature  =  abi.encodePacked( r, s, v );
    }

    function _hash_address_entry_reference( AddressEntry memory entry ) internal pure returns ( bytes32 )
    {
        return keccak256(abi.encode( ADDRESS_ENTRY_TYPEHASH, keccak256(bytes(entry.key)), entry.value ));
    }

    function _hash_bytes32_entry_reference( Bytes32Entry memory entry ) internal pure returns ( bytes32 )
    {
        return keccak256(abi.encode( BYTES32_ENTRY_TYPEHASH, keccak256(bytes(entry.key)), entry.value ));
    }

    function _hash_uint_entry_reference( UintEntry memory entry ) internal pure returns ( bytes32 )
    {
        return keccak256(abi.encode( UINT_ENTRY_TYPEHASH, keccak256(bytes(entry.key)), entry.value ));
    }

    function _hash_address_entries_reference( AddressEntry[] memory entries ) internal pure returns ( bytes32 result )
    {
        bytes32[] memory entry_hashes  =  new bytes32[]( entries.length );

        for(  uint256 i = 0  ;  i < entries.length  ;  i++  )
        {
            entry_hashes[ i ]  =  _hash_address_entry_reference( entries[ i ] );
        }

        result  =  keccak256(abi.encodePacked( entry_hashes ));
    }

    function _hash_bytes32_entries_reference( Bytes32Entry[] memory entries ) internal pure returns ( bytes32 result )
    {
        bytes32[] memory entry_hashes  =  new bytes32[]( entries.length );

        for(  uint256 i = 0  ;  i < entries.length  ;  i++  )
        {
            entry_hashes[ i ]  =  _hash_bytes32_entry_reference( entries[ i ] );
        }

        result  =  keccak256(abi.encodePacked( entry_hashes ));
    }

    function _hash_uint_entries_reference( UintEntry[] memory entries ) internal pure returns ( bytes32 result )
    {
        bytes32[] memory entry_hashes  =  new bytes32[]( entries.length );

        for(  uint256 i = 0  ;  i < entries.length  ;  i++  )
        {
            entry_hashes[ i ]  =  _hash_uint_entry_reference( entries[ i ] );
        }

        result  =  keccak256(abi.encodePacked( entry_hashes ));
    }

    function _hash_config_struct_reference( Config memory config ) internal pure returns ( bytes32 )
    {
        return keccak256(
            abi.encode(
                CONFIG_TYPEHASH,
                config.chain_id,
                config.timestamp,
                _hash_address_entries_reference( config.addresses ),
                _hash_bytes32_entries_reference( config.bytes32s ),
                _hash_uint_entries_reference( config.uints )
            )
        );
    }

    function _domain_separator_reference( uint256 chain_id, address verifying_contract ) internal pure returns ( bytes32 )
    {
        return keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(EIP712_DOMAIN_NAME)),
                keccak256(bytes(EIP712_DOMAIN_VERSION)),
                chain_id,
                verifying_contract
            )
        );
    }

    function _hash_config_reference( Config memory config ) internal view returns ( bytes32 )
    {
        bytes32 domain_separator  =  _domain_separator_reference( block.chainid, address(chain_config) );
        bytes32 struct_hash       =  _hash_config_struct_reference( config );

        return keccak256(abi.encodePacked( "\x19\x01", domain_separator, struct_hash ));
    }

    function _expect_empty_key_revert( ) internal
    {
        vm.expectRevert( EmptyKey.selector );
    }

    function _expect_key_too_long_revert( string memory key ) internal
    {
        vm.expectRevert( abi.encodeWithSelector( KeyTooLong.selector, key, bytes(key).length ) );
    }

}
