pragma solidity ^0.4.18;

import "../node_modules/zeppelin-solidity/contracts/token/ERC20/MintableToken.sol";
import "../node_modules/zeppelin-solidity/contracts/lifecycle/Pausable.sol";

/**
 * @title The smart contract for the pre-sale.
 * @dev Origin Card is an ERC20 token.
 */
contract Presale is Pausable {
  using SafeMath for uint256;

  // Eth will be sent to this wallet.
  address public wallet;

  // The token contract.
  OriginCard public tokenContract;

  // Start and end timestamps where investments are allowed (both inclusive).
  uint256 public startTime;
  uint256 public endTime;

  // Price for a card in wei.
  uint256 public price;

  // Amount of card sold.
  uint256 public soldCards;

  // Increase of price per transaction.
  uint256 public priceIncrease;

  // Amount of card redeemed.
  uint256 public redeemedCards;

  // Event that is fired when purchase transaction is made.
  event TokenPurchase(
    address indexed purchaser, 
    address indexed beneficiary, 
    uint256 value,
    uint256 amount
  );

  // Event that is fired when redeem tokens.
  event TokenRedeem(
    address indexed beneficiary,
    uint256 amount
  );

  // Event that is fired when refunding excessive money from ther user.
  event RefundEth(
    address indexed beneficiary,
    uint256 amount
  );

  // @dev Contructor.
  function Presale(address _wallet, uint256 _startTime, uint256 _endTime, uint256 _price, uint256 _priceIncrease)
    public
  {
    require(_endTime >= _startTime);
    require(_price >= 0);
    require(_priceIncrease >= 0);
    require(_wallet != address(0));
    
    wallet = _wallet;
    tokenContract = new OriginCard();
    startTime = _startTime;
    endTime = _endTime;
    price = _price;
    priceIncrease = _priceIncrease;
  }

  // @return true if the transaction can buy tokens
  function validPurchase()
    internal view 
    returns (bool)
  {
    bool withinPeriod = now >= startTime && now <= endTime;
    bool nonZeroPurchase = msg.value != 0;
    return withinPeriod && nonZeroPurchase;
  }

  // @Notify Redeem limit is 500 cards.
  // @return true if the transaction can redeem tokens
  function validRedeem()
    internal view
    returns (bool)
  {
    bool withinPeriod = now >= startTime && now <= endTime;
    bool notExceedRedeemLimit = redeemedCards < 500;
    return withinPeriod && notExceedRedeemLimit;
  }

  // @return true if crowdsale event has ended
  function hasEnded()
    public view 
    returns (bool) 
  {
    return now > endTime;
  }

  // @dev Fallback function can be used to buy tokens.
  function () 
    external
    payable
  {
    buyTokens(msg.sender, 1);
  }

  // @dev Low level token purchase function.
  function buyTokens(address _beneficiary, uint256 _amount)
    whenNotPaused
    public
    payable
  {
    require(_beneficiary != address(0));
    require(validPurchase());
    require(_amount >= 1 && _amount <= 5);

    var _priceOfBundle = price.mul(_amount);

    require(msg.value >= _priceOfBundle);

    // Increase the price.
    // The price increases only when a transaction is made.
    // Amount of tokens purchase at a transaction won't affect the price.
    price = price.add(priceIncrease);

    // Mint tokens.
    tokenContract.mint(_beneficiary, _amount);

    // Add count of tokens sold.
    soldCards += _amount;

    // Send the raised eth to the wallet.
    wallet.transfer(_priceOfBundle);

    // Send the exta eth paid by the sender.
    var _extraEthInWei = msg.value.sub(_priceOfBundle);
    if (_extraEthInWei >= 0) {
      msg.sender.transfer(_extraEthInWei);
    }

    // Fire event.
    TokenPurchase(msg.sender, _beneficiary, msg.value, _amount);
  }

  // @dev Low level token redeem function.
  function redeemTokens(address _beneficiary)
    onlyOwner
    public
  {
    require(_beneficiary != address(0));
    require(validRedeem());

    // Mint token.
    tokenContract.mint(_beneficiary, 1);

    // Add count of tokens redeemed.
    redeemedCards ++;

    // Fire event.
    TokenRedeem(_beneficiary, 1);
  }

  // @dev Set price increase of token per transaction.
  //  Note that this will never become below 0, 
  //  which means early buyers will always buy tokens at lower price than later buyers.
  function setPriceIncrease(uint256 _priceIncrease)
    onlyOwner
    public
  {
    require(priceIncrease >= 0);
    
    // Set price increase per transaction.
    priceIncrease = _priceIncrease;
  }

  // @dev Withdraw ether collected.
  function withdrawal()
    onlyOwner
    public
  {
    wallet.transfer(this.balance);
  }

}

/**
 * @title Origin Card.
 * @dev ERC20 Token that repesents Origin Cards.
 */
contract OriginCard is MintableToken {

  string public constant name = "Origin Card";
  string public constant symbol = "ORGC";
  uint8 public constant decimals = 0;

}