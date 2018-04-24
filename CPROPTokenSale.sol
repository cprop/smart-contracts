pragma solidity ^0.4.19;

import "./Helper.sol";
import "./SafeMath.sol";

interface tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) public; }

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
        Transfer(0, msg.sender, totalSupply);
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
        Transfer(_from, _to, _value);
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
        Burn(msg.sender, _value);
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
        Burn(_from, _value);
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
    
    function addBonusReceived(address _to, uint256 _value) onlyOwner public {
        bonusReceived[_to] = _value;
    }
    
    function getBonusReceived(address _to) view public returns(uint res) {
        return bonusReceived[_to];
    }

    function getUnlockTime(address _to) view public returns(uint res) {
        if(unlockAt[_to] > 0) return unlockAt[_to];
        if(unlockAtDefault[_to]) return defaultUnlockTime;
        return 0;
    }

    function lockTokensUntil(address _to, uint _unlockAt) onlyOwner public {
        unlockAt[_to] = _unlockAt;
    }

    function setDefaultUnlockTime(uint _unlockAt) onlyOwner public {
        defaultUnlockTime = _unlockAt;
    }

    function transferAndLock(address _to, uint256 _value, uint _unlockAt) onlyOwner public {
        if(_unlockAt == 0) {
            unlockAtDefault[_to] = true;
        } else {
            unlockAt[_to] = _unlockAt;
        }
        _transfer(msg.sender, _to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(msg.sender == admin || msg.sender == owner || _value <= allowance[_from][msg.sender]);     // Check allowance or admin/owner
        if(msg.sender != admin && msg.sender != owner){
            allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(_value);
        }
        _transfer(_from, _to, _value);
        return true;
    }

}

