//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ISaltVaultBulls {
    function vaultedSaltCountOfOwner(address _owner) external view returns (uint256);
}

contract SaltVaultToken is IERC20, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // token data
    string private constant _name = "Salt Vault Token";
    string private constant _symbol = "SVT";
    uint8 private constant _decimals = 6;
    uint256 private constant precision = 10 ** 6;

    IERC20 public underlying;

    uint256 private _totalSupply;

    // Balances
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // Address -> Fee Exemption
    mapping(address => bool) public isTransferFeeExempt;

    mapping(address => uint256) public customFee;

    mapping(address => bool) public hasCustomFee;

    mapping(address => uint256) public preSaleAmount;

    mapping(address => bool) public contracts;

    mapping(address => bool) public isApprovedCaller;

    // Ecosystem Contracts
    address public saltVaultBulls;

    // Token Activation
    bool public tokenActivated;

    // presale
    bool public presaleOpen;

    // Fees
    uint256 public mintFee = 95000; // 5% presale mintfee
    uint256 public sellFee = 95000; // 5% redeem fee during presale
    uint256 public transferFee = 95000; // 5% transfer fee
    uint256 public contractFee = 95000; // 5% contract fee
    uint256 public non_holder = 90000; // 10% for non-holder, Doesn't own a Salt Vault Bull NFT

    uint256 private constant feeDenominator = 10 ** 5;

    // Fee Receiver Fees
    address public feeReceiver;

    uint256 public feeReceiverPercentage; // percentage of 100,000

    event PriceChange(uint256 previousPrice, uint256 currentPrice, uint256 totalSupply);
    event TokenActivated(uint blockNo);
    event presaleStatus(bool flag);
    event Burn(address from, uint256 amountTokensErased);
    event GarbageCollected(uint256 amountTokensErased);
    event Redeemed(address seller, uint256 amountSVT, uint256 amountUSDC);
    event Minted(address recipient, uint256 numTokens);
    event SetPermissions(address Contract, bool feeExempt);
    event SetFees(uint mintFee, uint transferFee, uint sellFee, uint contractFee);
    event SetFeeReceiver(address newReceiver);
    event SetUnderlying(address underlying);
    event SetFeeReceiverPercentage(uint256 newPercentage);
    event SellDownAccount(address account);
    event SetContract(address addr, bool value);

    constructor() {
        feeReceiverPercentage = 60000; // 60% of fee is taken for receivers to split for treasury
    }

    /** Returns the total number of tokens in existence */
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    /** Returns the number of tokens owned by `account` */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    /** Returns the number of tokens `spender` can transfer from `holder` */
    function allowance(address holder, address spender) external view override returns (uint256) {
        return _allowances[holder][spender];
    }

    /** Token Name */
    function name() public pure returns (string memory) {
        return _name;
    }

    /** Token Ticker Symbol */
    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    /** Tokens decimals */
    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    /** Approves `spender` to transfer `amount` tokens from caller */
    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /** Transfer Function */
    function transfer(address recipient, uint256 amount) external override nonReentrant returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }

    /** Transfer Function */
    function transferFrom(address sender, address recipient, uint256 amount) external override nonReentrant returns (bool) {
        _allowances[sender][msg.sender] = _allowances[sender][msg.sender].sub(amount, "Insufficient Allowance");
        return _transferFrom(sender, recipient, amount);
    }

    /** Internal Transfer */
    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        // make standard checks
        require(recipient != address(0) && sender != address(0), "Transfer To Zero");
        require(amount > 0, "Transfer Amt Zero");
        // track price change
        uint256 oldPrice = _calculatePrice();

        // Determine the appropriate transfer fee
        uint256 curFee = determineFeeForAddress(sender);

        // amount to give recipient
        // uint256 tAmount = (isTransferFeeExempt[sender] || isTransferFeeExempt[recipient]) ? amount : amount.mul(curFee).div(feeDenominator);

        uint256 tAmount = amount.mul(curFee).div(feeDenominator);

        // tax taken from transfer
        uint256 tax = amount.sub(tAmount);

        // subtract from sender
        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");

        // give reduced amount to receiver
        _balances[recipient] = _balances[recipient].add(tAmount);

        // burn the tax
        if (tax > 0) {
            // Take Fee
            _takeFee(tax);
            _totalSupply = _totalSupply.sub(tax);
            emit Transfer(sender, address(0), tax);
        }

        // require price rises
        _requirePriceRises(oldPrice);

        // Transfer Event
        emit Transfer(sender, recipient, tAmount);
        return true;
    }

    /** 
        Mint SVT Tokens For `recipient` By Depositing USDC Into The Contract
            Requirements:
                Approval from the USDC prior to purchase
        
        @param numTokens number of USDC tokens to mint SVT with
        @return tokensMinted number of SVT tokens minted
    */
    function mintWithBacking(uint256 numTokens) external nonReentrant returns (uint256) {
        _checkGarbageCollector(address(this));
        return _mintWithBacking(numTokens, msg.sender);
    }

    /** 
        Burns Sender's SVT Tokens and redeems their value in USDC
        @param tokenAmount Number of SVT Tokens To Redeem, Must be greater than 0
    */
    function sell(uint256 tokenAmount) external nonReentrant returns (uint256) {
        return _sell(msg.sender, tokenAmount, msg.sender);
    }

    /** 
        Burns Sender's SVT Tokens and redeems their value in USDC for `recipient`
        @param tokenAmount Number of SVT Tokens To Redeem, Must be greater than 0
        @param recipient Recipient Of USDC transfer, Must not be address(0)
    */
    function sellTo(uint256 tokenAmount, address recipient) external nonReentrant returns (uint256) {
        return _sell(msg.sender, tokenAmount, recipient);
    }

    /** 
        Allows A User To Erase Their Holdings From Supply 
        DOES NOT REDEEM UNDERLYING ASSET FOR USER
        @param amount Number of SVT Tokens To Burn
    */
    function burn(uint256 amount) external nonReentrant {
        // get balance of caller
        uint256 bal = _balances[msg.sender];
        require(bal >= amount && bal > 0, "Zero Holdings");
        // Track Change In Price
        uint256 oldPrice = _calculatePrice();
        // take fee
        _takeFee(amount);
        // burn tokens from sender + supply
        _burn(msg.sender, amount);
        // require price rises
        _requirePriceRises(oldPrice);
        // Emit Call
        emit Burn(msg.sender, amount);
    }

    /** Stake Tokens and Deposits SVT in Sender's Address, Must Have Prior Approval For USDC */
    function _mintWithBacking(uint256 amount, address recipient) internal returns (uint256) {
        require(tokenActivated, "Token Not Activated");

        // users token balance
        uint256 userTokenBalance = underlying.balanceOf(recipient);
        // ensure user has enough to send
        require(userTokenBalance > 0 && amount <= userTokenBalance, "Insufficient Balance");

        // calculate price change
        uint256 oldPrice = _calculatePrice();

        // amount of underlying
        uint256 amountUnderlying = underlyingBalance();

        // transfer in token
        uint256 received = _transferIn(amount);

        // Handle Minting
        return _mintTo(recipient, received, amountUnderlying, oldPrice);
    }

    /** Burns SVT Tokens And Deposits USDC Tokens into Recipients's Address */
    function _sell(address seller, uint256 tokenAmount, address recipient) internal returns (uint256) {
        require(tokenAmount > 0 && _balances[seller] >= tokenAmount);
        require(seller != address(0) && recipient != address(0));

        // calculate price change
        uint256 oldPrice = _calculatePrice();

        // Determine the appropriate sell fee
        uint256 curFee = determineFeeForAddress(seller);

        // tokens post fee to swap for underlying asset
        uint256 tokensToSwap = tokenAmount.mul(curFee).div(feeDenominator);

        // value of taxed tokens
        uint256 amountUnderlyingAsset = amountOut(tokensToSwap);

        // Take Fee
        if (!isTransferFeeExempt[msg.sender]) {
            uint fee = tokenAmount.sub(tokensToSwap);
            _takeFee(fee);
        }

        // burn from sender + supply
        _burn(seller, tokenAmount);

        // send Tokens to Seller
        require(underlying.transfer(recipient, amountUnderlyingAsset), "Underlying Transfer Failure");

        // require price rises
        _requirePriceRises(oldPrice);

        // Differentiate Sell
        emit Redeemed(seller, tokenAmount, amountUnderlyingAsset);

        // return token redeemed and amount underlying
        return amountUnderlyingAsset;
    }

    /** Handles Minting Logic To Create New SVT */
    function _mintTo(address recipient, uint256 received, uint256 totalBacking, uint256 oldPrice) private returns (uint256) {
        // find the number of tokens we should mint to keep SVT with the current price
        uint256 tokensToMintNoTax = _totalSupply == 0 ? received : _totalSupply.mul(received).div(totalBacking);

        // Determine the appropriate sell fee
        uint256 curFee = determineFeeForAddress(recipient);

        // // apply fee to minted tokens to inflate price relative to total supply
        uint256 tokensToMint = tokensToMintNoTax.mul(curFee).div(feeDenominator);

        require(tokensToMint > 0, "Zero Amount");

        // mint to Buyer
        _mint(recipient, tokensToMint);

        // apply fee to tax taken

        // Take Fee
        if (!isTransferFeeExempt[recipient]) {
            uint fee = tokensToMintNoTax.sub(tokensToMint);
            _takeFee(fee);
        }

        // require price rises
        _requirePriceRises(oldPrice);

        // differentiate purchase
        emit Minted(recipient, tokensToMint);
        return tokensToMint;
    }

    /** Takes Fee */
    function _takeFee(uint mFee) internal {
        uint256 feeToTake = (mFee * feeReceiverPercentage) / feeDenominator;
        if (feeToTake > 0 && feeReceiver != address(0)) {
            _mint(feeReceiver, feeToTake);
        }
    }

    /** Calculate Buy and Sell Fee based On Salt Grains  */
    function determineFeeForAddress(address _address) public view returns (uint256) {
        if (hasCustomFee[_address]) {
            return customFee[_address];
        } else {
            ISaltVaultBulls svbContract = ISaltVaultBulls(saltVaultBulls);
            // Get the amount of vaulted salt for the buyer
            uint256 vaultedSaltAmount = svbContract.vaultedSaltCountOfOwner(_address);

            if (vaultedSaltAmount == 0) return 90000; // 10%
            if (vaultedSaltAmount < 500) return 95000; // 5.0%
            if (vaultedSaltAmount < 1000) return 95250; // 4.75%
            if (vaultedSaltAmount < 2500) return 95500; // 4.50%
            if (vaultedSaltAmount < 5000) return 95750; // 4.25%
            if (vaultedSaltAmount < 7500) return 96000; // 4.00%
            if (vaultedSaltAmount < 10000) return 96250; // 3.75%
            return 96500; // 3.50% for 100000+
        }
    }

    /** Requires The Price Of SVT To Rise For The Transaction To Conclude */
    function _requirePriceRises(uint256 oldPrice) internal {
        // Calculate Price After Transaction
        uint256 newPrice = _calculatePrice();
        // Require Current Price >= Last Price
        require(newPrice >= oldPrice, "Price Cannot Fall");
        // Emit The Price Change
        emit PriceChange(oldPrice, newPrice, _totalSupply);
    }

    /** Transfers `desiredAmount` of `token` in and verifies the transaction success */
    function _transferIn(uint256 desiredAmount) internal returns (uint256) {
        uint256 balBefore = underlyingBalance();
        require(underlying.transferFrom(msg.sender, address(this), desiredAmount), "Failure Transfer From");
        uint256 balAfter = underlyingBalance();
        require(balAfter > balBefore, "Zero Received");
        return balAfter - balBefore;
    }

    /** Mints Tokens to the Receivers Address */
    function _mint(address receiver, uint amount) private {
        _balances[receiver] = _balances[receiver].add(amount);
        _totalSupply = _totalSupply.add(amount);
        emit Transfer(address(0), receiver, amount);
    }

    /** Burns `amount` of tokens from `account` */
    function _burn(address account, uint amount) private {
        _balances[account] = _balances[account].sub(amount, "Insufficient Balance");
        _totalSupply = _totalSupply.sub(amount, "Negative Supply");
        emit Transfer(account, address(0), amount);
    }

    /** Make Sure there's no Native Tokens in contract */
    function _checkGarbageCollector(address burnLocation) internal {
        uint256 bal = _balances[burnLocation];
        if (bal > 10 ** 3) {
            // Track Change In Price
            uint256 oldPrice = _calculatePrice();
            // take fee
            _takeFee(bal);
            // burn amount
            _burn(burnLocation, bal);
            // Emit Collection
            emit GarbageCollected(bal);
            // Emit Price Difference
            emit PriceChange(oldPrice, _calculatePrice(), _totalSupply);
        }
    }

    function underlyingBalance() public view returns (uint256) {
        return underlying.balanceOf(address(this));
    }

    /** Price Of SVT in USDC With 6 Points Of Precision */
    function calculatePrice() external view returns (uint256) {
        return _calculatePrice();
    }

    /** Returns the Current Price of 1 Token */
    function _calculatePrice() internal view returns (uint256) {
        return _totalSupply == 0 ? 10 ** 6 : (underlyingBalance().mul(precision)).div(_totalSupply);
    }

    /**
        Amount Of Underlying To Receive For `numTokens` of SVT
     */
    function amountOut(uint256 numTokens) internal view returns (uint256) {
        return _calculatePrice().mul(numTokens).div(precision);
    }

    /** Returns the value of `holder`'s holdings */
    function getValueOfHoldings(address holder) public view returns (uint256) {
        return amountOut(_balances[holder]);
    }

    /** Activates/Pauses Token */
    function activateToken(bool _flag) external onlyOwner {
        require(isApprovedCaller[saltVaultBulls], "must set saltVaultBulls");
        require(address(underlying) != address(0), "Must set the underlying token first");
        require(address(feeReceiver) != address(0), "Must set the feeReceiver token first");

        tokenActivated = _flag;
        emit TokenActivated(block.number);
    }

    function presaleToggle(bool _flag) external onlyOwner {
        require(isApprovedCaller[saltVaultBulls], "must set saltVaultBulls");
        require(address(underlying) != address(0), "Must set the underlying token first");
        require(address(feeReceiver) != address(0), "Must set the feeReceiver token first");

        presaleOpen = _flag;
        emit presaleStatus(presaleOpen);
    }

    function setFeeReceiver(address newReceiver) external onlyOwner {
        require(newReceiver != address(0), "Zero Address");
        feeReceiver = newReceiver;
        emit SetFeeReceiver(newReceiver);
    }

    function setFeeReceiverPercentage(uint256 newPercentage) external onlyOwner {
        require(newPercentage <= ((9 * feeDenominator) / 10), "Invalid Percentage");
        feeReceiverPercentage = newPercentage;
        emit SetFeeReceiverPercentage(newPercentage);
    }

    function setUnderlyingToken(address _underlyingToken) external onlyOwner {
        require(_underlyingToken != address(0), "Zero Address");
        underlying = IERC20(_underlyingToken);
        emit SetUnderlying(_underlyingToken);
    }

    /** Withdraws Tokens Incorrectly Sent To SVT */
    function withdrawNonStableToken(IERC20 token) external onlyOwner {
        require(address(token) != address(underlying), "Cannot Withdraw Underlying Asset");
        require(address(token) != address(0), "Zero Address");
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    function setCustomFee(address[] memory _address, uint256[] memory _fee) external onlyOwner {
        for (uint256 i = 0; i < _address.length; i++) {
            require(_fee[i] >= 90000 && _fee[i] <= 100000, "Invalid fee");
            customFee[_address[i]] = _fee[i];
            hasCustomFee[_address[i]] = true;
        }
    }

    function removeCustomFee(address _address) external onlyOwner {
        hasCustomFee[_address] = false;
    }

    function setPresaleAmountFromApprovedCaller(address _address, uint256 _allocation) external {
        require(isApprovedCaller[msg.sender] == true, "Not An Authorized Caller");
        preSaleAmount[_address] += _allocation;
    }

    function setPresaleAmountBulk(address[] memory _addresses, uint256 _allocation) external onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            preSaleAmount[_addresses[i]] += _allocation;
        }
    }

    /** 
        Sells Tokens On Tax Free On Behalf Of Other User Tax Free
        Prevents Locked or Inaccessible funds from appreciating indefinitely
     */
    function sellDownExternalAccount(address account) external nonReentrant onlyOwner {
        require(account != address(0), "Zero Address");
        require(_balances[account] > 0, "Zero Amount");

        // exempt account from fees and sell them down
        isTransferFeeExempt[account] = true;
        _sell(account, _balances[account], account);
        isTransferFeeExempt[account] = false;

        // emit sell down event
        emit SellDownAccount(account);
    }

    /** 
        Sets Mint, Transfer, Sell Fee, Contract Fee
        Must Be Within Bounds ( Between 0% - 5% ) 
    */
    function setFees(uint256 _mintFee, uint256 _transferFee, uint256 _sellFee, uint256 _contractFee) external onlyOwner {
        require(_mintFee >= 95000); // capped at 5% fee
        require(_transferFee >= 95000);
        require(_sellFee >= 95000);
        require(_contractFee >= 95000);

        mintFee = _mintFee;
        transferFee = _transferFee;
        sellFee = _sellFee;
        contractFee = _contractFee;

        emit SetFees(_mintFee, _transferFee, _sellFee, _contractFee);
    }

    /** Excludes Contract From Transfer Fees */
    function setTransferFeeExempt(address Contract, bool transferFeeExempt) external onlyOwner {
        require(Contract != address(0), "Zero Address");
        isTransferFeeExempt[Contract] = transferFeeExempt;
        emit SetPermissions(Contract, transferFeeExempt);
    }

    function setContract(address _add, bool _value) external onlyOwner {
        require(contracts[_add] != _value, "Value already set");
        contracts[_add] = _value;
        emit SetContract(_add, _value);
    }

    function setApprovedCallerRole(address _address, bool value) external onlyOwner {
        isApprovedCaller[_address] = value;
    }

    /** Mint Tokens to Buyer */
    receive() external payable {
        _checkGarbageCollector(address(this));
        // _mintWithNative(msg.sender, 0);
    }

    function setSaltVaultBullsAddress(address _saltVaultBulls) external onlyOwner {
        saltVaultBulls = _saltVaultBulls;
        isApprovedCaller[saltVaultBulls] = true;
    }

    function isReadyForTrdContracts(address _address) external view returns (bool) {
        return isApprovedCaller[_address];
    }

    function isCurrentContractFeeExempt(address _address) public view returns (bool) {
        return isTransferFeeExempt[_address];
    }
}
