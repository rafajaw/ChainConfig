

ChainConfig Deployment
======================

Contract address (same on every chain):

    0x5Afec0de00EB1c5323C7faA110f67499F744467b


Deploy to a new chain
---------------------

Anyone can deploy ChainConfig to any EVM chain that supports the London
hard fork (no exotic opcodes required). No build toolchain needed — just
send the calldata.

    1. Send the contents of calldata.txt to the CREATE2 factory:

       0x4e59b44847b379578588920cA78FbF26c0B4956C

    2. The contract will deploy to the same address, guaranteed by CREATE2.

Example using cast:

    cast send 0x4e59b44847b379578588920cA78FbF26c0B4956C \
        --rpc-url <RPC_URL> \
        --private-key <KEY> \
        --gas-limit 4000000 \
        "$(cat calldata.txt)"

The calldata contains the salt and compiled initcode. ChainConfig has no
constructor arguments — the canonical EIP-712 domain name and version are
compiled into the bytecode as constants.


CREATE2 parameters
------------------

    Factory:        0x4e59b44847b379578588920cA78FbF26c0B4956C
    Salt:           0xcabdd74eca000000cabd07000000000000000000000000000000000000000000
    Init Code Hash: 0x645aea6490075d66530b3f76be94e7970ab0ebfa0328300879e73cf8d79bedbe


Constructor arguments
---------------------

None. ChainConfig is parameterless — every deployment on every chain has
identical initcode, which is the whole point.


Trust model
-----------

ChainConfig has no owner, no admin, no upgrade path, and no privileged role.
Anyone can deploy to any chain that does not yet have the canonical address
occupied; the deployer has no special authority over the resulting contract.

Consumers must hardcode (or otherwise deterministically choose) the trusted
config signer for each key they read. ChainConfig itself does not decide
what is true — the signer does.
