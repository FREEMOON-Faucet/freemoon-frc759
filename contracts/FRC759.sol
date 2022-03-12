
// SPDX-License-Identifier: ChaingeFinance
pragma solidity ^0.8.12;

import "./libraries/SafeMath.sol";
import "./interfaces/ISlice.sol";
import "./Context.sol";


contract FRC759 is Context, IFRC759 {
    using SafeMath for uint256;

    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply;
    uint256 private _maxSupply;
    address public fullTimeToken;

    bool internal _paused;
    bool internal _allowSliceTransfer;
    mapping(address => bool) internal _blockList;

    constructor (
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 maxSupply_
    ) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _maxSupply = maxSupply_;

        fullTimeToken = createSlice(MIN_TIME, MAX_TIME);
    }

    uint256 public constant MIN_TIME = 0;
    uint256 public constant MAX_TIME = 18446744073709551615;

    mapping(uint256 => mapping(uint256 => address)) internal timeSlice;

    function paused() public override view returns(bool) {
        return _paused;
    }

    function allowSliceTransfer() public override view returns(bool) {
        return _allowSliceTransfer;
    }

    function blocked(address account) public override view returns (bool) {
        return _blockList[account];
    }

    function _setPaused(bool paused_) internal {
        _paused = paused_;
    }

    function _setSliceTransfer(bool allowed_) internal {
        _allowSliceTransfer = allowed_;
    }

    function _setBlockList(address account_, bool blocked_) internal {
        _blockList[account_] = blocked_;
    }

    function name() public override view  returns (string memory) {
        return _name;
    }
    function symbol() public override view returns (string memory) {
        return _symbol;
    }
    function decimals() public override view returns (uint8) {
        return _decimals;
    }
    function totalSupply() public override view returns (uint256) {
        return _totalSupply;
    }
    function maxSupply() public override view returns (uint256) {
        return _maxSupply;
    }

    function _mint(address account, uint256 amount) internal {
        if (_maxSupply != 0) {
            require(_totalSupply.add(amount) <= _maxSupply, "FRC759: maxSupply exceeds");
        }
        _totalSupply = _totalSupply.add(amount);
        ISlice(fullTimeToken).mint(account, amount);
    }
    function _burn(address account, uint256 amount) internal {
        ISlice(fullTimeToken).burn(account, amount);
    }

    function _burnSlice(address account, uint256 amount, uint256 start, uint256 end) internal {
        address sliceAddr = timeSlice[start][end];
        require(sliceAddr != address(0), "FRC759: slice not exists");
        ISlice(sliceAddr).burn(account, amount);
    }

    function balanceOf(address account) public view returns (uint256) {
        return ISlice(fullTimeToken).balanceOf(account);
    }

    function timeBalanceOf(address account, uint256 start, uint256 end) public view returns (uint256) {
        address sliceAddr = timeSlice[start][end];
        require(sliceAddr != address(0), "FRC759: slice not exists");
        return ISlice(sliceAddr).balanceOf(account);
    }
    
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return ISlice(fullTimeToken).allowance(owner, spender);
    }

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        return ISlice(fullTimeToken).approveByParent(_msgSender(), spender, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual returns (bool) {
        ISlice(fullTimeToken).transferByParent(sender, recipient, amount);
        ISlice(fullTimeToken).approveByParent(sender, _msgSender(), 
        ISlice(fullTimeToken).allowance(sender, _msgSender()).sub(amount, "FRC759: too less allowance"));
        return true;
    }

    function transferFromData(address sender, address recipient, uint256 amount, bytes calldata data) public virtual returns (bool) {
        ISlice(fullTimeToken).transferByParent(sender, recipient, amount);
        ISlice(fullTimeToken).approveByParent(sender, _msgSender(), 
        ISlice(fullTimeToken).allowance(sender, _msgSender()).sub(amount, "FRC759: too less allowance"));
        emit DataDelivery(data);
        return true;
    }

    function transfer(address recipient, uint256 amount) public virtual returns (bool) {
        ISlice(fullTimeToken).transferByParent(_msgSender(), recipient, amount);
        return true;
    }

    function transferData(address recipient, uint256 amount, bytes calldata data) public virtual returns (bool) {
        ISlice(fullTimeToken).transferByParent(_msgSender(), recipient, amount);
        emit DataDelivery(data);
        return true;
    }

    function timeSliceTransferFrom(address sender, address recipient, uint256 amount, uint256 start, uint256 end) public virtual returns (bool) {
        address sliceAddr = timeSlice[start][end];
        require(sliceAddr != address(0), "FRC759: slice not exists");
        ISlice(sliceAddr).transferByParent(sender, recipient, amount);
        ISlice(fullTimeToken).approveByParent(sender, _msgSender(), 
            ISlice(fullTimeToken).allowance(sender, _msgSender()).sub(amount, "FRC759: too less allowance"));
	    return true;
    }

    function timeSliceTransfer(address recipient, uint256 amount, uint256 start, uint256 end)  public virtual returns (bool) {
        address sliceAddr = timeSlice[start][end];
        require(sliceAddr != address(0), "FRC759: slice not exists");
        ISlice(sliceAddr).transferByParent(_msgSender(), recipient, amount);
        return true;
    }

    function createSlice(uint256 start, uint256 end) public returns(address sliceAddr) {
       require(end > start, "FRC759: tokenEnd must be greater than tokenStart");
       require(end <= MAX_TIME, "FRC759: tokenEnd must be less than MAX_TIME");
       require(timeSlice[start][end] == address(0), "FRC759: slice already exists");
        bytes memory bytecode = type(Slice).creationCode;

        bytes32 salt = keccak256(abi.encodePacked(start, end));
    
        assembly {
            sliceAddr := create2(0, add(bytecode, 32), mload(bytecode), salt)
            if iszero(extcodesize(sliceAddr)) {revert(0, 0)}
        }

        ISlice(sliceAddr).initialize(string(abi.encodePacked("TF_", _name)), 
            string(abi.encodePacked("TF_", _symbol)), _decimals, start, end);
        
        timeSlice[start][end] = sliceAddr;

        emit SliceCreated(sliceAddr, start, end);
    }

    function sliceByTime(uint256 amount, uint256 sliceTime) public {
        require(sliceTime >= block.timestamp, "FRC759: sliceTime must be greater than blockTime");
        require(sliceTime < MAX_TIME, "FRC759: sliceTime must be smaller than blockTime");
        require(amount > 0, "FRC759: amount cannot be zero");

        address _left = getSlice(MIN_TIME, sliceTime);
        address _right = getSlice(sliceTime, MAX_TIME);

        if (_left == address(0)) {
            _left = createSlice(MIN_TIME, sliceTime);
        }
        if (_right == address(0)) {
            _right = createSlice(sliceTime, MAX_TIME);
        }

        ISlice(fullTimeToken).burn(_msgSender(), amount);

        ISlice(_left).mint(_msgSender(), amount);
        ISlice(_right).mint(_msgSender(), amount);
    }
    
    function mergeSlices(uint256 amount, address[] calldata slices) public {
        require(slices.length > 0, "FRC759: empty slices array");
        require(amount > 0, "FRC759: amount cannot be zero");

        uint256 lastEnd = MIN_TIME;
    
        for(uint256 i = 0; i < slices.length; i++) {
            uint256 _start = ISlice(slices[i]).startTime();
            uint256 _end = ISlice(slices[i]).endTime();
            require(slices[i] == getSlice(_start, _end), "FRC759: invalid slice address");
            require(lastEnd == 0 || _start == lastEnd, "FRC759: continuous slices required");
            ISlice(slices[i]).burn(_msgSender(), amount);
            lastEnd = _end;       
        }

        uint256 firstStart = ISlice(slices[0]).startTime();
        address sliceAddr;
        if (firstStart <= block.timestamp){
            firstStart = MIN_TIME;
        }

        if (lastEnd > block.timestamp) {
            sliceAddr = getSlice(firstStart, lastEnd);
            if (sliceAddr == address(0)) {
                sliceAddr = createSlice(firstStart, lastEnd);
            }
        }

        if (sliceAddr != address(0)) {
            ISlice(sliceAddr).mint(_msgSender(), amount);
        }
    }

    function getSlice(uint256 start, uint256 end) public view returns(address) {
        return timeSlice[start][end];
    }
}
