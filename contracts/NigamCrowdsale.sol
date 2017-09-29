pragma solidity ^0.4.15;

import './zeppelin/ownership/Ownable.sol';
import './oraclize/oraclizeAPI.sol';
import './NigamCoin.sol';

contract NigamCrowdsale is Ownable, usingOraclize {
    using SafeMath for uint256;

    NigamCoin public token;     //token we sale
    uint256 public ethPrice;    //ETHUSD price in cents (* 100), will be set by Oraclize

    uint256   public preSale1BasePrice;       //price in cents
    uint8[]   public preSale1BonusSchedule;   //bonus percents
    uint256[] public preSale1BonusLimits;     //limits to apply bonuses
    uint256   public preSale1EthHardCap;      //hard cap for 1 pre-sale in ether  

    uint256   public preSale2BasePrice;       //price in cents
    uint8[]   public preSale2BonusSchedule;   //bonus percents
    uint256[] public preSale2BonusLimits;     //limits to apply bonuses
    uint256   public preSale2EthHardCap;      //hard cap for 2 pre-sale in ether  


    uint256 public saleBasePrice;              //price in cents
    uint32  public salePriceIncreaseInteval;   //seconds before price increase
    uint32  public salePriceIncreaseAmount;    //amount to increae price to (in cents)
    uint256 public saleEthHardCap;             //hard cap for the main sale  round in ether  

    uint256 ownersPercent;              //percent of tokens that will be mint to owner during the sale

    enum State {Paused, FirstPreSale, SecondPreSale, Sale};
    State public state;                  //current state of the contract



    uint16 public oraclizeUpdateInterval = 60; //update price interval in seconds
    event EthPriceUpdate(uint256 newEthPrice);


    function NigamCrowdsale(){
        preSale1BasePrice = 50;
        preSale1BonusSchedule = [5, 10, 15, 25, 50];
        preSale1BonusLimits   = [4 ether, 10 ether, 15 ether, 25 ether, 100 ether];
        saleEthHardCap = 1666.67 ether;

        preSale2BasePrice = 70;
        preSale2BonusSchedule = [1, 3, 5, 8, 25];
        preSale2BonusLimits   = [500 ether, 1000 ether, 2500 ether, 5000 ether, 1000 ether];
        saleEthHardCap = 16666.67 ether;

        saleBasePrice = 100;
        salePriceIncreaseInteval = 24*60*60; //1 day
        salePriceIncreaseAmount = 20;
        saleEthHardCap = 166666.67 ether;

        ownersPercent = 10;

        token = new NigamCoin();
    }


    /**
     * @notice How many tokens you receive for 1 ETH
     * @param etherAmount how much ether you are sending
     * @return conversion rate
     */
    function currentRate(uint256 etherAmount) public constant returns(uint256){
        if(state == Paused) return 0;
        if(state == State.FirstPreSale)

    }


    function __callback(bytes32 myid, string result, bytes proof) {
        require(msg.sender == oraclize_cbAddress());
        ethPrice = parseInt(result, 2); //2 makes ethPrice to be price in cents. Maximum accuracy for kraken is 5
        EthPriceUpdate(ethPrice);
        if(oraclizeUpdateInterval > 0){
            updateEthPriceInternal();
        }
    }

    function updateEthPrice() public payable onlyOwner{
        updatePriceInternal();
    }
    function updateEthPriceInternal() internal {
        oraclize_query(oraclizeUpdateInterval, "URL", "json(https://api.kraken.com/0/public/Ticker?pair=ETHUSD).result.XETHZUSD.c.0");
    }
    function updateInterva(newInterval) public  onlyOwner{
    }

}


