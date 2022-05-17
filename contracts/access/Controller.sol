// SPDX-License-Identifier: ChaingeFinance
pragma solidity ^0.8.13;

import "./Ownable.sol";


abstract contract Controller is Ownable {
    event ControllerAdded(address controller);
    event ControllerRemoved(address controller);
    mapping(address => bool) controllers;

    modifier onlyController {
        require(isController(_msgSender()), "no controller rights");
        _;
    }

    function isController(address _controller) public view returns (bool) {
        return _controller == owner() || controllers[_controller];
    }

    function addController(address _controller) public onlyOwner {
        controllers[_controller] = true;
        emit ControllerAdded(_controller);
    }

    function removeController(address _controller) public onlyOwner {
        controllers[_controller] = false;
        emit ControllerRemoved(_controller);
    }
}
