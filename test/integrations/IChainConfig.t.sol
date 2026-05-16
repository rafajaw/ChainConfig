// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";

import {
    AddressEntry,
    Bytes32Entry,
    CHAINCONFIG_ADDRESS,
    ChainConfig,
    Config,
    KeyTypeMismatch,
    UintEntry,
    ValueType
} from "../../src/integrations/IChainConfig.sol";

import { IIntegrationTests } from "../TestManifest.sol";


// ━━━━  MOCKS  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// @notice Acts as a DAO/timelock/governance contract that publishes config under its own namespace.
contract MockDAO {

    function publish_address( string memory key, address value, uint256 timestamp ) external
    {
        AddressEntry[] memory entries  =  new AddressEntry[](1);
        entries[0]  =  AddressEntry({ key: key, value: value });

        Config memory config;
        config.chain_id   =  block.chainid;
        config.timestamp  =  timestamp;
        config.addresses  =  entries;
        config.bytes32s   =  new Bytes32Entry[](0);
        config.uints      =  new UintEntry[](0);

        ChainConfig.write_config( config );
    }

    function publish_bytes32( string memory key, bytes32 value, uint256 timestamp ) external
    {
        Bytes32Entry[] memory entries  =  new Bytes32Entry[](1);
        entries[0]  =  Bytes32Entry({ key: key, value: value });

        Config memory config;
        config.chain_id   =  block.chainid;
        config.timestamp  =  timestamp;
        config.addresses  =  new AddressEntry[](0);
        config.bytes32s   =  entries;
        config.uints      =  new UintEntry[](0);

        ChainConfig.write_config( config );
    }

    function publish_uint( string memory key, uint256 value, uint256 timestamp ) external
    {
        UintEntry[] memory entries  =  new UintEntry[](1);
        entries[0]  =  UintEntry({ key: key, value: value });

        Config memory config;
        config.chain_id   =  block.chainid;
        config.timestamp  =  timestamp;
        config.addresses  =  new AddressEntry[](0);
        config.bytes32s   =  new Bytes32Entry[](0);
        config.uints      =  entries;

        ChainConfig.write_config( config );
    }
}


/// @notice Downstream contract that reads DAO-published config in its constructor and caches as `immutable`.
contract MockDownstreamConsumer {

    address public immutable USDC;
    uint256 public immutable FEE_BPS;

    constructor( address dao_signer )
    {
        USDC     =  ChainConfig.read_address( dao_signer, bytes32("USDC_ADDRESS") );
        FEE_BPS  =  ChainConfig.read_uint(    dao_signer, bytes32("FEE_BPS")      );
    }
}


// ━━━━  TEST SUITE  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

