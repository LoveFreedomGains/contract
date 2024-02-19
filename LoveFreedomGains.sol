// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "contracts/Ownable.sol";

library SafeMath {
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a, "SafeMath: addition overflow");
    return c;
  }
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a, "SafeMath: subtraction overflow");
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
    require(b > 0, "SafeMath: division by zero");
    uint256 c = a / b;
    return c;
  }
}

contract LoveFreedomGains is Ownable {
  using SafeMath for uint256;

  string public name = "LoveFreedomGains";
  string public symbol = "LFGains";
  uint8 public decimals = 18;
  uint256 public totalSupply = 202442000000000000000000000000;
  uint256 public circulatingSupply = 202442000000000000000000000000;

  mapping(address => uint256) public balances;
  mapping(address => mapping(address => uint256)) public allowed;
  mapping(address => bool) public isTaxExempt;

  address public constant burnAddress = 0x000000000000000000000000000000000000dEaD;
  address payable public marketingWallet; // Marketing wallet address
  address payable public lpAddress; // LP address


  constructor() {
    marketingWallet = payable(0x7F3B220Dab6eCcD231c8736d04700B1442d5b4db); // Set marketing wallet address here
    balances[owner()] = totalSupply;
    circulatingSupply = totalSupply;

  }

  /**
     * @dev Renounces ownership of the contract. This operation is irreversible.
     * Only the current owner can call this function.
     */
    function renounceOwnership() public onlyOwner override {
    super.renounceOwnership();
  }
  
  function setTaxExemption(address _address, bool _isExempt) external onlyOwner {
        isTaxExempt[_address] = _isExempt;
  }

  function withdrawBNB(uint256 amount) external onlyOwner {
    payable(owner()).transfer(amount);
  }

  function transfer(address _to, uint256 _value) public returns (bool success) {
    require(_to != address(0), "Invalid address");
    require(_value > 0, "Invalid value");
    require(_value <= balances[msg.sender], "Insufficient balance");

    uint256 burnFee = 0;
    uint256 contractFee = 0;
    uint256 marketingFee = 0;
    uint256 feesTotal = 0;

    // Check if sender is exempt from tax
    if (!isTaxExempt[msg.sender]) {
        // Calculate fees only for non-exempt addresses
        burnFee = _value.mul(1).div(100); // 1% burn fee
        contractFee = _value.mul(1).div(100); // 1% contract fee
        marketingFee = _value.mul(3).div(100); // 3% marketing fee
        feesTotal = burnFee.add(contractFee).add(marketingFee);
    }

    uint256 transferAmount = _value.sub(feesTotal);

    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(transferAmount);
    
    // Distribute fees if applicable
    if(feesTotal > 0) {
        balances[burnAddress] = balances[burnAddress].add(burnFee);
        balances[lpAddress] = balances[lpAddress].add(contractFee);
        balances[marketingWallet] = balances[marketingWallet].add(marketingFee);
        circulatingSupply = circulatingSupply.sub(burnFee); // Reduce circulating supply by the burn amount
        // Emit events for fee transfers
        emit Transfer(msg.sender, burnAddress, burnFee);
        emit Transfer(msg.sender, lpAddress, contractFee);
        emit Transfer(msg.sender, marketingWallet, marketingFee);
    }

    emit Transfer(msg.sender, _to, transferAmount);

    return true;

}

function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
    require(_from != address(0), "Invalid sender address");
    require(_to != address(0), "Invalid recipient address");
    require(_value > 0, "Invalid value");
    require(_value <= balances[_from], "Insufficient balance");
    require(_value <= allowed[_from][msg.sender], "Insufficient allowance");

    uint256 burnFee = 0;
    uint256 contractFee = 0;
    uint256 marketingFee = 0;
    uint256 feesTotal = 0;

    // Check if sender is exempt from tax
    if (!isTaxExempt[_from]) {
        // Calculate fees for non-exempt addresses
        burnFee = _value.mul(1).div(100); // 1% burn fee
        contractFee = _value.mul(1).div(100); // 1% contract fee
        marketingFee = _value.mul(3).div(100); // 3% marketing fee
        feesTotal = burnFee.add(contractFee).add(marketingFee);
    }

    uint256 transferAmount = _value.sub(feesTotal);

    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(transferAmount);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    
    // Distribute fees if applicable
    if(feesTotal > 0) {
        balances[burnAddress] = balances[burnAddress].add(burnFee);
        balances[lpAddress] = balances[lpAddress].add(contractFee);
        balances[marketingWallet] = balances[marketingWallet].add(marketingFee);
        circulatingSupply = circulatingSupply.sub(burnFee); // Reduce circulating supply by the burn amount
        // Emit events for fee transfers
        emit Transfer(_from, burnAddress, burnFee);
        emit Transfer(_from, lpAddress, contractFee);
        emit Transfer(_from, marketingWallet, marketingFee);
    }

    emit Transfer(_from, _to, transferAmount);

    return true;
}

function approve(address _spender, uint256 _value) public returns (bool success) {
require(_spender != address(0), "Invalid spender address");
allowed[msg.sender][_spender] = _value;
emit Approval(msg.sender, _spender, _value);
return true;
}

function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
require(_owner != address(0), "Invalid owner address");
require(_spender != address(0), "Invalid spender address");
return allowed[_owner][_spender];
}

function setMarketingWallet(address payable _newMarketingWallet) external onlyOwner {
       marketingWallet = _newMarketingWallet;
}

function setLPAddress(address payable _lpAddress) external onlyOwner {
        lpAddress = _lpAddress;
}

function balanceOf(address _owner) public view returns (uint256 balance) {
require(_owner != address(0), "Invalid address");
return balances[_owner];
}

function burn(uint256 _value) public {
require(_value > 0, "Invalid value");
require(balances[msg.sender] >= _value, "Insufficient balance");
balances[msg.sender] = balances[msg.sender].sub(_value);
circulatingSupply = circulatingSupply.sub(_value);

emit Transfer(msg.sender, burnAddress, _value);
}

event Transfer(address indexed _from, address indexed _to, uint256 _value);
event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