contract CPROPTokenSale is admined {
    using SafeMath for uint256;
    uint256 public initialSupply;
    uint internal buyersCount;
    uint256 internal totalEthRaised;
    uint256 internal totalUsdRaised;
    uint256 internal totalTokensSold;
    uint256 internal tokensDistributedInPreICO;
    CPROPToken public cpropToken;
    uint256 public attoUSDperETH;
    uint256 public attoUSDperTKN;
    uint256 public attoUSDperTKNonPreSale;
    uint256 public minEthAmount;
    uint256 public minGas;
    uint256 public maxGas;
    uint256 public minGasPrice;
    uint256 public maxGasPrice;
    uint public lockTokenTimeout;
    uint public lockBonusTimeout;
    uint public preSaleStartTime;
    uint public preSaleEndTime;
    uint public publicSaleStartTime;
    uint public saleEndTime;
    uint256 public hardCap;
    uint256 public decimals = 0;//** decimals
    uint256 public attoUsdDecimals = 18;//** decimals
    
    uint256 maxDistributedInICO;
    uint256 maxDistributedInPreICO;
    
    address teamTokensPool = 0x0;//sent to one ETH wallet and then we will do a smart contract to payout equally over 24 months to appropriate people
    address advisorsTokensPool = 0x0;//sent to one ETH wallet and then we will do a smart contract to payout as per their agreements
    address bountiesTokensPool = 0x0;//setnt to one ETH wlalet and then we will create smart contract to payout as per agreements

    bool internal tokensIssued;
    bool internal _preSale = false;

    struct _ICO {
        bool approved;
        bool preSale;
        uint lockingTime;
        uint preSaleBonus;
        uint publicSaleBonus;
    }

    mapping (address => _ICO) public userAccount;
    mapping (address => uint256) public etherPaid;

    /* Initializes contract with initial supply tokens to the creator of the contract */
    function CPROPTokenSale(
        address _saleAdmin
    ) public {
        admin = _saleAdmin;
        attoUSDperTKN = 1 * 10**(attoUsdDecimals-2);//$0.01 * 10**18 for 1 TKN
        attoUSDperTKNonPreSale = 8 * 10**(attoUsdDecimals-3);//$0.008 * 10**18 for 1 TKN
        attoUSDperETH = 51200 * 10**(attoUsdDecimals-2);//512.00 * 10^18 for 1 ETH
        minEthAmount = 10 ** 17; // 0.1 Eth //_minEthAmount
        
        minGas = 21000; //_minGas;
        maxGas = 1000000; //_maxGas;
        minGasPrice = 1 * 10**9; //1 GWEI _minGasPrice;
        maxGasPrice = 100 * 10**9; //100 GWEI _maxGasPrice;

        lockTokenTimeout = 0; // Ico tokens should not be locked. 
        lockBonusTimeout = 90 days;//bonus tokens are additionally locked for 3 months after the end of the sale;
        preSaleStartTime = getTime(); //Pre-ICO Dates	April 30, 2018 - May 10, 2018	// 1525046400 - 1525910400
        preSaleEndTime = getTime() + 2048; //Pre-ICO Dates	April 30, 2018 - May 10, 2018	// 1525046400 - 1525910400
        publicSaleStartTime = preSaleStartTime;//ICO Dates	May 21, 2018 - June 10, 2018   //1526860800 - 1528588800
        saleEndTime = publicSaleStartTime + 30 days;//ICO Dates	May 21, 2018 - June 10, 2018   //1526860800 - 1528588800
        hardCap = 20000000 * 10**attoUsdDecimals; // $20M * 10**18
        
        maxDistributedInICO = 4600000000;
        maxDistributedInPreICO = 4200000000;
        
        buyersCount = 0;
        totalEthRaised = 0;
        totalTokensSold = 0;

        cpropToken = new CPROPToken(6130000000, "CPROPCoin", decimals, "CPROP", (saleEndTime + lockTokenTimeout), (saleEndTime + lockBonusTimeout));
        cpropToken.transferAdmin(_saleAdmin);
        tokensIssued = false;
        
        if(teamTokensPool != 0x0)sendTokens(teamTokensPool, 920000000);//920,000,000
        if(advisorsTokensPool != 0x0)sendTokens(advisorsTokensPool, 306500000);//306,500,000
        if(bountiesTokensPool != 0x0)sendTokens(bountiesTokensPool, 306500000);//306,500,000
    }

    function getCPROPTokenAddress() view public returns (address _address){
        return address(cpropToken);
    }

    function transferTokenAdmin(address _tokenAdmin) onlyOwner public {
        cpropToken.transferAdmin(_tokenAdmin);
    }

    function getBalance(address user_addr) public view returns (uint currentBalance){
        return cpropToken.getBalance(user_addr);
    }

    function getTime() internal view returns (uint) {
        return now;
    }

    function getSaleTimes() onlyAdmin public view returns (uint currentTime, uint whitelistedTime, uint publicTime,
        uint endTime, uint lockTimeout, uint whitelistedEndTime) {
        return (getTime(), preSaleStartTime, publicSaleStartTime, saleEndTime, lockTokenTimeout, preSaleEndTime);
    }

    function setSaleTimes(uint _preSaleTime, uint _publicTime, uint _endTime, uint _lockTokenTimeout, uint _preSaleEndTime) onlyAdmin public {
        if(_preSaleTime > 0) preSaleStartTime = _preSaleTime;
        if(_preSaleEndTime > 0) preSaleEndTime = _preSaleEndTime;
        if(_publicTime > 0 && _publicTime > _preSaleTime) publicSaleStartTime = _publicTime;
        bool updateLockTime = false;
        if(_endTime > 0 && _endTime > preSaleStartTime && _endTime > publicSaleStartTime) {
            saleEndTime = _endTime;
            updateLockTime = true;
        }
        if(_lockTokenTimeout > 0) {
            lockTokenTimeout = _lockTokenTimeout;
            updateLockTime = true;
        }
        if(updateLockTime) {
            cpropToken.setDefaultUnlockTime(saleEndTime + lockTokenTimeout);
        }
    }
    
    function getAttoUSDperTKN() public view returns (uint _attoUSDperTKN){
        return attoUSDperTKN;
    }
    
    function getAttoUSDperTKNonPreSale() public view returns (uint _attoUSDperTKNonPreSale){
        return attoUSDperTKNonPreSale;
    }

    function getAttoUSDperETH() public view returns (uint _attoUSDperTKN) {
        return attoUSDperETH;
    }

    function setAttoUSDperTKN(uint _p) onlyOwner public {
        //expecting in USD * 10^18;
        //for example 0.089346 USD * 10^18 => 8.9346e+16
        if(_p > 0) {
            attoUSDperTKN = _p;
        }
    }
    
    function setAttoUSDperTKNonPreSale(uint _p) onlyOwner public {
        if(_p > 0) {
            attoUSDperTKNonPreSale = _p;
        }
    }

    function setAttoUSDperETH(uint _p) onlyOwner public {
        //expecting in USD * 10^18;
        if(_p > 0) {
            attoUSDperETH = _p;
        }
    }
    
    function setMaxDistributedInICO(uint _p) onlyOwner public {
        maxDistributedInICO = _p;
    }
    
    function setMaxDistributedInPreICO(uint _p) onlyOwner public {
        maxDistributedInPreICO = _p;
    }

    function sendTokens(address _target, uint256 _amount) onlyOwner public {
        require(_target != 0x0);
        cpropToken.transfer(_target, _amount);
    }

    function setAccountSettings(address target, bool approved, bool preSale, uint lockTimeout, uint preSaleBonus, uint publicSaleBonus) onlyAdmin public {
        userAccount[target].approved = approved;
        userAccount[target].preSale = preSale;
        userAccount[target].lockingTime = lockTimeout;
        userAccount[target].preSaleBonus = preSaleBonus;
        userAccount[target].publicSaleBonus = publicSaleBonus;
    }

    function getAccountSettings(address target) onlyAdmin view public returns(bool approved, bool preSale, uint lockingTime, uint preSaleBonus, uint publicSaleBonus) {//isPreSale
        return (userAccount[target].approved, userAccount[target].preSale, userAccount[target].lockingTime, userAccount[target].preSaleBonus, userAccount[target].publicSaleBonus);
    }

    function getStats() onlyAdmin view public returns(uint256 _totalEthRaised, uint256 _totalTokensSold,
        uint totalBuyers, uint256 _totalUsdRaised, uint256 _tokensDistributedInPreICO) {
        return (totalEthRaised, totalTokensSold, buyersCount, totalUsdRaised, tokensDistributedInPreICO);
    }

    function getEtherPaid(address target) onlyAdmin view public returns(uint256 res) {
        return etherPaid[target];
    }


    // fallback function can be used to buy tokens
    function () payable public {
        buy();
    }

    /// @notice Buy tokens from contract by sending 
    function buy() payable public {
        uint256 _tmpTknPrice = attoUSDperTKN;
        
        uint _ethAmount = msg.value;
        uint _usdAmount = (_ethAmount.mul(attoUSDperETH)).div(10**18);//18 is const here, 1ether = 10^18wei
        
        if(maxDistributedInPreICO > tokensDistributedInPreICO && userAccount[msg.sender].preSale && preSaleStartTime <= getTime() && preSaleEndTime > getTime()){
            _preSale = true;
            _tmpTknPrice = attoUSDperTKNonPreSale;
        }else{
            _preSale = false;
        }
        

        require(msg.value >= minEthAmount);
        
        require(msg.gas >= minGas && msg.gas <= maxGas);
        require(tx.gasprice >= minGasPrice && tx.gasprice <= maxGasPrice);
        
        //require(totalEthRaised + msg.value > totalEthRaised && (totalEthRaised * attoUSDperETH) / 10**18 <= hardCap);//cryptro cap
        require(totalUsdRaised.add(_usdAmount) > totalUsdRaised);//fiat cap

        require(saleEndTime == 0 || saleEndTime > getTime());

        require(_preSale || (userAccount[msg.sender].approved && publicSaleStartTime <= getTime()));

        require(totalUsdRaised.add(_usdAmount) > totalUsdRaised);
        
        if(totalUsdRaised.add(_usdAmount) > hardCap) {
             // sell only remainer
             _usdAmount = hardCap.sub(totalUsdRaised);
             _ethAmount = (_usdAmount.mul(10**attoUsdDecimals)).div(attoUSDperETH);
         }

        uint _t_bonus;
        uint amount = (_usdAmount.mul(10**decimals)).div(_tmpTknPrice);  // calculate the amount

        // calculate bonuses        
        if(_preSale && userAccount[msg.sender].preSaleBonus > 0) {
            _t_bonus = (amount.mul(userAccount[msg.sender].preSaleBonus)).div(100);
        }
        
        if(!_preSale && userAccount[msg.sender].publicSaleBonus > 0) {
            _t_bonus = (amount.mul(userAccount[msg.sender].publicSaleBonus)).div(100);
        }
        
        if(_t_bonus > 0){
            cpropToken.addBonusReceived(msg.sender, _t_bonus);
            amount = amount.add(_t_bonus);
        }


        // check if we have enough tokens left
        uint tokensLeft = (_preSale)?(maxDistributedInPreICO - tokensDistributedInPreICO):(maxDistributedInICO - totalTokensSold);//this.getBalance(this);

        if(tokensLeft < amount) {
            amount = tokensLeft;
            _usdAmount = amount.mul(_tmpTknPrice);
            _ethAmount = (_usdAmount.mul(10**attoUsdDecimals)).div(attoUSDperETH);
        }else{
            //require(amount >= minBuyAmount);   
        }
        
        require(amount > 0);


        cpropToken.transferAndLock(msg.sender, amount, userAccount[msg.sender].lockingTime);

        buyersCount = buyersCount.add(1);
        totalEthRaised = totalEthRaised.add(_ethAmount);
        totalTokensSold = totalTokensSold.add(amount);
        totalUsdRaised  = totalUsdRaised.add(_usdAmount);

        etherPaid[msg.sender] = etherPaid[msg.sender].add(_ethAmount);

        uint ethToReturn = msg.value.sub(_ethAmount); 
        if(ethToReturn > 0) msg.sender.transfer(ethToReturn);
        
        if(_preSale){
            tokensDistributedInPreICO = amount.add(tokensDistributedInPreICO);
        }

        // check if sale is overflows
        //(totalEthRaised * attoUSDperETH) / 10**18 >= hardCap
        if(totalUsdRaised >= hardCap || cpropToken.getBalance(this) == 0) {
            // sale is over
            cpropToken.setDefaultUnlockTime(getTime().add(lockTokenTimeout));
        }

    }
    
    //debug function
    function setHardCap(uint _hardCap) public {
        hardCap = _hardCap;
    }
    
    
}
