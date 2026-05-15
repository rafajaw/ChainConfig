// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { IERC1271 } from "openzeppelin/contracts/interfaces/IERC1271.sol";


contract MockEIP1271Wallet is IERC1271 {

    bytes32 public valid_hash;
    bytes public valid_signature;
    bytes4 public magic_value;
    bool public should_revert;

    constructor( )
    {
        magic_value  =  IERC1271.isValidSignature.selector;
    }

    function set_valid_signature( bytes32 hash, bytes calldata signature )
    external
    {
        valid_hash       =  hash;
        valid_signature  =  signature;
        magic_value      =  IERC1271.isValidSignature.selector;
        should_revert    =  false;
    }

    function set_invalid_magic_value( )
    external
    {
        magic_value  =  bytes4(0xdeadbeef);
    }

    function set_should_revert( bool value )
    external
    {
        should_revert  =  value;
    }

    function isValidSignature( bytes32 hash, bytes calldata signature )
    external view returns ( bytes4 )
    {
        if(  should_revert  )  revert( "INVALID_SIGNATURE" );

        bytes32 signature_hash        =  keccak256( signature );  // forge-lint: disable-line(asm-keccak256)
        bytes32 valid_signature_hash  =  keccak256( valid_signature );  // forge-lint: disable-line(asm-keccak256)

        if(  hash == valid_hash  &&  signature_hash == valid_signature_hash  )  return magic_value;

        return bytes4(0);
    }
}
