// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;


library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }
 
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
 
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}


abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}


interface ISlice {
    event Transfer(address indexed sender, address indexed recipient, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function startTime() external view returns (uint256); 
    function endTime() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function mint(address account, uint256 amount) external;
    function burn(address account, uint256 amount) external;
    function initialize(string memory name, string memory symbol, uint8 decimals, uint256 start, uint256 end) external;
    function approveByParent(address owner, address spender, uint256 amount) external returns (bool);
    function transferByParent(address sender, address recipient, uint256 amount) external returns (bool);
}


interface IFRC759 {
    event DataDelivery(bytes data);
    event SliceCreated(address indexed sliceAddr, uint256 start, uint256 end);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function maxSupply() external view returns (uint256);
    function fullTimeToken() external view returns (address);

    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function timeSliceTransferFrom(address spender, address recipient, uint256 amount, uint256 start, uint256 end) external returns (bool);
    function timeSliceTransfer(address recipient, uint256 amount, uint256 start, uint256 end) external returns (bool);

    function createSlice(uint256 start, uint256 end) external returns (address);
    function sliceByTime(uint256 amount, uint256 sliceTime) external;
    function mergeSlices(uint256 amount, address[] calldata slices) external;
    function getSlice(uint256 start, uint256 end) external view returns (address);
    function timeBalanceOf(address account, uint256 start, uint256 end) external view returns (uint256);

    function paused() external view returns (bool);
    function allowSliceTransfer() external view returns (bool);
    function blocked(address account) external view returns (bool);

    function MIN_TIME() external view returns (uint256);
    function MAX_TIME() external view returns (uint256);
}


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
 
        for (uint256 i = 0; i < slices.length; i++) {
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