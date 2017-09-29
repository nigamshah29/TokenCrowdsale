pragma solidity ^0.4.15;

import './zeppelin/ownership/Ownable.sol';
import './oraclize/oraclizeAPI.sol';
import './NigamCoin.sol';

contract NigamCrowdsale is Ownable, HasNoTokens, usingOraclize {
    using SafeMath for uint256;

    NigamCoin public token;     //token we sale
    uint256 public ethPrice;    //ETHUSD price in $0.00001, will be set by Oraclize, example: if 1 ETH = 295.14000 USD, then ethPrice = 29514000

    uint256   public preSale1BasePrice;       //price in cents
    uint8[]   public preSale1BonusSchedule;   //bonus percents
    uint256[] public preSale1BonusLimits;     //limits to apply bonuses
    uint256   public preSale1EthHardCap;      //hard cap for 1 pre-sale in ether  
    uint256   public preSale1EthCollected;    //how much ether already collected at pre-sale 1

    uint256   public preSale2BasePrice;       //price in cents
    uint8[]   public preSale2BonusSchedule;   //bonus percents
    uint256[] public preSale2BonusLimits;     //limits to apply bonuses
    uint256   public preSale2EthHardCap;      //hard cap for 2 pre-sale in ether  
    uint256   public preSale2EthCollected;    //how much ether already collected at pre-sale 2


    uint256 public saleBasePrice;              //price in cents
    uint32  public salePriceIncreaseInteval;   //seconds before price increase
    uint32  public salePriceIncreaseAmount;    //amount to increae price to (in cents)
    uint256 public saleEthHardCap;             //hard cap for the main sale  round in ether  
    uint256 public saleStartTimestamp;         //when sale started 
    uint256 public saleEthCollected;       //how much ether already collected at main sale

    uint256 ownersPercent;              //percent of tokens that will be mint to owner during the sale

    enum State { Paused, FirstPreSale, SecondPreSale, Sale, Finished }
    State public state;                  //current state of the contract



    uint32 public oraclizeUpdateInterval = 60; //update price interval in seconds

    /**
    * event for price update logging
    * @param newEthPrice new price of eth in points, where 1 point = 0.00001 USD
    */
    event EthPriceUpdate(uint256 newEthPrice);

    /**
    * event for token purchase logging
    * @param purchaser who paid for the tokens
    * @param value weis paid for purchase
    * @param amount amount of tokens purchased
    */
    event TokenPurchase(address indexed purchaser, uint256 value, uint256 amount);


    function NigamCrowdsale(){
        state = State.Paused;

        preSale1BasePrice = 50000;
        preSale1BonusSchedule = [5, 10, 15, 25, 50];
        preSale1BonusLimits   = [4 ether, 10 ether, 15 ether, 25 ether, 100 ether];
        saleEthHardCap = 1666.67 ether;
        assert(preSale1BonusSchedule.length == preSale1BonusLimits.length);

        preSale2BasePrice = 70000;
        preSale2BonusSchedule = [1, 3, 5, 8, 25];
        preSale2BonusLimits   = [500 ether, 1000 ether, 2500 ether, 5000 ether, 1000 ether];
        saleEthHardCap = 16666.67 ether;
        assert(preSale2BonusSchedule.length == preSale2BonusLimits.length);

        saleBasePrice = 100000;
        salePriceIncreaseInteval = 24*60*60; //1 day
        salePriceIncreaseAmount = 20000;
        saleEthHardCap = 166666.67 ether;

        ownersPercent = 10;

        token = new NigamCoin();
    }

    /**
    * @notice To buy tokens just send ether here
    */
    function() payable {
        require(msg.value > 0);
        require(crowdsaleOpen());
        uint256 rate = currentRate(msg.value);
        assert(rate > 0);
        uint256 buyerTokens = rate.mul(msg.value);
        uint256 ownerTokens = buyerTokens.mul(ownersPercent)/100; //ownersPercent is percents, so divide to 100
        token.mint(msg.sender, buyerTokens);
        token.mint(owner, ownerTokens);
        TokenPurchase(msg.sender, msg.value, buyerTokens);
    }
    /**
    * @notice Check if crowdsale is open or not
    */
    function crowdsaleOpen() constant returns(bool){
        return  (state != State.Paused) && 
                (state != State.Finished) && 
                !hardCapReached(state);
    }
    /**
    * @notice How many tokens you receive for 1 ETH
    * @param etherAmount how much ether you are sending
    * @return conversion rate
    */
    function currentRate(uint256 etherAmount) public constant returns(uint256){
        if(state == State.Paused || state == State.Finished) return 0;
        uint256 rate;
        if(state == State.FirstPreSale) {
            rate = calculatePreSaleRate(etherAmount, preSale1BasePrice, preSale1BonusSchedule, preSale1BonusLimits);
        }else if(state == State.SecondPreSale) {
            rate = calculatePreSaleRate(etherAmount, preSale2BasePrice, preSale2BonusSchedule, preSale2BonusLimits);
        }else if(state == State.Sale){
            rate = calculateSaleRate();
        }else {
            revert();   //state is wrong
        }
        return rate;
    }
    function calculatePreSaleRate(uint256 etherAmount, uint256 basePrice, uint8[] bonusSchedule, uint256[] bonusLimits) constant returns(uint256) {
        uint256 rate = ethPrice.div(basePrice);
        for(uint i = preSale1BonusSchedule.length - 1; i >=0; i--){
            if(etherAmount >= preSale1BonusLimits[i]){
                uint256 bonus = rate.mul(preSale1BonusSchedule[i]).div(100); //preSale1BonusSchedule[i] is percents, so divide to 100
                rate = rate.add(bonus);
                break;
            }
        }
        return rate;
    }
    function calculateSaleRate() constant returns(uint256){
        if(saleStartTimestamp == 0 || now < saleStartTimestamp) return 0;
        uint256 saleRunningSeconds = now - saleStartTimestamp;
        uint256 passedIntervals = saleRunningSeconds / salePriceIncreaseInteval; //remainder will be discarded
        uint256 price = saleBasePrice.add( passedIntervals.mul(salePriceIncreaseAmount) );
        uint256 rate = ethPrice.div(price);
        return rate;
    }
    function hardCapReached(State _state) constant returns(bool){
        if(_state == State.FirstPreSale) {
            return preSale1EthCollected < preSale1EthHardCap;
        }else if(_state == State.SecondPreSale) {
            return preSale2EthCollected < preSale2EthHardCap;
        }else if(_state == State.Sale){
            return saleEthCollected < saleEthHardCap;
        }else {
            return false;
        }
    }

    /**
    * @notice Owner can change state
    * @param newState New state of the crowdsale
    */
    function setState(State newState) public onlyOwner {
        require(state != State.Finished); //if Finished, no state change possible
        if(newState == State.Finished){
            token.finishMinting();
            token.transferOwnership(owner);
            oraclizeUpdateInterval = 0;
        }else if(newState == State.Sale && saleStartTimestamp == 0) {
            saleStartTimestamp = now;
        }
        state = newState;
    }
    /**
    * @notice Owner can claim collected ether
    * @param amount How much ether to take. Please leave enough ether for price updates
    */
    function claim(uint256 amount) onlyOwner {
        require(this.balance >= amount);
        owner.transfer(amount);
    }
    /**
    * @notice Owner can change price update interval
    * @param newOraclizeUpdateInterval Update interval in seconds. Zero will stop updates.
    */
    function updateInterval(uint32 newOraclizeUpdateInterval) public onlyOwner {
        if(oraclizeUpdateInterval == 0 && newOraclizeUpdateInterval > 0){
            oraclizeUpdateInterval = newOraclizeUpdateInterval;
            updateEthPriceInternal();
        }else{
            oraclizeUpdateInterval = newOraclizeUpdateInterval;
        }
    }
    /**
    * @notice Owner can do this to start price updates
    * Also, he can put some ether to the contract so that it can pay for the updates
    */
    function updateEthPrice() public payable onlyOwner{
        updateEthPriceInternal();
    }
    /**
    * @dev Callbacl for Oraclize
    */
    function __callback(bytes32 myid, string result, bytes proof) {
        require(msg.sender == oraclize_cbAddress());
        ethPrice = parseInt(result, 5); //5 makes ethPrice to be price in 0.00001 USD
        EthPriceUpdate(ethPrice);
        if(oraclizeUpdateInterval > 0){
            updateEthPriceInternal();
        }
    }
    function updateEthPriceInternal() internal {
        oraclize_query(oraclizeUpdateInterval, "URL", "json(https://api.kraken.com/0/public/Ticker?pair=ETHUSD).result.XETHZUSD.c.0");
    }

}


