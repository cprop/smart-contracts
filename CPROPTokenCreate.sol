pragma solidity ^0.4.21;

contract owned {
    address public owner;

    function owned() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner public {
        owner = newOwner;
    }
}

contract admined is owned {
    address public admin;

    function admined() public {
        admin = msg.sender;
    }

    modifier onlyAdmin {
        require(msg.sender == admin || msg.sender == owner);
        _;
    }

    function transferAdmin(address newAdmin) onlyOwner public {
        admin = newAdmin;
    }
}

library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  /**
  * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

interface tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) external; }

contract TokenERC20 {
    using SafeMath for uint256;
    // Public variables of the token
    string public name;
    string public symbol;
    uint256 public decimals = 18;
    // 18 decimals is the strongly suggested default, avoid changing it
    uint256 public totalSupply;

    // This creates an array with all balances
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    // This generates a public event on the blockchain that will notify clients
    event Transfer(address indexed from, address indexed to, uint256 value);

    // This notifies clients about the amount burnt
    event Burn(address indexed from, uint256 value);

    /**
     * Constrctor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    function TokenERC20(
        uint256 initialSupply,
        string tokenName,
        uint256 decimalsToken,
        string tokenSymbol
    ) public {
        decimals = decimalsToken;
        totalSupply = initialSupply * 10 ** uint256(decimals);  // Update total supply with the decimal amount
        emit Transfer(0, msg.sender, totalSupply);
        balanceOf[msg.sender] = totalSupply;                // Give the contract itself all initial tokens
        name = tokenName;                                   // Set the name for display purposes
        symbol = tokenSymbol;                               // Set the symbol for display purposes
    }

    /**
     * Internal transfer, only can be called by this contract
     */
    function _transfer(address _from, address _to, uint _value) internal {
        // Prevent transfer to 0x0 address. Use burn() instead
        require(_to != 0x0);
        // Check if the sender has enough
        require(balanceOf[_from] >= _value);
        // Check for overflows
        require(balanceOf[_to] + _value > balanceOf[_to]);
        // Save this for an assertion in the future
        uint previousBalances = balanceOf[_from] + balanceOf[_to];
        // Subtract from the sender
        balanceOf[_from] -= _value;
        // Add the same to the recipient
        balanceOf[_to] += _value;
        emit Transfer(_from, _to, _value);
        // Asserts are used to use static analysis to find bugs in your code. They should never fail
        assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
    }

    /**
     * Transfer tokens
     *
     * Send `_value` tokens to `_to` from your account
     *
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transfer(address _to, uint256 _value) public {
        _transfer(msg.sender, _to, _value);
    }

    /**
     * Transfer tokens from other address
     *
     * Send `_value` tokens to `_to` in behalf of `_from`
     *
     * @param _from The address of the sender
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_value <= allowance[_from][msg.sender]);     // Check allowance
        allowance[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }

    /**
     * Set allowance for other address
     *
     * Allows `_spender` to spend no more than `_value` tokens in your behalf
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     */
    function approve(address _spender, uint256 _value) public
        returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        return true;
    }

    /**
     * Set allowance for other address and notify
     *
     * Allows `_spender` to spend no more than `_value` tokens in your behalf, and then ping the contract about it
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     * @param _extraData some extra information to send to the approved contract
     */
    function approveAndCall(address _spender, uint256 _value, bytes _extraData) public
        returns (bool success) {
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, this, _extraData);
            return true;
        }
    }

    /**
     * Destroy tokens
     *
     * Remove `_value` tokens from the system irreversibly
     *
     * @param _value the amount of money to burn
     */
    function burn(uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value);   // Check if the sender has enough
        balanceOf[msg.sender] -= _value;            // Subtract from the sender
        totalSupply -= _value;                      // Updates totalSupply
        emit Burn(msg.sender, _value);
        return true;
    }

    /**
     * Destroy tokens from other account
     *
     * Remove `_value` tokens from the system irreversibly on behalf of `_from`.
     *
     * @param _from the address of the sender
     * @param _value the amount of money to burn
     */
    function burnFrom(address _from, uint256 _value) public returns (bool success) {
        require(balanceOf[_from] >= _value);                // Check if the targeted balance is enough
        require(_value <= allowance[_from][msg.sender]);    // Check allowance
        balanceOf[_from] -= _value;                         // Subtract from the targeted balance
        allowance[_from][msg.sender] -= _value;             // Subtract from the sender's allowance
        totalSupply -= _value;                              // Update totalSupply
        emit Burn(_from, _value);
        return true;
    }

    function getBalance(address _to) view public returns(uint res) {
        return balanceOf[_to];
    }

}

