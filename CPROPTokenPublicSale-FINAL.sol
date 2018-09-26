pragma solidity ^0.4.21;

contract owned {
    address public owner;

    constructor() public {
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

    constructor() public {
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


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
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


contract AttoUSDperETH is admined {
    using SafeMath for uint256;
    uint256 public attoUSDperETH;
    bool public pause;
    uint256 public attoUsdDecimals = 18;//** decimals
    // This notifies admin about significant price change
    event priceChange(uint256 prevPrice, uint256 nextPrice, uint percentChange);
    
    constructor() public {
        pause = false;
        attoUSDperETH = 25600 * 10**(attoUsdDecimals-2);//256.00 * 10^18 for 1 ETH
    }
    /**
     * atto usd is usd * 10^18
     * @param _p set atto usd per 1 eth
     */
    function set(uint _p) onlyAdmin public {
        //expecting in USD * 10^18;
        if(_p > 0) {
            
           if(_p > attoUSDperETH && (_p >= attoUSDperETH*2)){
                emit priceChange(attoUSDperETH, _p, (((_p - attoUSDperETH)*100)/attoUSDperETH));
                pause = true;
            }else if(_p < attoUSDperETH && (_p*2 <= attoUSDperETH)){
                emit priceChange(attoUSDperETH, _p, (((attoUSDperETH - _p)*100)/attoUSDperETH));
                pause = true;
            }
            attoUSDperETH = _p;
        }
    }
    
    /**
     * atto usd is usd * 10^18
     * @return _attoUSDperTKN 1 eth price in atto usd 
     */
    function get() public view returns (uint _attoUSDperTKN) {
        return attoUSDperETH;
    }

    function getPause() public view returns (bool _pause){
        return pause;
    }
    
    function setPause(bool _pause) onlyAdmin public {
        pause = _pause;
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

    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);

    /**
     * Constrctor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    constructor(
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
        // Subtract from the sender
        balanceOf[_from] = balanceOf[_from].sub(_value);
        // Add the same to the recipient
        balanceOf[_to] = balanceOf[_to].add(_value);
        emit Transfer(_from, _to, _value);
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
        allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(_value);
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
        emit Approval(msg.sender, _spender, _value);
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
        _burn(msg.sender, _value);
        return true;
    }
    
    function _burn(address _who, uint256 _value) internal {
        balanceOf[_who] = balanceOf[_who].sub(_value);  // Subtract from the sender
        totalSupply = totalSupply.sub(_value);                      // Updates totalSupply
        emit Burn(_who, _value);
        emit Transfer(_who, address(0), _value);
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
        allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(_value); // Subtract from the sender's allowance
        _burn(_from, _value);
        return true;
    }

    function getBalance(address _to) view public returns(uint res) {
        return balanceOf[_to];
    }

}

contract CPROPToken is admined, TokenERC20  {
    constructor(
        uint256 initialSupply,
        string tokenName,
        uint256 decimalsToken,
        string tokenSymbol
    ) TokenERC20(initialSupply, tokenName, decimalsToken, tokenSymbol) public {
    }
}

contract CPROPTokenPublicSale is admined {
    using SafeMath for uint256;
    uint internal buyersCount;
    uint256 internal totalEthRaised;
    uint256 internal totalUsdRaised;
    uint256 internal totalTokensSold;
    CPROPToken public cpropToken;
    AttoUSDperETH public AttoUSDperETHContract;
    uint256 public attoUSDperTKN;
    uint256 public minEthAmount;
    uint256 public minGas;
    uint256 public maxGas;
    uint256 public minGasPrice;
    uint256 public maxGasPrice;
    uint public publicSaleStartTime;
    uint public saleEndTime;
    uint256 public hardCap;
    uint256 public decimals = 0;//** decimals
    uint256 public attoUsdDecimals = 18;//** decimals
    uint256 maxDistributedInICO;
    address CPROPTokenContractAddress;
    address AttoUSDperETHContractAddress;

    struct _ICO {
        bool approved;
        uint lockingTime;
        uint publicSaleBonus;
        uint maxUSDAmount;
    }

    mapping (address => _ICO) public userAccount;
    mapping (address => uint256) public etherPaid;
    mapping (address => uint256) public usdPaid;
    
    event TokensSold(address indexed buyer, uint ethPaid, uint usdPaid, uint tokensReceived);
    event SoldOut(string _type, uint totalUsdRaised, uint totalTokensSold);
    
    address internal ethWallet = 0x0; // wallet to gather Eth from sale
    
    // This notifies admin about significant price change
    event priceChange(uint256 prevPrice, uint256 nextPrice, uint percentChange);
    
    /* Initializes contract with initial supply tokens to the creator of the contract */
    constructor(
        address _saleAdmin, 
        address _token
    ) public {
        admin = _saleAdmin;
        CPROPTokenContractAddress = _token;
        //AttoUSDperETHContractAddress = _usdpereth;
        attoUSDperTKN = 1 * 10**(attoUsdDecimals-2);//$0.01 * 10**18 for 1 TKN
        minEthAmount = 10 ** 17; // 0.1 Eth //_minEthAmount
        
        minGas = 21000; //_minGas;
        maxGas = 1000000; //_maxGas;
        minGasPrice = 1 * 10**9; //1 GWEI _minGasPrice;
        maxGasPrice = 100 * 10**9; //100 GWEI _maxGasPrice;

        publicSaleStartTime = 1538265600; //1538265600 - Is equivalent to: 09/30/2018 @ 12:00am (UTC)
        saleEndTime = 1542326399; //1542326399 - Is equivalent to: 11/15/2018 @ 11:59pm (UTC)
        hardCap = 20000000 * 10**attoUsdDecimals; // $20M * 10**18
        
        buyersCount = 0;
        totalEthRaised = 0;
        totalTokensSold = 0;

        cpropToken = CPROPToken(CPROPTokenContractAddress);
        
        /****/
        //in case of external eth to usd contract
        //AttoUSDperETHContract = AttoUSDperETH(AttoUSDperETHContractAddress);
        
        //in case of internal eth to usd contract
        AttoUSDperETHContract = new AttoUSDperETH();
        AttoUSDperETHContract.transferAdmin(admin);
        AttoUSDperETHContractAddress = address(AttoUSDperETHContract);
        /****/
       
        //owner = 0x0;
    }

    /**
     * @return _address address of cprop token contract deployed in construct function
     */
    function getCPROPTokenAddress() view public returns (address _address){
        return address(cpropToken);
    }

    /**
     * Change admin address (admined contract)
     * 
     * @param _tokenAdmin The address of new admin
     */
    function transferTokenAdmin(address _tokenAdmin) onlyOwner public {
        cpropToken.transferAdmin(_tokenAdmin);
    }

    /**
     * Get amount of tokens user holds on their account
     *
     * @param user_addr The address of the user
     * @return currentBalance amount of CPROP tokens
     */
    function getBalance(address user_addr) public view returns (uint currentBalance){
        return cpropToken.getBalance(user_addr);
    }

    /**
     * return current block timestamp (alias for block.timestamp)
     */
    function getTime() internal view returns (uint) {
        return now;
    }

    /**
     * get time related contract settings
     * @return currentTime current time, unix timestamp
     * @return publicTime abilitiy to buy tokens for approved users, unix timestamp
     * @return endTime tokens saled end on, unix timestamp
     * @return lockTimeout tokens locked untill, seconds
     */
    function getSaleTimes() onlyAdmin public view returns (uint currentTime, uint publicTime,
        uint endTime, uint lockTimeout) {
        return (getTime(), publicSaleStartTime, saleEndTime, 0);
    }

    /**
     * atto usd is usd * 10^18
     * @return _attoUSDperTKN 1 cprop price in atto usd 
     */
    function getAttoUSDperTKN() public view returns (uint _attoUSDperTKN){
        return attoUSDperTKN;
    }
    
    /**
     * atto usd is usd * 10^18
     * @return _attoUSDperTKN 1 eth price in atto usd 
     */
    function getAttoUSDperETH() public view returns (uint _attoUSDperTKN) {
        
        return AttoUSDperETHContract.get();
    }
    
    function getAttoUSDperETHPause() public view returns (bool _pause){
        return AttoUSDperETHContract.getPause();
    }
    
    function setAttoUSDperETHPause(bool _pause) onlyAdmin public {
        AttoUSDperETHContract.setPause(_pause);
    }

    /**
     * atto usd is usd * 10^18
     * @param _attoUSDperETH set atto usd per 1 eth
     */
    function setAttoUSDperETH(uint _attoUSDperETH) onlyAdmin public {
        //expecting in USD * 10^18;
        if(_attoUSDperETH > 0) {
            AttoUSDperETHContract.set(_attoUSDperETH);
        }
    }

    /**
     * atto usd is usd * 10^18
     * @param _p set atto usd per 1 cprop
     */
    function setAttoUSDperTKN(uint _p) onlyOwner public {
        //expecting in USD * 10^18;
        //for example 0.089346 USD * 10^18 => 8.9346e+16
        if(_p > 0) {
            attoUSDperTKN = _p;
        }
    }
    
    
    /**
     * send tokens to an address
     * @param _target address
     * @param _amount the amount to send
     */
    function sendTokens(address _target, uint256 _amount) onlyOwner public {
        require(_target != 0x0);
        cpropToken.transfer(_target, _amount);
    }

    /**
     * set account settings
     * @param target address
     * @param approved 1 - passed, 0 - failed
     * @param lockTimeout set lock timout on buy event, in seconds
     * @param publicSaleBonus personal bonus in % while public sale
     */
    function setAccountSettings(address target, bool approved, uint lockTimeout, uint publicSaleBonus, uint maxUSDAmount) onlyAdmin public {
        lockTimeout = 0;
        userAccount[target].approved = approved;
        userAccount[target].lockingTime = lockTimeout;
        userAccount[target].publicSaleBonus = publicSaleBonus;
        userAccount[target].maxUSDAmount = maxUSDAmount;
    }

    /**
     * get account settings
     * @param target address
     * @return approved 1 - passed, 0 - failed
     * @return lockTimeout set lock timout on buy event, in seconds
     * @return publicSaleBonus personal bonus in % while public sale
     */
    function getAccountSettings(address target) onlyAdmin view public returns(bool approved, uint lockingTime, uint publicSaleBonus, uint maxUSDAmount) {
        return (userAccount[target].approved, userAccount[target].lockingTime, userAccount[target].publicSaleBonus, userAccount[target].maxUSDAmount);
    }

    /**
     * some analytics
     * @return totalEthRaised total amount of wei converted to mzx
     * @return totalTokensSold total amount of cprop converted to wei
     * @return buyersCount total amount of wei -> max transactions
     * @return totalUsdRaised total usd raised
     */
    function getStats() onlyAdmin view public returns(uint256 _totalEthRaised, uint256 _totalTokensSold,
        uint totalBuyers, uint256 _totalUsdRaised) {
        return (totalEthRaised, totalTokensSold, buyersCount, totalUsdRaised);
    }

    /**
     * @return total amount of wei user paid
     */
    function getEtherPaid(address target) onlyAdmin view public returns(uint256 res) {
        return etherPaid[target];
    }
    
    /**
     * @return total amount of usd user paid
     */
    function getUsdPaid(address target) onlyAdmin view public returns(uint256 res) {
        return usdPaid[target];
    }

    // fallback function can be used to buy tokens
    function () payable public {
        buy();
    }

    /// @notice Buy tokens from contract by sending 
    function buy() payable public {
        uint256 _tmpTknPrice = attoUSDperTKN;
        
        require(msg.value >= minEthAmount);
        
        require(ethWallet != 0x0);
        
        //require(gasleft() >= minGas && gasleft() <= maxGas);//comment if truffle, uncomment on deploy
        require(tx.gasprice >= minGasPrice && tx.gasprice <= maxGasPrice);

        require(saleEndTime == 0 || saleEndTime > getTime());

        require(userAccount[msg.sender].approved && publicSaleStartTime <= getTime());
        
        

        //a single ETH-USD ExchangeRate smart contract 
        require(AttoUSDperETHContractAddress != 0x0);
        uint attoUSDperETH = this.getAttoUSDperETH();
        require(AttoUSDperETHContract.getPause() == false);        
        uint _ethAmount = msg.value;
        uint _usdAmount = (_ethAmount.mul(attoUSDperETH)).div(10**18);//18 is const here, 1ether = 10^18wei
        
        
        if(totalUsdRaised.add(_usdAmount) > hardCap) {
             // sell only remainer
             _usdAmount = hardCap.sub(totalUsdRaised);
             _ethAmount = (_usdAmount.mul(10**attoUsdDecimals)).div(attoUSDperETH);
         }

        //check for usd limit overflow (personal)
        if(userAccount[msg.sender].maxUSDAmount > 0 && usdPaid[msg.sender].add(_usdAmount) > userAccount[msg.sender].maxUSDAmount) {
             // sell only remainer
             _usdAmount = userAccount[msg.sender].maxUSDAmount.sub(usdPaid[msg.sender]);
             _ethAmount = (_usdAmount.mul(10**attoUsdDecimals)).div(attoUSDperETH);
         }
         
        uint _t_bonus;
        uint amount = (_usdAmount.mul(10**decimals)).div(_tmpTknPrice);  // calculate the amount

        // calculate bonuses        
        if(userAccount[msg.sender].publicSaleBonus > 0) {
            _t_bonus = (amount.mul(userAccount[msg.sender].publicSaleBonus)).div(100);
        }
        
        if(_t_bonus > 0){
            amount = amount.add(_t_bonus);
        }


        // check if we have enough tokens left
        uint tokensLeft = this.getBalance(this);

        if(tokensLeft < amount) {
            amount = tokensLeft;
            _usdAmount = amount.mul(_tmpTknPrice);
            _ethAmount = (_usdAmount.mul(10**attoUsdDecimals)).div(attoUSDperETH);
        }
        
        require(amount > 0);


        cpropToken.transfer(msg.sender, amount);

        buyersCount = buyersCount.add(1);
        totalEthRaised = totalEthRaised.add(_ethAmount);
        totalTokensSold = totalTokensSold.add(amount);
        totalUsdRaised  = totalUsdRaised.add(_usdAmount);

        etherPaid[msg.sender] = etherPaid[msg.sender].add(_ethAmount);
        usdPaid[msg.sender] = usdPaid[msg.sender].add(_usdAmount);

        uint ethToReturn = msg.value.sub(_ethAmount); 
        if(ethToReturn > 0) msg.sender.transfer(ethToReturn);
        
        ethWallet.transfer(_ethAmount);
        
        // fire event for tokens sold
        emit TokensSold(msg.sender, _ethAmount, _usdAmount, amount);
        
        if(this.getBalance(this) == 0) {
            emit SoldOut("tkn", totalUsdRaised, totalTokensSold);
        }

    }
}