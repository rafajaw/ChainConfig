// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { ISignatureValidatorTests } from "../TestManifest.sol";
import { ChainConfigTestBase } from "../helpers/ChainConfigTestBase.sol";
import { MockEIP1271Wallet } from "../mocks/MockEIP1271Wallet.sol";
import { SignatureValidator } from "../../src/utils/SignatureValidator.sol";


contract SignatureValidatorTest is ChainConfigTestBase, ISignatureValidatorTests {

    MockEIP1271Wallet internal valid_wallet;
    MockEIP1271Wallet internal invalid_wallet;
    MockEIP1271Wallet internal reverting_wallet;

    function setUp( )
    public override
    {
        super.setUp( );

        valid_wallet      =  new MockEIP1271Wallet();
        invalid_wallet    =  new MockEIP1271Wallet();
        reverting_wallet  =  new MockEIP1271Wallet();
    }

    function test_is_valid_signature_rejects_zero_hash( )
    external view
    {
        bytes memory signature  =  _sign_hash( keccak256("VALID_HASH"), SIGNER_PRIVATE_KEY );

        bool is_valid  =  SignatureValidator.is_valid_signature( signer, bytes32(0), signature, false );

        assertFalse( is_valid, "Zero hash should always be rejected." );
    }

    function test_is_valid_signature_rejects_zero_signer( )
    external view
    {
        bytes32 hash            =  keccak256("VALID_HASH");
        bytes memory signature  =  _sign_hash( hash, SIGNER_PRIVATE_KEY );

        bool is_valid  =  SignatureValidator.is_valid_signature( address(0), hash, signature, false );

        assertFalse( is_valid, "Zero signer should always be rejected." );
    }

    function test_is_valid_signature_dispatches_to_ecdsa_when_is_eip1271_is_false( )
    external view
    {
        bytes32 hash            =  keccak256("VALID_HASH");
        bytes memory signature  =  _sign_hash( hash, SIGNER_PRIVATE_KEY );

        bool is_valid  =  SignatureValidator.is_valid_signature( signer, hash, signature, false );

        assertTrue( is_valid, "is_eip1271 false should validate ECDSA signatures." );
    }

    function test_is_valid_signature_dispatches_to_eip1271_when_is_eip1271_is_true( )
    external
    {
        bytes32 hash            =  keccak256("VALID_HASH");
        bytes memory signature  =  "VALID_SIGNATURE";

        valid_wallet.set_valid_signature( hash, signature );

        bool is_valid  =  SignatureValidator.is_valid_signature( address(valid_wallet), hash, signature, true );

        assertTrue( is_valid, "is_eip1271 true should validate contract signatures." );
    }

    function test_is_valid_ecdsa_signature_accepts_valid_signature( )
    external view
    {
        bytes32 hash            =  keccak256("VALID_HASH");
        bytes memory signature  =  _sign_hash( hash, SIGNER_PRIVATE_KEY );

        bool is_valid  =  SignatureValidator.is_valid_ecdsa_signature( signer, hash, signature );

        assertTrue( is_valid, "Valid ECDSA signature should be accepted." );
    }

    function test_is_valid_ecdsa_signature_rejects_wrong_signer( )
    external view
    {
        bytes32 hash            =  keccak256("VALID_HASH");
        bytes memory signature  =  _sign_hash( hash, SIGNER_PRIVATE_KEY );

        bool is_valid  =  SignatureValidator.is_valid_ecdsa_signature( wrong_signer, hash, signature );

        assertFalse( is_valid, "ECDSA signature should reject the wrong signer." );
    }

    function test_is_valid_ecdsa_signature_rejects_wrong_hash( )
    external view
    {
        bytes32 hash            =  keccak256("VALID_HASH");
        bytes32 wrong_hash      =  keccak256("WRONG_HASH");
        bytes memory signature  =  _sign_hash( hash, SIGNER_PRIVATE_KEY );

        bool is_valid  =  SignatureValidator.is_valid_ecdsa_signature( signer, wrong_hash, signature );

        assertFalse( is_valid, "ECDSA signature should reject the wrong hash." );
    }

    function test_is_valid_ecdsa_signature_rejects_malformed_signature( )
    external view
    {
        bytes32 hash                  =  keccak256("VALID_HASH");
        bytes memory malformed_sig    =  hex"deadbeef";

        bool is_valid  =  SignatureValidator.is_valid_ecdsa_signature( signer, hash, malformed_sig );

        assertFalse( is_valid, "Malformed ECDSA signature should be rejected." );
    }

    function test_is_valid_ecdsa_signature_rejects_empty_signature( )
    external view
    {
        bytes32 hash  =  keccak256("VALID_HASH");

        bool is_valid  =  SignatureValidator.is_valid_ecdsa_signature( signer, hash, "" );

        assertFalse( is_valid, "Empty ECDSA signature should be rejected." );
    }

    function test_is_valid_contract_signature_accepts_valid_eip1271_wallet( )
    external
    {
        bytes32 hash            =  keccak256("VALID_HASH");
        bytes memory signature  =  "VALID_SIGNATURE";

        valid_wallet.set_valid_signature( hash, signature );

        bool is_valid  =  SignatureValidator.is_valid_contract_signature( address(valid_wallet), hash, signature );

        assertTrue( is_valid, "Valid EIP-1271 wallet should be accepted." );
    }

    function test_is_valid_contract_signature_rejects_invalid_eip1271_wallet( )
    external
    {
        bytes32 hash            =  keccak256("VALID_HASH");
        bytes memory signature  =  "VALID_SIGNATURE";

        invalid_wallet.set_valid_signature( hash, signature );
        invalid_wallet.set_invalid_magic_value( );

        bool is_valid  =  SignatureValidator.is_valid_contract_signature( address(invalid_wallet), hash, signature );

        assertFalse( is_valid, "EIP-1271 wallet returning wrong magic value should be rejected." );
    }

    function test_is_valid_contract_signature_rejects_reverting_eip1271_wallet( )
    external
    {
        bytes32 hash            =  keccak256("VALID_HASH");
        bytes memory signature  =  "VALID_SIGNATURE";

        reverting_wallet.set_valid_signature( hash, signature );
        reverting_wallet.set_should_revert( true );

        bool is_valid  =  SignatureValidator.is_valid_contract_signature( address(reverting_wallet), hash, signature );

        assertFalse( is_valid, "Reverting EIP-1271 wallet should be rejected." );
    }

    function test_is_valid_contract_signature_rejects_eoa( )
    external view
    {
        bytes32 hash            =  keccak256("VALID_HASH");
        bytes memory signature  =  "VALID_SIGNATURE";

        bool is_valid  =  SignatureValidator.is_valid_contract_signature( signer, hash, signature );

        assertFalse( is_valid, "EOA should be rejected by contract signature path." );
    }

    function test_is_valid_contract_signature_rejects_zero_address( )
    external view
    {
        bytes32 hash            =  keccak256("VALID_HASH");
        bytes memory signature  =  "VALID_SIGNATURE";

        bool is_valid  =  SignatureValidator.is_valid_contract_signature( address(0), hash, signature );

        assertFalse( is_valid, "Zero address should be rejected by contract signature path." );
    }

    function test_is_valid_contract_signature_rejects_precompile_address( )
    external view
    {
        bytes32 hash            =  keccak256("VALID_HASH");
        bytes memory signature  =  "VALID_SIGNATURE";

        bool is_valid  =  SignatureValidator.is_valid_contract_signature( address(0x09), hash, signature );

        assertFalse( is_valid, "Precompile address should be rejected by contract signature path." );
    }

    function test_is_valid_contract_signature_rejects_contract_returning_wrong_magic_value( )
    external
    {
        bytes32 hash            =  keccak256("VALID_HASH");
        bytes memory signature  =  "VALID_SIGNATURE";

        invalid_wallet.set_valid_signature( hash, signature );
        invalid_wallet.set_invalid_magic_value( );

        bool is_valid  =  SignatureValidator.is_valid_contract_signature( address(invalid_wallet), hash, signature );

        assertFalse( is_valid, "Contract returning wrong EIP-1271 magic value should be rejected." );
    }

    function _sign_hash( bytes32 hash, uint256 private_key ) private pure returns ( bytes memory signature )
    {
        ( uint8 v, bytes32 r, bytes32 s )  =  vm.sign( private_key, hash );

        signature  =  abi.encodePacked( r, s, v );
    }
}