contract CPROPToken is admined, TokenERC20  {

    uint defaultUnlockTime;
    uint bonusUnlockTime;

    mapping (address => uint) public unlockAt;
    mapping (address => bool) public unlockAtDefault;
    mapping (address => uint256) public bonusReceived;

    function CPROPToken(
        uint256 initialSupply,
        string tokenName,
        uint256 decimalsToken,
        string tokenSymbol,
        uint _defaultUnlockTime,
        uint _bonusUnlockTime
    ) TokenERC20(initialSupply, tokenName, decimalsToken, tokenSymbol) public {
        defaultUnlockTime = _defaultUnlockTime;
        bonusUnlockTime = _bonusUnlockTime;
    }

    // need to check if lockTokenTimeout passed
    function transfer(address _to, uint256 _value) public {
        
        //bonus tokens are additionally locked for 3 months after the end of the sale;
        require(bonusUnlockTime <= now || getBalance(msg.sender) >= _value + bonusReceived[msg.sender]);
        
        bool okay = false;
        // owners are OK
        if(msg.sender == owner)
            okay = true;
        // unlockAt accounts are OK if unlock time is over
        else if(unlockAt[msg.sender] > 0 && unlockAt[msg.sender] <= now)
            okay = true;
        // unlockAtDefault accounts are OK if default unlock time is over
        else if(unlockAt[msg.sender] == 0 && unlockAtDefault[msg.sender] && defaultUnlockTime <= now)
            okay = true;
        // users who did not take part in the sale are OK
        else if(!unlockAtDefault[msg.sender] && unlockAt[msg.sender] == 0)
            okay = true;
            
        require(okay);
        _transfer(msg.sender, _to, _value);        
    }
    
    /**
     * log amount of bonus tokens user received
     *
     * @param _to The address of the user
     * @param _value amount of tokens 
     */
    
    function addBonusReceived(address _to, uint256 _value) onlyOwner public {
        bonusReceived[_to] = _value;
    }
    
    /**
     * get amount of bonus tokens user received
     *
     * @param _to The address of the user
     */
    
    function getBonusReceived(address _to) view public returns(uint res) {
        return bonusReceived[_to];
    }
    
    /**
     * Get date when user can spend their tokens
     *
     * @param _to The address of the user
     * @return res unix timestamp
     */

    function getUnlockTime(address _to) view public returns(uint res) {
        if(unlockAt[_to] > 0) return unlockAt[_to];
        if(unlockAtDefault[_to]) return defaultUnlockTime;
        return 0;
    }
    
    /**
     * Set date when user can spend their tokens
     *
     * @param _to The address of the user
     * @param _unlockAt unix timestamp
     */

    function lockTokensUntil(address _to, uint _unlockAt) onlyOwner public {
        unlockAt[_to] = _unlockAt;
    }

    /**
     * set default date when user can spend their tokens 
     * the option is for users who don't have special lock time
     * 
     * @param _unlockAt unix timestamp
     */
    
    function setDefaultUnlockTime(uint _unlockAt) onlyOwner public {
        defaultUnlockTime = _unlockAt;
    }

    /**
     * transfer tokens from contract to an address
     * 
     * @param _to address where send tokens
     * @param _value amount of tokens
     * @param _unlockAt unix timestamp, date when user can spend new and current tokens.
     */
    
    function transferAndLock(address _to, uint256 _value, uint _unlockAt) onlyOwner public {
        if(_unlockAt == 0) {
            unlockAtDefault[_to] = true;
        } else {
            unlockAt[_to] = _unlockAt;
        }
        _transfer(msg.sender, _to, _value);
    }

    /**
     * transfer tokens from one holder to another
     * requires spenders approval
     * admin/contract owner is available to transfer funds without any approval
     * 
     * @param _from address of account where take tokens
     * @param _to address where send tokens
     * @param _value amount of tokens 
     */
    
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(msg.sender == admin || msg.sender == owner || _value <= allowance[_from][msg.sender]);     // Check allowance or admin/owner
        if(msg.sender != admin && msg.sender != owner){
            allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(_value);
        }
        _transfer(_from, _to, _value);
        return true;
    }

}
