// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@aave/protocol-v2/contracts/interfaces/ILendingPoolAddressesProvider.sol";
import "@aave/protocol-v2/contracts/interfaces/ILendingPool.sol";
import "hardhat/console.sol";

contract RedAavelopes is ERC721 {
    //TODO: SafeMath for, you know, safety....

    address private constant DAI_ADDRESS = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    ILendingPoolAddressesProvider private constant LENDING_POOL_PROVIDER = ILendingPoolAddressesProvider(address(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5));

    mapping (uint256 => uint256) private _balances;
    mapping (uint256 => uint256) private _depositTimestamps;
    mapping (uint256 => uint256) private _unlockTimestamps;

    address private _owner;

    constructor() public ERC721("Red Aavelopes", "REDAAVE") {
        _owner = msg.sender;
    }

    function mintWithDai(uint256 _amount, uint256 _unlockTimestamp) public returns(uint256) {
        require(_amount > 0, "Amount must be bigger than 0");
        require(_unlockTimestamp > block.timestamp, "Unlock timestamp must be in the future");

        // Move tokens from user to contract
        IERC20(DAI_ADDRESS).transferFrom(msg.sender, address(this), _amount);

        // Deposit tokens with AAVE
        ILendingPool lendingPool = ILendingPool(LENDING_POOL_PROVIDER.getLendingPool());
        IERC20(DAI_ADDRESS).approve(address(lendingPool), _amount);
        lendingPool.deposit(DAI_ADDRESS, _amount, address(this), 0);

        // Mint NFT
        uint256 newItemId = totalSupply();

        _safeMint(msg.sender, newItemId);

        // Update structures
        _balances[newItemId] += _amount;
        _depositTimestamps[newItemId] = block.timestamp;
        _unlockTimestamps[newItemId] = _unlockTimestamp;

        return newItemId;
    }

    function burn(uint256 _tokenId) public {
        require(_isApprovedOrOwner(_msgSender(), _tokenId), "Only owner or approved can burn");
        require(block.timestamp >= _unlockTimestamps[_tokenId], "Can't burn yet - wait....");

        // Burn NFT
        _burn(_tokenId);

        // Get back DAI from AAVE and send to burner
        ILendingPool lendingPool = ILendingPool(LENDING_POOL_PROVIDER.getLendingPool());
        lendingPool.withdraw(DAI_ADDRESS, _getAmountAsOfNow(_tokenId), msg.sender);

        _balances[_tokenId] = 0;
        _depositTimestamps[_tokenId] = 0;
        _unlockTimestamps[_tokenId] = 0;
    }

    function _getAmountAsOfNow(uint256 _tokenId) internal view returns(uint256) {
        return _getAmountAsOf(_tokenId, block.timestamp - _depositTimestamps[_tokenId]);
    }

    function _getAmountAsOfUnlock(uint256 _tokenId) internal view returns(uint256) {
        return _getAmountAsOf(_tokenId, _unlockTimestamps[_tokenId] - _depositTimestamps[_tokenId]);
    }

    function _getAmountAsOf(uint256 _tokenId, uint256 _timePassedInSeconds) internal view returns(uint256) {
        // ILendingPool lendingPool = ILendingPool(LENDING_POOL_PROVIDER.getLendingPool());
        // DataTypes.ReserveData memory reserve = lendingPool.getReserveData(DAI_ADDRESS);

        // TODO: rough apy between blocks calculation for purposes of hack, use real rate in real life
        uint256 amount = _balances[_tokenId] + (_balances[_tokenId] * (_timePassedInSeconds * 2  / 31557600)) / 100;
        return amount;
    }

    function getSvg(uint256 _tokenId) public view returns(string memory) {


        return string(abi.encodePacked('<svg width="374" height="599" viewBox="0 0 374 599" fill="none" xmlns="http://www.w3.org/2000/svg">    <rect width="374" height="599" fill="white"/>    <path d="M35 10H339C352.807 10 364 21.1929 364 35V564C364 577.807 352.807 589 339 589H35C21.1929 589 10 577.807 10 564V35C10 21.1929 21.1929 10 35 10Z" fill="#E96A4C" stroke="#44413D" stroke-width="20"/>    <g style="mix-blend-mode:multiply">        <path d="M18 65C18 48.4315 31.4315 35 48 35H325C341.569 35 355 48.4315 355 65V148.973C355 160.838 348.986 171.882 338.427 177.294C311.703 190.993 255.085 215 186.5 215C117.915 215 61.2968 190.993 34.5726 177.294C24.0143 171.882 18 160.838 18 148.973V65Z" fill="#E96A4C"/>    </g>    <path d="M10 132C29.7216 151.333 91.6375 190 181.528 190C271.419 190 339.964 151.333 363 132" stroke="#44413D" stroke-width="20" stroke-linecap="round" stroke-linejoin="round"/>    <path d="M256 178C256 216.108 225.108 247 187 247C148.892 247 118 216.108 118 178C118 139.892 148.892 109 187 109C225.108 109 256 139.892 256 178Z" fill="#F8E14B" stroke="#44413D" stroke-width="20"/>    <g style="mix-blend-mode:multiply">        <path d="M186.5 217C154.1 217 134.667 196.333 129 186C132.833 203.167 149.7 235.5 186.5 235.5C223.3 235.5 242.5 203.167 247.5 186C240.667 196.333 218.9 217 186.5 217Z" fill="#FCE44D"/>    </g><text x="160" y="295" fill="black" font-family="Arial, Helvetica, sans-serif" font-weight="bold" font-size="28">', uint2str(_getAmountAsOfNow(_tokenId) / (10 ** 18)), '</text><text x="160" y="340" fill="black" font-family="Arial, Helvetica, sans-serif" font-weight="bold" font-size="26">aDai</text></svg>'));
    }

    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}