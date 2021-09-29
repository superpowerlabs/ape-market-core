Light Design/Architecture of Ape Market Smart Contracts

The contracts whose names start with I are the interface of corresponding contracts, unless 
there are special elements in the interface, we will only talk about the actual contracts. 

SaleDB is the core storage contract, it stores the setup data and vesting schedules of all the sales. 
It also contains the all the investment approvals.
SaleDB contains the minimum operations that modifies the underlying data storages. 
ISaleDB contains the definition of Setup, which are the list of parameters specified by 
the seller, and VestingStep, which specifies one step in the vesting schedule.
The design goal of SaleDB is to be minimal and stable - since it contains the data, we want to 
minimize the chance of it needs to be changed/redeployed in the future. 
 
SaleData is a wrapper over SaleDB.  it contains more complicated operations. All the non-view functions
of SaleDB can only be accessed through SaleData.

Sale represents each individual sale.

SaleFactory manages the creation of Sale. 

SaleSetupHasher provides functions to pack sale parameters.

TokneRegistry provides a registry of multiple payment tokens. 

SANFT is based on ERC721Enumerable and manages basic operation of the smart agreements, such as mint, burn, and access

SANFTManager manages more complicated operations on smart agreements, such as merge, split, vest and swap

ApeRegistry is a contract that keeps track of the most recent contract address of
the keep components.

RegistryUser is an abstract contract that allow will push a contract's new address to its users 

only one instance of SaleDB, SaleData, SaleFactory, should be valid/active at any given moment

The following is the workflow of setting up the system to be ready for use.

deploy ApeRegistry
deploy Profile, SaleSetupHasher, SaleDB, SaleData, SaleFactory, TokenRegistry, SANFT, SANFTManager 
register the above contracts with ApeRegistry 
