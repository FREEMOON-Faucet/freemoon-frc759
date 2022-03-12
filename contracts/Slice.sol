// SPDX-License-Identifier: ChaingeFinance
pragma solidity ^0.8.12;

import "./libraries/SafeMath.sol";
import "./interfaces/ISlice.sol";
import "./Context.sol";


contract Slice is Context, ISlice {
    using SafeMath for uint256;
    
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _start;
    uint256 private _end;

    bool private initialized;

    address public parent;

    constructor () {}

    function initialize(string memory name_, string memory symbol_, uint8 decimals_, uint256 start_, uint256 end_) public override {
        require(initialized == false, "Slice: already been initialized");
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _start = start_;
        _end = end_;
        parent = _msgSender();
        
        initialized = true;
    }

    modifier whenNotPaused() {
        require(IFRC759(parent).paused() == false, "Slice: contract paused");
        _;
    }

    modifier whenAllowSliceTransfer() {
        require(IFRC759(parent).allowSliceTransfer() == true, "Slice: slice transfer not allowed");
        _;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function startTime() public view override returns(uint256) {
        return _start;
    }
    
    function endTime() public view override returns(uint256) {
        return _end;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
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

    function transferFrom(address sender, address recipient, uint256 amount) public virtual whenAllowSliceTransfer override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "Slice: too less allowance"));
        return true;
    }

    function transfer(address recipient, uint256 amount) public virtual override whenAllowSliceTransfer returns (bool) {
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
        require(balanceOf(account) >=  amount, "Slice: burn amount exceeds balance");
        _burn(account, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual whenNotPaused {
        require(IFRC759(parent).blocked(sender) == false, "Slice: sender blocked");
        require(IFRC759(parent).blocked(recipient) == false, "Slice: recipient blocked");
        require(sender != address(0), "Slice: transfer from the zero address");
        require(recipient != address(0), "Slice: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount, "Slice: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual whenNotPaused {
        require(owner != address(0), "Slice: approve from the zero address");
        require(spender != address(0), "Slice: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _mint(address account, uint256 amount) internal virtual whenNotPaused {
        require(IFRC759(parent).blocked(account) == false, "Slice: account blocked");
        require(account != address(0), "Slice: mint to the zero address");
        require(amount > 0, "Slice: invalid amount to mint");
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual whenNotPaused {
        _balances[account] = _balances[account].sub(amount, "Slice: transfer amount exceeds balance");
        emit Transfer(account, address(0), amount);
    }
}