contract IntegrationTest is Test, IIntegrationTests {

    uint256 internal constant DEFAULT_TIMESTAMP  =  1_700_000_000;

    MockDAO internal dao_a;
    MockDAO internal dao_b;


    function setUp( )
    public
    {
        vm.chainId( 31_337 );
        vm.warp( DEFAULT_TIMESTAMP + 1 days );

        // Deploy the actual ChainConfig contract AT the canonical address so the typed constant resolves.
        deployCodeTo( "ChainConfig.sol:ChainConfig", "", CHAINCONFIG_ADDRESS );

        dao_a  =  new MockDAO();
        dao_b  =  new MockDAO();
    }


    // ━━━━  TYPED-CONSTANT ROUTING  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    function test_typed_constant_points_to_canonical_address( )
    external pure
    {
        assertEq( address(ChainConfig), CHAINCONFIG_ADDRESS, "Typed constant must resolve to the canonical CREATE2 address." );
    }

    function test_read_address_via_typed_constant_returns_written_value( )
    external
    {
        dao_a.publish_address( "USDC_ADDRESS", address(0xAAAA), DEFAULT_TIMESTAMP );

        assertEq( ChainConfig.read_address( address(dao_a), bytes32("USDC_ADDRESS") ), address(0xAAAA), "Read via typed constant should return the value written via the typed constant." );
    }

    function test_read_bytes32_via_typed_constant_returns_written_value( )
    external
    {
        dao_a.publish_bytes32( "SALT", bytes32("SALT_VALUE"), DEFAULT_TIMESTAMP );

        assertEq( ChainConfig.read_bytes32( address(dao_a), bytes32("SALT") ), bytes32("SALT_VALUE"), "Read via typed constant should return the value written via the typed constant." );
    }

    function test_read_uint_via_typed_constant_returns_written_value( )
    external
    {
        dao_a.publish_uint( "FEE_BPS", 30, DEFAULT_TIMESTAMP );

        assertEq( ChainConfig.read_uint( address(dao_a), bytes32("FEE_BPS") ), 30, "Read via typed constant should return the value written via the typed constant." );
    }

    function test_string_key_overload_works_via_typed_constant( )
    external
    {
        dao_a.publish_uint( "FEE_BPS", 42, DEFAULT_TIMESTAMP );

        assertEq( ChainConfig.read_uint( address(dao_a), string("FEE_BPS") ), 42, "String-key overload should route through the typed constant." );
    }

    function test_bytes32_key_overload_works_via_typed_constant( )
    external
    {
        dao_a.publish_uint( "FEE_BPS", 99, DEFAULT_TIMESTAMP );

        assertEq( ChainConfig.read_uint( address(dao_a), bytes32("FEE_BPS") ), 99, "Bytes32-key overload should route through the typed constant." );
    }


    // ━━━━  DAO-AS-SIGNER PATTERN  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    function test_dao_publishes_address_under_its_own_namespace( )
    external
    {
        dao_a.publish_address( "USDC_ADDRESS", address(0xABCD), DEFAULT_TIMESTAMP );

        assertEq( ChainConfig.read_address( address(dao_a), bytes32("USDC_ADDRESS") ), address(0xABCD), "DAO write should be readable under the DAO's address as signer namespace." );
    }

    function test_dao_publishes_uint_under_its_own_namespace( )
    external
    {
        dao_a.publish_uint( "FEE_BPS", 50, DEFAULT_TIMESTAMP );

        assertEq( ChainConfig.read_uint( address(dao_a), bytes32("FEE_BPS") ), 50, "DAO write should be readable under the DAO's address as signer namespace." );
    }

    function test_two_daos_have_isolated_namespaces( )
    external
    {
        dao_a.publish_address( "USDC_ADDRESS", address(0xAAAA), DEFAULT_TIMESTAMP );
        dao_b.publish_address( "USDC_ADDRESS", address(0xBBBB), DEFAULT_TIMESTAMP );

        assertEq( ChainConfig.read_address( address(dao_a), bytes32("USDC_ADDRESS") ), address(0xAAAA), "DAO A's namespace must not be affected by DAO B's write." );
        assertEq( ChainConfig.read_address( address(dao_b), bytes32("USDC_ADDRESS") ), address(0xBBBB), "DAO B's namespace must not be affected by DAO A's write." );
    }

    function test_dao_updates_value_with_newer_timestamp( )
    external
    {
        dao_a.publish_uint( "FEE_BPS", 30, DEFAULT_TIMESTAMP );
        dao_a.publish_uint( "FEE_BPS", 50, DEFAULT_TIMESTAMP + 1 );

        assertEq( ChainConfig.read_uint( address(dao_a), bytes32("FEE_BPS") ), 50, "Newer-timestamp write should overwrite the prior value." );
    }

    function test_dao_changes_type_with_newer_timestamp( )
    external
    {
        dao_a.publish_address( "PARAM", address(0x1111), DEFAULT_TIMESTAMP );
        dao_a.publish_uint(    "PARAM", 42,              DEFAULT_TIMESTAMP + 1 );

        assertEq( ChainConfig.read_uint( address(dao_a), bytes32("PARAM") ), 42, "Type change with newer timestamp should switch the read type to uint." );

        vm.expectRevert( abi.encodeWithSelector( KeyTypeMismatch.selector, address(dao_a), bytes32("PARAM"), ValueType.UINT, ValueType.ADDRESS ) );
        ChainConfig.read_address( address(dao_a), bytes32("PARAM") );
    }


    // ━━━━  DOWNSTREAM CONSUMER PATTERN  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    function test_downstream_consumer_reads_dao_address_in_constructor( )
    external
    {
        dao_a.publish_address( "USDC_ADDRESS", address(0xCAFE), DEFAULT_TIMESTAMP );
        dao_a.publish_uint(    "FEE_BPS",      30,              DEFAULT_TIMESTAMP );

        MockDownstreamConsumer consumer  =  new MockDownstreamConsumer( address(dao_a) );

        assertEq( consumer.USDC(), address(0xCAFE), "Downstream consumer should read DAO-published address in its constructor and cache it." );
    }

    function test_downstream_consumer_reads_dao_uint_in_constructor( )
    external
    {
        dao_a.publish_address( "USDC_ADDRESS", address(0xCAFE), DEFAULT_TIMESTAMP );
        dao_a.publish_uint(    "FEE_BPS",      77,              DEFAULT_TIMESTAMP );

        MockDownstreamConsumer consumer  =  new MockDownstreamConsumer( address(dao_a) );

        assertEq( consumer.FEE_BPS(), 77, "Downstream consumer should read DAO-published uint in its constructor and cache it." );
    }
}
