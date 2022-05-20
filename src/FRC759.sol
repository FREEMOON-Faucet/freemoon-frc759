// SPDX-License-Identifier: ChaingeFinance
pragma solidity ^0.8.13;

import "./Slice.sol";
import "./libraries/SafeMath.sol";
import "./interfaces/IFRC759.sol";
import "./interfaces/ISlice.sol";
import "./utils/Context.sol";


contract FRC759 is Context, IFRC759 {
    using SafeMath for uint256;

    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    uint256 public maxSupply;
    address public fullTimeToken;

    bool public paused;
    bool public allowSliceTransfer;
    mapping(address => bool) public blocked;

    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint256 maxSupply_) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
        maxSupply = maxSupply_;

        fullTimeToken = createSlice(MIN_TIME, MAX_TIME);
    }

    uint256 public constant MIN_TIME = 0;
    uint256 public constant MAX_TIME = 18446744073709551615;

    mapping(uint256 => mapping(uint256 => address)) internal timeSlice;

    function _mint(address account, uint256 amount) internal {
        if (maxSupply != 0) {
            require(totalSupply.add(amount) <= maxSupply, "FRC759: maxSupply exceeds");
        }
        totalSupply = totalSupply.add(amount);
        ISlice(fullTimeToken).mint(account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        totalSupply = totalSupply.sub(amount);
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
        ISlice(fullTimeToken).approveByParent(sender, _msgSender(), ISlice(fullTimeToken).allowance(sender, _msgSender()).sub(amount, "FRC759: too less allowance"));
        return true;
    }

    function transferFromData(address sender, address recipient, uint256 amount, bytes calldata data) public virtual returns (bool) {
        ISlice(fullTimeToken).transferByParent(sender, recipient, amount);
        ISlice(fullTimeToken).approveByParent(sender, _msgSender(), ISlice(fullTimeToken).allowance(sender, _msgSender()).sub(amount, "FRC759: too less allowance"));
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
        ISlice(fullTimeToken).approveByParent(sender, _msgSender(), ISlice(fullTimeToken).allowance(sender, _msgSender()).sub(amount, "FRC759: too less allowance"));
        return true;
    }

    function timeSliceTransfer(address recipient, uint256 amount, uint256 start, uint256 end) public virtual returns (bool) {
        address sliceAddr = timeSlice[start][end];
        require(sliceAddr != address(0), "FRC759: slice not exists");
        ISlice(sliceAddr).transferByParent(_msgSender(), recipient, amount);
        return true;
    }

    function createSlice(uint256 start, uint256 end) public returns (address sliceAddr) {
       require(end > start, "FRC759: tokenEnd must be greater than tokenStart");
       require(end <= MAX_TIME, "FRC759: tokenEnd must be less than MAX_TIME");
       require(timeSlice[start][end] == address(0), "FRC759: slice already exists");
        bytes memory bytecode = type(Slice).creationCode;

        bytes32 salt = keccak256(abi.encodePacked(start, end));
    
        assembly {
            sliceAddr := create2(0, add(bytecode, 32), mload(bytecode), salt)
            if iszero(extcodesize(sliceAddr)) {revert(0, 0)}
        }

        ISlice(sliceAddr).initialize(string(abi.encodePacked("TF_", name)), string(abi.encodePacked("TF_", symbol)), decimals, start, end);
        
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
        if (firstStart <= block.timestamp) {
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

    function getSlice(uint256 start, uint256 end) public view returns (address) {
        return timeSlice[start][end];
    }
}

