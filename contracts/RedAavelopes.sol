// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@aave/protocol-v2/contracts/interfaces/ILendingPoolAddressesProvider.sol";
import "@aave/protocol-v2/contracts/interfaces/ILendingPool.sol";
import "hardhat/console.sol";

contract RedAavelopes is ERC721 {
    using Counters for Counters.Counter;

    address private constant DAI_ADDRESS = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    ILendingPoolAddressesProvider private constant LENDING_POOL_PROVIDER = ILendingPoolAddressesProvider(address(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5));

    Counters.Counter private _tokenIds;
    mapping (uint256 => uint256) private _balances;

    constructor() public ERC721("Red Aavelopes", "REDAAVE") {
        console.log("Address is %s", LENDING_POOL_PROVIDER.getLendingPool());
    }

    function mintWithDai(uint256 amount) public returns(uint256) {
        IERC20(DAI_ADDRESS).transferFrom(msg.sender, address(this), amount);

        ILendingPool lendingPool = ILendingPool(LENDING_POOL_PROVIDER.getLendingPool());

        IERC20(DAI_ADDRESS).approve(address(lendingPool), amount);
        lendingPool.deposit(DAI_ADDRESS, amount, address(this), 0);

        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();

        _safeMint(msg.sender, newItemId);

        _balances[newItemId] += amount;

        return newItemId;
    }

    function burn(uint256 _tokenId) public {
        require(_isApprovedOrOwner(_msgSender(), _tokenId), "Only owner or approved can burn");

        _burn(_tokenId);

        ILendingPool lendingPool = ILendingPool(LENDING_POOL_PROVIDER.getLendingPool());
        lendingPool.withdraw(DAI_ADDRESS, _balances[_tokenId], msg.sender); //TODO add interest calc to amount hah

        _balances[_tokenId] = 0;
    }
}