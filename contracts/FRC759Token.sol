
// SPDX-License-Identifier: ChaingeFinance
pragma solidity ^0.8.12;

import "./access/Controller.sol";
import "./FRC759.sol";


contract FRC759Token is Controller, FRC759 {
  constructor (string memory _name, string memory _symbol, uint8 _decimals, uint256 _maxSupply) 
  FRC759(_name, _symbol, _decimals, _maxSupply) {}

  function mint(address account, uint256 amount) public onlyController {
      _mint(account, amount);
  }
  
  function burn(address account, uint256 amount) public onlyController {
     _burn(account, amount);
  }

  function burnSlice(address account, uint256 amount, uint256 start, uint256 end) public onlyController {
     _burnSlice(account, amount, start, end);
  }

  function pause() public onlyController {
      _setPaused(true);
  }

function unpause() public onlyController {
      _setPaused(false);
  }

  function enableSliceTransfer() public onlyController {
      _setSliceTransfer(true);
  }

function disableSliceTransfer() public onlyController {
      _setSliceTransfer(false);
  }

  function blockUser(address account) public onlyController {
      _setBlockList(account, true);
  }

function unblockUser(address account) public onlyController {
      _setBlockList(account, false);
  }
}
