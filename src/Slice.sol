// SPDX-License-Identifier: ChaingeFinance
pragma solidity ^0.8.13;

import "./libraries/SafeMath.sol";
import "./interfaces/ISlice.sol";
import "./interfaces/IFRC759.sol";
import "./utils/Context.sol";


contract Slice is Context, ISlice {
    using SafeMath for uint256;
 
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public startTime;
    uint256 public endTime;

    bool private initialized;

    address public parent;

    constructor() {}

    function initialize(string memory name_, string memory symbol_, uint8 decimals_, uint256 start_, uint256 end_) public override {
        require(initialized == false, "Slice: already been initialized");
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
        startTime = start_;
        endTime = end_;
        parent = _msgSender();
 
        initialized = true;
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function approveByParent(address owner, address spender, uint256 amount) public virtual override returns (bool) {
        require(_msgSender() == parent, "Slice: caller must be parent");
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), allowance[sender][_msgSender()].sub(amount, "Slice: too less allowance"));
        return true;
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferByParent(address sender, address recipipent, uint256 amount) public virtual override returns (bool) {
        require(_msgSender() == parent, "Slice: caller must be parent");
        _transfer(sender, recipipent, amount);
        return true;
    }

    function mint(address account, uint256 amount) public virtual override {
        require(_msgSender() == parent, "Slice: caller must be parent");
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public override {
        require(_msgSender() == parent, "Slice: caller must be parent");
        require(balanceOf[account] >=  amount, "Slice: burn amount exceeds balance");
        _burn(account, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "Slice: transfer from the zero address");
        require(recipient != address(0), "Slice: transfer to the zero address");

        balanceOf[sender] = balanceOf[sender].sub(amount, "Slice: transfer amount exceeds balance");
        balanceOf[recipient] = balanceOf[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "Slice: approve from the zero address");
        require(spender != address(0), "Slice: approve to the zero address");

        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(amount > 0, "Slice: invalid amount to mint");
        balanceOf[account] = balanceOf[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        balanceOf[account] = balanceOf[account].sub(amount, "Slice: transfer amount exceeds balance");
        emit Transfer(account, address(0), amount);
    }
}