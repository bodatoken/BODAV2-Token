// SPDX-License-Identifier: Unlicensed

//
// $BODAV2 offers long term security and passsive income in BUSD.
//
// AUTOMATIC DIVIDEND YIELD PAID IN BUSD! With the auto-claim feature,
// simply hold $BODAV2 and you receive BUSD automatically in your wallet.
// 
// Hold BODAV2 and get rewarded in Busd on every transaction!
//
// 📱 Telegram: https://t.me/Boda_Token
// 🌎 Website: https://bodatoken.org
// 🌐 Twitter: https://twitter.com/BodaToken
 
pragma solidity ^0.8.4;
import "./BUSDDividendTracker.sol";


contract BodaV2 is ERC20, Ownable {
    using SafeMath for uint256;
 
    IUniswapV2Router02 public uniswapV2Router;
    address public immutable uniswapV2Pair;
 
    address public busdDividendToken;
    address public deadAddress = 0x000000000000000000000000000000000000dEaD;
 
    bool private swapping;
    bool public tradingIsEnabled = false;
    bool public marketingEnabled = true;
    bool public swapAndLiquifyEnabled = true;
    bool public busdDividendEnabled = true;

 
    BUSDDividendTracker public busdDividendTracker;
    
    address public marketingWallet;
 
    uint256 public maxBuyTranscationAmount = 10000000000000 * (10**18);
    uint256 public maxSellTransactionAmount = 1000000000000 * (10**18);
    uint256 public maxWalletBalance = 1000000000000000 * (10**18);
    uint256 public swapTokensAtAmount = 20 * 10**6 * 10**18;
 
    uint256 public liquidityFee;
    uint256 public previousLiquidityFee;

    uint256 public busdDividendRewardsFee;
    uint256 public previousBusdDividendRewardsFee;

    uint256 public marketingFee;
    uint256 public previousMarketingFee;

    uint256 public totalFees = busdDividendRewardsFee.add(marketingFee).add(liquidityFee);
    
    uint256 public _busdDividendRewardsFeeBuy = 6;
    uint256 public _marketingFeeBuy = 4;
    uint256 public _LpFeeBuy = 2;

    uint256 public _busdDividendRewardsFeeSell=13;
    uint256 public _LpFeeSell=2;
    uint256 public _marketingFeeSell=5;  
 
    uint256 public busdDividedRewardsInContract;
    uint256 public tokensForLpInContract;

    uint256 public sellFeeIncreaseFactor = 130;
 
    uint256 public gasForProcessing = 600000;
 
    mapping (address => bool) private isExcludedFromFees;
 
    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping (address => bool) public automatedMarketMakerPairs;
 
    event UpdatebusdDividendTracker(address indexed newAddress, address indexed oldAddress);
    
    event UpdateUniswapV2Router(address indexed newAddress, address indexed oldAddress);
 
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event MarketingEnabledUpdated(bool enabled);
    event BusdDividendEnabledUpdated(bool enabled);
    
 
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);
 
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
 
    event MarketingWalletUpdated(address indexed newMarketingWallet, address indexed oldMarketingWallet);
 
    event GasForProcessingUpdated(uint256 indexed newValue, uint256 indexed oldValue);
 
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 bnbReceived,
        uint256 tokensIntoLiqudity
    );
 
    event SendDividends(
    	uint256 amount
    );
 
    event ProcessedbusdDividendTracker(
    	uint256 iterations,
    	uint256 claims,
        uint256 lastProcessedIndex,
    	bool indexed automatic,
    	uint256 gas,
    	address indexed processor
    );
 
    
 
    constructor() ERC20("BODA", "BODAV2") {
        	
    	marketingWallet = 0x4e65443994A45117BbF1E749B98045C0874Ca0ac; 
    	busdDividendToken = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56; 

        busdDividendTracker = new BUSDDividendTracker(busdDividendToken);

    	IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
         // Create a uniswap pair for this new token
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
 
        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;
 
        _setAutomatedMarketMakerPair(_uniswapV2Pair, true);
 
        excludeFromDividend(address(busdDividendTracker));
        excludeFromDividend(address(this));
        excludeFromDividend(address(_uniswapV2Router));
        excludeFromDividend(deadAddress);
 
        // exclude from paying fees or having max transaction amount
        excludeFromFees(marketingWallet, true);
        excludeFromFees(address(this), true);
        excludeFromFees(deadAddress, true);
        excludeFromFees(owner(), true);
 
        setAuthOnDividends(owner());
 
        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(owner(), 1000000000000000 * (10**18));
    }
 
    receive() external payable {
 
  	}
 
  	function prepareForPartherOrExchangeListing(address _partnerOrExchangeAddress) external onlyOwner {
  	    busdDividendTracker.excludeFromDividends(_partnerOrExchangeAddress);
        excludeFromFees(_partnerOrExchangeAddress, true);
  	}
 
  	function setWalletBalance(uint256 _maxWalletBalance) external onlyOwner{
  	    maxWalletBalance = _maxWalletBalance;
  	}
 
  	function setMaxBuyTransaction(uint256 _maxTxn) external onlyOwner {
  	    maxBuyTranscationAmount = _maxTxn * (10**18);
  	}
 
  	function setMaxSellTransaction(uint256 _maxTxn) external onlyOwner {
  	    maxSellTransactionAmount = _maxTxn * (10**18);
  	}
 
 
  	function updateBusdDividendToken(address _newContract) external onlyOwner {
  	    busdDividendToken = _newContract;
  	    busdDividendTracker.setDividendTokenAddress(_newContract);
  	}
 
  	function updateMarketingWallet(address _newWallet) external onlyOwner {
  	    require(_newWallet != marketingWallet, "Boda: The marketing wallet is already this address");
        excludeFromFees(_newWallet, true);
        emit MarketingWalletUpdated(marketingWallet, _newWallet);
  	    marketingWallet = _newWallet;
  	}
 
  	function setSwapTokensAtAmount(uint256 _swapAmount) external onlyOwner {
  	    swapTokensAtAmount = _swapAmount * (10**18);
  	}
 
  	function setSellTransactionMultiplier(uint256 _multiplier) external onlyOwner {
  	    sellFeeIncreaseFactor = _multiplier;
  	}
 
 
    function setTradingIsEnabled(bool _enabled) external onlyOwner {
        tradingIsEnabled = _enabled;
    }
 
    function setAuthOnDividends(address account) public onlyOwner {
        busdDividendTracker.setAuth(account);
    }
 
    function setBusdDividendEnabled(bool _enabled) external onlyOwner {
        require(busdDividendEnabled != _enabled, "Can't set flag to same status");
        if (_enabled == false) {
            previousBusdDividendRewardsFee = busdDividendRewardsFee;
            busdDividendRewardsFee = 0;
            busdDividendEnabled = _enabled;
        }
 
        emit BusdDividendEnabledUpdated(_enabled);
    }
 
 
    function setMarketingEnabled(bool _enabled) external onlyOwner {
        require(marketingEnabled != _enabled, "Can't set flag to same status");
        if (_enabled == false) {
            previousMarketingFee = marketingFee;
            marketingFee = 0;
            marketingEnabled = _enabled;
        } 
 
        emit MarketingEnabledUpdated(_enabled);
    }
 
    function setSwapAndLiquifyEnabled(bool _enabled) external onlyOwner {
        require(swapAndLiquifyEnabled != _enabled, "Can't set flag to same status");
        if (_enabled == false) {
            previousLiquidityFee = liquidityFee;
            liquidityFee = 0;
            swapAndLiquifyEnabled = _enabled;
        } 
 
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }
 
 
    function updatebusdDividendTracker(address newAddress) external onlyOwner {
        require(newAddress != address(busdDividendTracker), "Boda: The dividend tracker already has that address");
 
        BUSDDividendTracker newbusdDividendTracker = BUSDDividendTracker(payable(newAddress));
 
        require(newbusdDividendTracker.owner() == address(this), "Boda: The new dividend tracker must be owned by the Boda token contract");
 
        newbusdDividendTracker.excludeFromDividends(address(newbusdDividendTracker));
        newbusdDividendTracker.excludeFromDividends(address(this));
        newbusdDividendTracker.excludeFromDividends(address(uniswapV2Router));
        newbusdDividendTracker.excludeFromDividends(address(deadAddress));
 
        emit UpdatebusdDividendTracker(newAddress, address(busdDividendTracker));
 
        busdDividendTracker = newbusdDividendTracker;
    }
 
    function updateUniswapV2Router(address newAddress) external onlyOwner {
        require(newAddress != address(uniswapV2Router), "Boda: The router already has that address");
        emit UpdateUniswapV2Router(newAddress, address(uniswapV2Router));
        uniswapV2Router = IUniswapV2Router02(newAddress);
    }
 
    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(isExcludedFromFees[account] != excluded, "Boda: Account is already exluded from fees");
        isExcludedFromFees[account] = excluded;
 
        emit ExcludeFromFees(account, excluded);
    }
 
    function excludeFromDividend(address account) public onlyOwner {
        busdDividendTracker.excludeFromDividends(address(account));
       
    }
 
    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(pair != uniswapV2Pair, "Boda: The PancakeSwap pair cannot be removed from automatedMarketMakerPairs");
 
        _setAutomatedMarketMakerPair(pair, value);
    }
 
    function _setAutomatedMarketMakerPair(address pair, bool value) private onlyOwner {
        require(automatedMarketMakerPairs[pair] != value, "Boda: Automated market maker pair is already set to that value");
        automatedMarketMakerPairs[pair] = value;
 
        if(value) {
            busdDividendTracker.excludeFromDividends(pair);
          
        }
 
        emit SetAutomatedMarketMakerPair(pair, value);
    }
 
    function updateGasForProcessing(uint256 newValue) external onlyOwner {
        require(newValue != gasForProcessing, "Boda: Cannot update gasForProcessing to same value");
        gasForProcessing = newValue;
        emit GasForProcessingUpdated(newValue, gasForProcessing);
    }
 
    function updateMinimumBalanceForDividends(uint256 newMinimumBalance) external onlyOwner {
        busdDividendTracker.updateMinimumTokenBalanceForDividends(newMinimumBalance);
    }
 
    function updateClaimWait(uint256 claimWait) external onlyOwner {
        busdDividendTracker.updateClaimWait(claimWait);

    }
 
    function getBusdClaimWait() external view returns(uint256) {
        return busdDividendTracker.claimWait();
    }
 
  
 
    function getTotalBusdDividendsDistributed() external view returns (uint256) {
        return busdDividendTracker.totalDividendsDistributed();
    }
 
    
 
    function getIsExcludedFromFees(address account) public view returns(bool) {
        return isExcludedFromFees[account];
    }
 
    function withdrawableBusdDividendOf(address account) external view returns(uint256) {
    	return busdDividendTracker.withdrawableDividendOf(account);
  	}
 
  	
 
	function busdDividendTokenBalanceOf(address account) external view returns (uint256) {
		return busdDividendTracker.balanceOf(account);
	}
 
	
 
    function getAccountBusdDividendsInfo(address account)
        external view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
        return busdDividendTracker.getAccount(account);
    }
 
 
	function getAccountBusdDividendsInfoAtIndex(uint256 index)
        external view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
    	return busdDividendTracker.getAccountAtIndex(index);
    }
 
    
	function processDividendTracker(uint256 gas) external onlyOwner {
		(uint256 busdIterations, uint256 busdClaims, uint256 busdLastProcessedIndex) = busdDividendTracker.process(gas);
		emit ProcessedbusdDividendTracker(busdIterations, busdClaims, busdLastProcessedIndex, false, gas, tx.origin);
 
		
    }
 
    function claim() external {
		busdDividendTracker.processAccount(payable(msg.sender), false);
		
    }
    function getLastBusdDividendProcessedIndex() external view returns(uint256) {
    	return busdDividendTracker.getLastProcessedIndex();
    }
 
    
 
    function getNumberOfBusdDividendTokenHolders() external view returns(uint256) {
        return busdDividendTracker.getNumberOfTokenHolders();
    }
 
 
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(tradingIsEnabled || (isExcludedFromFees[from] || isExcludedFromFees[to]), "Boda: Trading has not started yet");
 
        bool excludedAccount = isExcludedFromFees[from] || isExcludedFromFees[to];
 
        if(!automatedMarketMakerPairs[to] && tradingIsEnabled && !excludedAccount){
            require(balanceOf(to).add(amount) <= maxWalletBalance, 'Wallet balance is exceeding maxWalletBalance');
        }
 
        if (
            tradingIsEnabled &&
            automatedMarketMakerPairs[from] &&
            !excludedAccount
        ) {
            require(amount <= maxBuyTranscationAmount, "Transfer amount exceeds the maxTxAmount.");

            busdDividendRewardsFee = _busdDividendRewardsFeeBuy;
            marketingFee = _marketingFeeBuy;
            liquidityFee = _LpFeeBuy;
 	    
        } else if (
        	tradingIsEnabled &&
            automatedMarketMakerPairs[to] &&
            !excludedAccount
        ) {
            require(amount <= maxSellTransactionAmount, "Sell transfer amount exceeds the maxSellTransactionAmount.");

            busdDividendRewardsFee = _busdDividendRewardsFeeSell;
            marketingFee = _marketingFeeSell;
            liquidityFee = _LpFeeSell;

        }
 
 
        uint256 contractTokenBalance = balanceOf(address(this));
        bool canSwap = contractTokenBalance >= swapTokensAtAmount;
 
        if (!swapping && canSwap && from != uniswapV2Pair) {
            swapping = true;
 
            if(swapAndLiquifyEnabled) {
                uint256 liqTokens = tokensForLpInContract;
                swapAndLiquify(liqTokens);
                tokensForLpInContract = 0;
            }
 
            if (busdDividendEnabled) {
                uint256 busdTokens = busdDividedRewardsInContract;
                swapAndSendBusdDividends(busdTokens);
                busdDividedRewardsInContract = 0;
            }
 
 
                swapping = false;
        }
 
        bool takeFee = tradingIsEnabled && !swapping && !excludedAccount;
 
        if(takeFee) {
        	uint256 fees;

            uint256 tmpMarketingRewardPercent;
            uint256 tmpBusdDividedRewardsInContract;
            uint256 tmpLpRewardInContract;

            tmpMarketingRewardPercent = amount.mul(marketingFee).div(100);
            tmpBusdDividedRewardsInContract = amount.mul(busdDividendRewardsFee).div(100);
            tmpLpRewardInContract = amount.mul(liquidityFee).div(100);

            fees = tmpMarketingRewardPercent.add(tmpBusdDividedRewardsInContract)
                            .add(tmpLpRewardInContract);

            busdDividedRewardsInContract = busdDividedRewardsInContract.add(tmpBusdDividedRewardsInContract);

            tokensForLpInContract = tokensForLpInContract.add(tmpLpRewardInContract);

            // if sell, multiply by 1.2
            if(automatedMarketMakerPairs[to]) {
                fees = fees.div(100).mul(sellFeeIncreaseFactor);
            }

        	amount = amount.sub(fees);
            super._transfer(from, address(this), fees);
            super._transfer(address(this),marketingWallet,tmpMarketingRewardPercent);
        }
 
        super._transfer(from, to, amount);
 
        try busdDividendTracker.setBalance(payable(from), balanceOf(from)) {} catch {}
        
        try busdDividendTracker.setBalance(payable(to), balanceOf(to)) {} catch {}
        
        if(!swapping) {
	    	uint256 gas = gasForProcessing;
 
	    	try busdDividendTracker.process(gas) returns (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) {
	    		emit ProcessedbusdDividendTracker(iterations, claims, lastProcessedIndex, true, gas, tx.origin);
	    	}
	    	catch {
 
	    	}
        }
    }
 
 
    function swapAndLiquify(uint256 contractTokenBalance) private {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);
 
        uint256 initialBalance = address(this).balance;
 
        swapTokensForBNB(half);
 
        uint256 newBalance = address(this).balance.sub(initialBalance);
 
        addLiquidity(otherHalf, newBalance);
 
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }
 
    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
 
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);
 
        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            marketingWallet,
            block.timestamp
        );
    }
 
 
    function swapTokensForBNB(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
 
        _approve(address(this), address(uniswapV2Router), tokenAmount);
 
        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
 
    }
 
    function swapTokensForDividendToken(uint256 _tokenAmount, address _recipient, address _dividendAddress) private {
        address[] memory path = new address[](3);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        path[2] = _dividendAddress;
 
        _approve(address(this), address(uniswapV2Router), _tokenAmount);
 
        // make the swap
        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _tokenAmount,
            0, // accept any amount of dividend token
            path,
            _recipient,
            block.timestamp
        );
    }
 
    function swapAndSendBusdDividends(uint256 tokens) private {
        swapTokensForDividendToken(tokens, address(this), busdDividendToken);
        uint256 busdDividends = IERC20(busdDividendToken).balanceOf(address(this));
        transferDividends(busdDividendToken, address(busdDividendTracker), busdDividendTracker, busdDividends);
    }
 
 
    function transferToWallet(address payable recipient, uint256 amount) private {
        recipient.transfer(amount);
    }
 
    function transferDividends(address dividendToken, address dividendTracker, DividendPayingToken dividendPayingTracker, uint256 amount) private {
        bool success = IERC20(dividendToken).transfer(dividendTracker, amount);
 
        if (success) {
            dividendPayingTracker.distributeDividends(amount);
            emit SendDividends(amount);
        }
    }
}
