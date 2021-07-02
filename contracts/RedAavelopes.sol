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

    function getBalance(uint256 _tokenId) public view returns (uint256) {
        return _balances[_tokenId];
    }

    function getDepositTimestamp(uint256 _tokenId) public view returns (uint256) {
        return _depositTimestamps[_tokenId];
    }

    function getUnlockTimestamp(uint256 _tokenId) public view returns (uint256) {
        return _unlockTimestamps[_tokenId];
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
        if (!_exists(_tokenId)) {
            return '🔥';
        } else {
            return string(abi.encodePacked('<svg width="374" height="599" viewBox="0 0 374 599" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M35 10H339C352.807 10 364 21.1929 364 35V564C364 577.807 352.807 589 339 589H35C21.1929 589 10 577.807 10 564V35C10 21.1929 21.1929 10 35 10Z" fill="#E96A4C" stroke="#44413D" stroke-width="20"/>    <g style="mix-blend-mode:multiply">        <g style="mix-blend-mode:multiply">            <path d="M18 65C18 48.4315 31.4315 35 48 35H325C341.569 35 355 48.4315 355 65V148.973C355 160.838 348.986 171.882 338.427 177.294C311.703 190.993 255.085 215 186.5 215C117.915 215 61.2968 190.993 34.5726 177.294C24.0143 171.882 18 160.838 18 148.973V65Z" fill="#E96A4C"/></g></g><path d="M10 132C29.7216 151.333 91.6375 190 181.528 190C271.419 190 339.964 151.333 363 132" stroke="#44413D" stroke-width="20" stroke-linecap="round" stroke-linejoin="round"/>    <path d="M256 178C256 216.108 225.108 247 187 247C148.892 247 118 216.108 118 178C118 139.892 148.892 109 187 109C225.108 109 256 139.892 256 178Z" fill="#2FB9C6" stroke="#44413D" stroke-width="20"/>    <path d="M205 169.447C204.797 159.041 196.339 150.798 186.133 151.004C176.205 151.21 168.203 159.35 168 169.447C168 169.499 168 169.551 168 169.602V169.885V203.913C168.051 205.073 168.988 205.974 170.127 205.923C171.216 205.897 172.077 204.995 172.103 203.913V197.834C172.103 196.675 173.014 195.748 174.154 195.748C175.294 195.748 176.205 196.675 176.205 197.834V200.719C176.205 201.879 177.117 202.806 178.257 202.806C179.396 202.806 180.308 201.879 180.308 200.719V197.834C180.308 196.675 181.22 195.748 182.359 195.748C183.499 195.748 184.411 196.675 184.411 197.834V198.633C184.411 199.792 185.322 200.719 186.462 200.719C187.602 200.719 188.513 199.792 188.513 198.633V197.834C188.564 196.675 189.501 195.774 190.641 195.825C191.73 195.851 192.591 196.752 192.616 197.834V200.719C192.616 201.879 193.528 202.806 194.667 202.806C195.807 202.806 196.719 201.879 196.719 200.719V197.834C196.719 196.675 197.63 195.748 198.77 195.748C199.91 195.748 200.821 196.675 200.821 197.834V203.913C200.821 205.073 201.733 206 202.873 206C204.012 206 204.924 205.073 204.924 203.913V169.576C205 169.551 205 169.499 205 169.447ZM179.675 172.461C177.851 172.461 176.383 170.735 176.383 168.623C176.383 166.511 177.851 164.785 179.675 164.785C181.498 164.785 182.967 166.511 182.967 168.623C182.967 170.735 181.498 172.461 179.675 172.461ZM186.639 177.871C184.993 177.871 183.651 176.866 183.651 175.63C183.651 174.393 184.993 175.14 186.639 175.14C188.285 175.14 189.628 174.393 189.628 175.63C189.628 176.866 188.285 177.871 186.639 177.871ZM193.325 172.461C191.502 172.461 190.033 170.735 190.033 168.623C190.033 166.511 191.502 164.785 193.325 164.785C195.149 164.785 196.617 166.511 196.617 168.623C196.617 170.735 195.149 172.461 193.325 172.461Z" fill="white"/><text font-family="Arial, Helvetica, sans-serif" font-weight="bold" fill="white" font-size="34" y="395" x="115">', uint2str(_getAmountAsOfNow(_tokenId) / (10 ** 18)), 'DAI</text></svg>'));
        }
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