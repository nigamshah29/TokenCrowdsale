pragma solidity ^0.4.15;


import './zeppelin/token/MintableToken.sol';
import './zeppelin/ownership/HasNoContracts.sol';
import './zeppelin/ownership/HasNoTokens.sol';

contract NigamCoin is MintableToken, HasNoContracts, HasNoTokens { //MintableToken is StandardToken, Ownable
    string public symbol = 'NGM';
    string public name = 'NigamCoin';
    uint8 public constant decimals = 18;

    /**
     * Allow transfer only after crowdsale finished
     */
    modifier canTransfer() {
        require(mintingFinished);
        _;
    }
    
    function transfer(address _to, uint256 _value) canTransfer returns (bool) {
        super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) canTransfer returns (bool) {
        super.transferFrom(_from, _to, _value);
    }
}