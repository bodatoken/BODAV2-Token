// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.4;


contract DogeCake is ERC20, Ownable {
    using SafeMath for uint256;

    IUniswapV2Router02 public uniswapV2Router;
    address public immutable uniswapV2Pair;

    address public cakeDividendToken;
    address public dogeDividendToken;
    address public deadAddress = 0x000000000000000000000000000000000000dEaD;

    bool private swapping;
    bool public tradingIsEnabled = false;
    bool public marketingEnabled = false;
    bool public buyBackAndLiquifyEnabled = false;
    bool public cakeDividendEnabled = false;
    bool public dogeDividendEnabled = false;

    CakeDividendTracker public cakeDividendTracker;
    DogeDividendTracker public dogeDividendTracker;

    address public marketingWallet;
    
    uint256 public maxBuyTranscationAmount;
    uint256 public maxSellTransactionAmount;
    uint256 public swapTokensAtAmount;
    uint256 public maxWalletToken; 

//-------------------- BODA Special ---------------------------------
    uint256 public _yieldFarmingFeeBuy;
    uint256 public _bnbDividendRewardsFeeBuy;
    uint256 public _marketingFeeBuy;
    uint256 public _LpFeeBuy;
    // uint256 public _totalFeesBuy;

    uint256 public _yieldFarmingFeeSell;
    uint256 public _bnbDividendRewardsFeeSell;
    uint256 public _LpFeeSell;
    uint256 public _DevelpmentFeeSell;
    // uint256 public _totalFeesSell;

    uint public percentPrecision = 1000;
    uint public buyLimit = 10; // 0.01%
    uint public sellLimit = 100; // 0.1%

    address public yieldFarmAddress;

// ------------------------------------------------------------

    uint256 public cakeDividendRewardsFee;
    uint256 public previousCakeDividendRewardsFee;

    uint256 public dogeDividendRewardsFee;
    uint256 public previousDogeDividendRewardsFee;

    uint256 public marketingFee;
    uint256 public previousMarketingFee;

    uint256 public buyBackAndLiquidityFee;
    uint256 public previousBuyBackAndLiquidityFee;

    uint256 public totalFees;

    uint256 public sellFeeIncreaseFactor = 130;

    uint256 public gasForProcessing = 600000;
    
    address public presaleAddress;

    mapping (address => bool) private isExcludedFromFees;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping (address => bool) public automatedMarketMakerPairs;

    event UpdateCakeDividendTracker(address indexed newAddress, address indexed oldAddress);
    event UpdateDogeDividendTracker(address indexed newAddress, address indexed oldAddress);

    event UpdateUniswapV2Router(address indexed newAddress, address indexed oldAddress);
    
    event BuyBackAndLiquifyEnabledUpdated(bool enabled);
    event MarketingEnabledUpdated(bool enabled);
    event CakeDividendEnabledUpdated(bool enabled);
    event DogeDividendEnabledUpdated(bool enabled);

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[10] accounts, bool isExcluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event MarketingWalletUpdated(address indexed newMarketingWallet, address indexed oldMarketingWallet);

    event GasForProcessingUpdated(uint256 indexed newValue, uint256 indexed oldValue);

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 cakeReceived,
        uint256 tokensIntoLiqudity
    );

    event SendDividends(
    	uint256 amount
    );
    
    event SwapBNBForTokens(
        uint256 amountIn,
        address[] path
    );

    event ProcessedCakeDividendTracker(
    	uint256 iterations,
    	uint256 claims,
        uint256 lastProcessedIndex,
    	bool indexed automatic,
    	uint256 gas,
    	address indexed processor
    );
    
    event ProcessedDogeDividendTracker(
    	uint256 iterations,
    	uint256 claims,
        uint256 lastProcessedIndex,
    	bool indexed automatic,
    	uint256 gas,
    	address indexed processor
    );

    constructor(address _uniswapRouter02,address _cake,address _doge,address _marketWallet,address _dividendToken,address _yieldFarmAddress) ERC20("Doge Cake", "DCAKE") {
    	cakeDividendTracker = new CakeDividendTracker();
    	dogeDividendTracker = new DogeDividendTracker(_dividendToken);

    	marketingWallet = _marketWallet;
    	cakeDividendToken = _cake;
        dogeDividendToken = _doge;
    	
    	IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_uniswapRouter02);
         // Create a uniswap pair for this new token
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;

        _setAutomatedMarketMakerPair(_uniswapV2Pair, true);
        
        excludeFromDividend(address(cakeDividendTracker));
        excludeFromDividend(address(dogeDividendTracker));
        excludeFromDividend(address(_uniswapV2Router));
        excludeFromDividend(deadAddress);

        // exclude from paying fees or having max transaction amount
        excludeFromFees(marketingWallet, true);
        excludeFromFees(address(this), true);
        excludeFromFees(owner(), true);

        yieldFarmAddress = _yieldFarmAddress;

        _LpFeeBuy = 1;
        _yieldFarmingFeeBuy = 2;
        _bnbDividendRewardsFeeBuy = 6;
        _marketingFeeBuy = 3;

        _yieldFarmingFeeSell = 2;
        _bnbDividendRewardsFeeSell = 13;
        _LpFeeSell = 2;
        _DevelpmentFeeSell = 3;

        marketingEnabled = true;
        buyBackAndLiquifyEnabled = true;
        cakeDividendEnabled = true;
        dogeDividendEnabled = true;
        swapTokensAtAmount = 20000000 * (10**18);
        maxBuyTranscationAmount = 100000000000 * (10**18);
        maxSellTransactionAmount = 300000000 * (10**18);
        maxWalletToken = 100000000000 * (10**18);


        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(owner(), 100000000000 * (10**18));
    }

    receive() external payable {

  	}

  	// function whitelistDxSale(address _presaleAddress, address _routerAddress) external onlyOwner {
  	//     presaleAddress = _presaleAddress;
    //     cakeDividendTracker.excludeFromDividends(_presaleAddress);
    //     dogeDividendTracker.excludeFromDividends(_presaleAddress);
    //     excludeFromFees(_presaleAddress, true);

    //     cakeDividendTracker.excludeFromDividends(_routerAddress);
    //     dogeDividendTracker.excludeFromDividends(_routerAddress);
    //     excludeFromFees(_routerAddress, true);
  	// }

  	function prepareForPartherOrExchangeListing(address _partnerOrExchangeAddress) external onlyOwner {
  	    cakeDividendTracker.excludeFromDividends(_partnerOrExchangeAddress);
        dogeDividendTracker.excludeFromDividends(_partnerOrExchangeAddress);
        excludeFromFees(_partnerOrExchangeAddress, true);
  	}
  	
  	function setMaxBuyTransaction(uint256 _maxTxn) external onlyOwner {
  	    maxBuyTranscationAmount = _maxTxn * (10**18);
  	}
  	
  	function setMaxSellTransaction(uint256 _maxTxn) external onlyOwner {
  	    maxSellTransactionAmount = _maxTxn * (10**18);
  	}
  	
  	function updateDogeDividendToken(address _newContract) external onlyOwner {
  	    dogeDividendToken = _newContract;
  	    dogeDividendTracker.setDividendTokenAddress(_newContract);
  	}
  	
  	function updateCakeDividendToken(address _newContract) external onlyOwner {
  	    cakeDividendToken = _newContract;
  	    cakeDividendTracker.setDividendTokenAddress(_newContract);
  	}
  	
	
  	function updateMarketingWallet(address _newWallet) external onlyOwner {
  	    require(_newWallet != marketingWallet, "DogeCake: The marketing wallet is already this address");
        excludeFromFees(_newWallet, true);
        emit MarketingWalletUpdated(marketingWallet, _newWallet);
  	    marketingWallet = _newWallet;
  	}
  	
  	function setMaxWalletTokend(uint256 _maxToken) external onlyOwner {
  	    maxWalletToken = _maxToken * (10**18);
  	}
  	
  	function setSwapTokensAtAmount(uint256 _swapAmount) external onlyOwner {
  	    swapTokensAtAmount = _swapAmount * (10**18);
  	}
  	
  	function setSellTransactionMultiplier(uint256 _multiplier) external onlyOwner {
  	    sellFeeIncreaseFactor = _multiplier;
  	}

    // function afterPreSale() external onlyOwner {
    //     cakeDividendRewardsFee = 4;
    //     dogeDividendRewardsFee = 4;
    //     marketingFee = 5;
    //     buyBackAndLiquidityFee = 2;
    //     totalFees = 15;
    //     marketingEnabled = true;
    //     buyBackAndLiquifyEnabled = true;
    //     cakeDividendEnabled = true;
    //     dogeDividendEnabled = true;
    //     swapTokensAtAmount = 20000000 * (10**18);
    //     maxBuyTranscationAmount = 100000000000 * (10**18);
    //     maxSellTransactionAmount = 300000000 * (10**18);
    //     maxWalletToken = 100000000000 * (10**18);
    // }
    
    function setTradingIsEnabled(bool _enabled) external onlyOwner {
        tradingIsEnabled = _enabled;
    }
    
    function setBuyBackAndLiquifyEnabled(bool _enabled) external onlyOwner {
        require(buyBackAndLiquifyEnabled != _enabled, "Can't set flag to same status");
        if (_enabled == false) {
            previousBuyBackAndLiquidityFee = buyBackAndLiquidityFee;
            buyBackAndLiquidityFee = 0;
            buyBackAndLiquifyEnabled = _enabled;
        } else {
            buyBackAndLiquidityFee = previousBuyBackAndLiquidityFee;
            totalFees = buyBackAndLiquidityFee.add(marketingFee).add(dogeDividendRewardsFee).add(cakeDividendRewardsFee);
            buyBackAndLiquifyEnabled = _enabled;
        }
        
        emit BuyBackAndLiquifyEnabledUpdated(_enabled);
    }
    
    function setCakeDividendEnabled(bool _enabled) external onlyOwner {
        require(cakeDividendEnabled != _enabled, "Can't set flag to same status");
        if (_enabled == false) {
            previousCakeDividendRewardsFee = cakeDividendRewardsFee;
            cakeDividendRewardsFee = 0;
            cakeDividendEnabled = _enabled;
        } else {
            cakeDividendRewardsFee = previousCakeDividendRewardsFee;
            totalFees = cakeDividendRewardsFee.add(marketingFee).add(dogeDividendRewardsFee).add(buyBackAndLiquidityFee);
            cakeDividendEnabled = _enabled;
        }

        emit CakeDividendEnabledUpdated(_enabled);
    }
    
    function setDogeDividendEnabled(bool _enabled) external onlyOwner {
        require(dogeDividendEnabled != _enabled, "Can't set flag to same status");
        if (_enabled == false) {
            previousDogeDividendRewardsFee = dogeDividendRewardsFee;
            dogeDividendRewardsFee = 0;
            dogeDividendEnabled = _enabled;
        } else {
            dogeDividendRewardsFee = previousDogeDividendRewardsFee;
            totalFees = dogeDividendRewardsFee.add(marketingFee).add(cakeDividendRewardsFee).add(buyBackAndLiquidityFee);
            dogeDividendEnabled = _enabled;
        }

        emit DogeDividendEnabledUpdated(_enabled);
    }
    
    function setMarketingEnabled(bool _enabled) external onlyOwner {
        require(marketingEnabled != _enabled, "Can't set flag to same status");
        if (_enabled == false) {
            previousMarketingFee = marketingFee;
            marketingFee = 0;
            marketingEnabled = _enabled;
        } else {
            marketingFee = previousMarketingFee;
            totalFees = marketingFee.add(dogeDividendRewardsFee).add(cakeDividendRewardsFee).add(buyBackAndLiquidityFee);
            marketingEnabled = _enabled;
        }

        emit MarketingEnabledUpdated(_enabled);
    }

    function updateCakeDividendTracker(address newAddress) external onlyOwner {
        require(newAddress != address(cakeDividendTracker), "DogeCake: The dividend tracker already has that address");

        CakeDividendTracker newCakeDividendTracker = CakeDividendTracker(payable(newAddress));

        require(newCakeDividendTracker.owner() == address(this), "DogeCake: The new dividend tracker must be owned by the DogeCake token contract");

        newCakeDividendTracker.excludeFromDividends(address(newCakeDividendTracker));
        newCakeDividendTracker.excludeFromDividends(address(this));
        newCakeDividendTracker.excludeFromDividends(address(uniswapV2Router));
        newCakeDividendTracker.excludeFromDividends(address(deadAddress));

        emit UpdateCakeDividendTracker(newAddress, address(cakeDividendTracker));

        cakeDividendTracker = newCakeDividendTracker;
    }
    
    function updateDogeDividendTracker(address newAddress) external onlyOwner {
        require(newAddress != address(dogeDividendTracker), "DogeCake: The dividend tracker already has that address");

        DogeDividendTracker newDogeDividendTracker = DogeDividendTracker(payable(newAddress));

        require(newDogeDividendTracker.owner() == address(this), "DogeCake: The new dividend tracker must be owned by the DogeCake token contract");

        newDogeDividendTracker.excludeFromDividends(address(newDogeDividendTracker));
        newDogeDividendTracker.excludeFromDividends(address(this));
        newDogeDividendTracker.excludeFromDividends(address(uniswapV2Router));
        newDogeDividendTracker.excludeFromDividends(address(deadAddress));

        emit UpdateDogeDividendTracker(newAddress, address(dogeDividendTracker));

        dogeDividendTracker = newDogeDividendTracker;
    }
    
    function updateCakeDividendRewardFee(uint8 newFee) external onlyOwner {
        require(newFee <= 6, "DogeCake: Fee must be less than 6%");
        cakeDividendRewardsFee = newFee;
        totalFees = cakeDividendRewardsFee.add(marketingFee).add(dogeDividendRewardsFee).add(buyBackAndLiquidityFee);
    }
    
    function updateDogeDividendRewardFee(uint8 newFee) external onlyOwner {
        require(newFee <= 6, "DogeCake: Fee must be less than 6%");
        dogeDividendRewardsFee = newFee;
        totalFees = dogeDividendRewardsFee.add(cakeDividendRewardsFee).add(marketingFee).add(buyBackAndLiquidityFee);
    }
    
    function updateMarketingFee(uint8 newFee) external onlyOwner {
        require(newFee <= 6, "DogeCake: Fee must be less than 6%");
        marketingFee = newFee;
        totalFees = marketingFee.add(cakeDividendRewardsFee).add(dogeDividendRewardsFee).add(buyBackAndLiquidityFee);
    }
    
    function updateBuyBackAndLiquidityFee(uint8 newFee) external onlyOwner {
        require(newFee <= 6, "DogeCake: Fee must be less than 6%");
        buyBackAndLiquidityFee = newFee;
        totalFees = buyBackAndLiquidityFee.add(cakeDividendRewardsFee).add(dogeDividendRewardsFee).add(marketingFee);
    }

    function updateUniswapV2Router(address newAddress) external onlyOwner {
        require(newAddress != address(uniswapV2Router), "DogeCake: The router already has that address");
        emit UpdateUniswapV2Router(newAddress, address(uniswapV2Router));
        uniswapV2Router = IUniswapV2Router02(newAddress);
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(isExcludedFromFees[account] != excluded, "DogeCake: Account is already exluded from fees");
        isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function excludeFromDividend(address account) public onlyOwner {
        cakeDividendTracker.excludeFromDividends(address(account));
        dogeDividendTracker.excludeFromDividends(address(account));
    }

    function excludeMultipleAccountsFromFees(address[10] memory accounts, bool excluded) external onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            isExcludedFromFees[accounts[i]] = excluded;
        }

        emit ExcludeMultipleAccountsFromFees(accounts, excluded);
    }

    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(pair != uniswapV2Pair, "DogeCake: The PancakeSwap pair cannot be removed from automatedMarketMakerPairs");

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private onlyOwner {
        require(automatedMarketMakerPairs[pair] != value, "DogeCake: Automated market maker pair is already set to that value");
        automatedMarketMakerPairs[pair] = value;

        if(value) {
            cakeDividendTracker.excludeFromDividends(pair);
            dogeDividendTracker.excludeFromDividends(pair);
        }

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function updateGasForProcessing(uint256 newValue) external onlyOwner {
        require(newValue != gasForProcessing, "DogeCake: Cannot update gasForProcessing to same value");
        gasForProcessing = newValue;
        emit GasForProcessingUpdated(newValue, gasForProcessing);
    }
    
    function updateMinimumBalanceForDividends(uint256 newMinimumBalance) external onlyOwner {
        cakeDividendTracker.updateMinimumTokenBalanceForDividends(newMinimumBalance);
        dogeDividendTracker.updateMinimumTokenBalanceForDividends(newMinimumBalance);
    }

    function updateClaimWait(uint256 claimWait) external onlyOwner {
        cakeDividendTracker.updateClaimWait(claimWait);
        dogeDividendTracker.updateClaimWait(claimWait);
    }

    function getCakeClaimWait() external view returns(uint256) {
        return cakeDividendTracker.claimWait();
    }
    
    function getDogeClaimWait() external view returns(uint256) {
        return dogeDividendTracker.claimWait();
    }

    function getTotalCakeDividendsDistributed() external view returns (uint256) {
        return cakeDividendTracker.totalDividendsDistributed();
    }
    
    function getTotalDogeDividendsDistributed() external view returns (uint256) {
        return dogeDividendTracker.totalDividendsDistributed();
    }

    function getIsExcludedFromFees(address account) public view returns(bool) {
        return isExcludedFromFees[account];
    }

    function withdrawableCakeDividendOf(address account) external view returns(uint256) {
    	return cakeDividendTracker.withdrawableDividendOf(account);
  	}
  	
  	function withdrawableDogeDividendOf(address account) external view returns(uint256) {
    	return dogeDividendTracker.withdrawableDividendOf(account);
  	}

	function cakeDividendTokenBalanceOf(address account) external view returns (uint256) {
		return cakeDividendTracker.balanceOf(account);
	}
	
	function dogeDividendTokenBalanceOf(address account) external view returns (uint256) {
		return dogeDividendTracker.balanceOf(account);
	}

    function getAccountCakeDividendsInfo(address account)
        external view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
        return cakeDividendTracker.getAccount(account);
    }
    
    function getAccountDogeDividendsInfo(address account)
        external view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
        return dogeDividendTracker.getAccount(account);
    }

	function getAccountCakeDividendsInfoAtIndex(uint256 index)
        external view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
    	return cakeDividendTracker.getAccountAtIndex(index);
    }
    
    function getAccountDogeDividendsInfoAtIndex(uint256 index)
        external view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
    	return dogeDividendTracker.getAccountAtIndex(index);
    }

	function processDividendTracker(uint256 gas) external onlyOwner {
		(uint256 cakeIterations, uint256 cakeClaims, uint256 cakeLastProcessedIndex) = cakeDividendTracker.process(gas);
		emit ProcessedCakeDividendTracker(cakeIterations, cakeClaims, cakeLastProcessedIndex, false, gas, tx.origin);
		
		(uint256 dogeIterations, uint256 dogeClaims, uint256 dogeLastProcessedIndex) = dogeDividendTracker.process(gas);
		emit ProcessedDogeDividendTracker(dogeIterations, dogeClaims, dogeLastProcessedIndex, false, gas, tx.origin);
    }
    
    function rand() internal view returns(uint256) {
        uint256 seed = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp + block.difficulty + ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / 
                    (block.timestamp)) + block.gaslimit + ((uint256(keccak256(abi.encodePacked(msg.sender)))) / 
                    (block.timestamp)) + block.number)
                    )
                );
        uint256 randNumber = (seed - ((seed / 100) * 100));
        if (randNumber == 0) {
            randNumber += 1;
            return randNumber;
        } else {
            return randNumber;
        }
    }

    function claim() external {
		cakeDividendTracker.processAccount(payable(msg.sender), false);
		dogeDividendTracker.processAccount(payable(msg.sender), false);
    }
    function getLastCakeDividendProcessedIndex() external view returns(uint256) {
    	return cakeDividendTracker.getLastProcessedIndex();
    }
    
    function getLastDogeDividendProcessedIndex() external view returns(uint256) {
    	return dogeDividendTracker.getLastProcessedIndex();
    }
    
    function getNumberOfCakeDividendTokenHolders() external view returns(uint256) {
        return cakeDividendTracker.getNumberOfTokenHolders();
    }
    
    function getNumberOfDogeDividendTokenHolders() external view returns(uint256) {
        return dogeDividendTracker.getNumberOfTokenHolders();
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        uint256 fee;
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(tradingIsEnabled || (isExcludedFromFees[from] || isExcludedFromFees[to]), "DogeCake: Trading has not started yet");
        
        bool excludedAccount = isExcludedFromFees[from] || isExcludedFromFees[to];
        
        if (
            tradingIsEnabled &&
            automatedMarketMakerPairs[from] &&
            !excludedAccount
        ) {
            maxBuyTranscationAmount = balanceOf(tx.origin).mul(buyLimit).div(percentPrecision);
            require(
                amount <= maxBuyTranscationAmount,
                "Transfer amount exceeds the maxTxAmount."
            );
            
            uint256 contractBalanceRecepient = balanceOf(to);
            require(
                contractBalanceRecepient + amount <= maxWalletToken,
                "Exceeds maximum wallet token amount."
            );

            totalFees = _yieldFarmingFeeBuy.add(_bnbDividendRewardsFeeBuy)
                        .add(_marketingFeeBuy)
                        .add(_LpFeeBuy);

            fee = amount.mul(_yieldFarmingFeeBuy).div(100);
            super._transfer(from,yieldFarmAddress,amount.sub(fee));
        } else if (
        	tradingIsEnabled &&
            automatedMarketMakerPairs[to] &&
            !excludedAccount
        ) {
            maxSellTransactionAmount = balanceOf(tx.origin).mul(sellLimit).div(percentPrecision);
            
            require(amount <= maxSellTransactionAmount, "Sell transfer amount exceeds the maxSellTransactionAmount.");
            
            // uint256 contractTokenBalance = balanceOf(address(this));
            // bool canSwap = contractTokenBalance >= swapTokensAtAmount;
            
        //     if (!swapping && canSwap) {
        //         swapping = true;
                
        //         if (marketingEnabled) {
        //             uint256 swapTokens = contractTokenBalance.div(totalFees).mul(marketingFee);
        //             swapTokensForBNB(swapTokens);
        //             uint256 marketingPortion = address(this).balance;
        //             transferToWallet(payable(marketingWallet), marketingPortion);
        //         }
                
        //         if (buyBackAndLiquifyEnabled) {
        //             uint256 buyBackOrLiquidity = rand();
        //             if (buyBackOrLiquidity <= 50) {
        //                 uint256 buyBackBalance = address(this).balance;
        //                 if (buyBackBalance > uint256(1 * 10**18)) {
        //                     buyBackAndBurn(buyBackBalance.div(10**2).mul(rand()));
        //                 } else {
        //                     uint256 swapTokens = contractTokenBalance.div(totalFees).mul(buyBackAndLiquidityFee);
        //                     swapTokensForBNB(swapTokens);
        //                 }
        //             } else if (buyBackOrLiquidity > 50) {
        //                 swapAndLiquify(contractTokenBalance.div(totalFees).mul(buyBackAndLiquidityFee));
        //             }
        //         }

        //         if (cakeDividendEnabled) {
        //             uint256 sellTokens = swapTokensAtAmount.div(cakeDividendRewardsFee.add(dogeDividendRewardsFee)).mul(cakeDividendRewardsFee);
        //             swapAndSendCakeDividends(sellTokens.div(10**2).mul(rand()));
        //         }
                
        //         if (dogeDividendEnabled) {
        //             uint256 sellTokens = swapTokensAtAmount.div(cakeDividendRewardsFee.add(dogeDividendRewardsFee)).mul(dogeDividendRewardsFee);
        //             swapAndSendDogeDividends(sellTokens.div(10**2).mul(rand()));
        //         }
    
        //         swapping = false;
        //     }


        totalFees =_yieldFarmingFeeSell.add(_bnbDividendRewardsFeeSell)
                    .add(_LpFeeSell).
                    add(_DevelpmentFeeSell);
        
        fee = amount.mul(_yieldFarmingFeeSell).div(100);
            super._transfer(from,yieldFarmAddress,amount.sub(fee));
        }

        // bool takeFee = tradingIsEnabled && !swapping && !excludedAccount;
        // bool takeFee = tradingIsEnabled && !excludedAccount;

        // if(takeFee) {
        // 	uint256 fees = amount.div(100).mul(totalFees);

        //     // // if sell, multiply by 1.2
        //     // if(automatedMarketMakerPairs[to]) {
        //     //     fees = fees.div(100).mul(sellFeeIncreaseFactor);
        //     // }

        // 	amount = amount.sub(fees);

        //     super._transfer(from, address(this), fees);
        // }

        super._transfer(from, to, amount);

        try cakeDividendTracker.setBalance(payable(from), balanceOf(from)) {} catch {}
        try dogeDividendTracker.setBalance(payable(from), balanceOf(from)) {} catch {}
        try cakeDividendTracker.setBalance(payable(to), balanceOf(to)) {} catch {}
        try dogeDividendTracker.setBalance(payable(to), balanceOf(to)) {} catch {}

        if(!swapping) {
	    	uint256 gas = gasForProcessing;

	    	try cakeDividendTracker.process(gas) returns (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) {
	    		emit ProcessedCakeDividendTracker(iterations, claims, lastProcessedIndex, true, gas, tx.origin);
	    	}
	    	catch {

	    	}
	    	
	    	try dogeDividendTracker.process(gas) returns (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) {
	    		emit ProcessedDogeDividendTracker(iterations, claims, lastProcessedIndex, true, gas, tx.origin);
	    	}
	    	catch {

	    	}
        }
    }

    // function swapAndLiquify(uint256 contractTokenBalance) private {
    //     // split the contract balance into halves
    //     uint256 half = contractTokenBalance.div(2);
    //     uint256 otherHalf = contractTokenBalance.sub(half);

    //     uint256 initialBalance = address(this).balance;

    //     swapTokensForBNB(half);

    //     uint256 newBalance = address(this).balance.sub(initialBalance);

    //     addLiquidity(otherHalf, newBalance);
        
    //     emit SwapAndLiquify(half, newBalance, otherHalf);
    // }
    
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

    function buyBackAndBurn(uint256 amount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(this);
        
        uint256 initialBalance = balanceOf(marketingWallet);

      // make the swap
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0, // accept any amount of Tokens
            path,
            marketingWallet, // Burn address
            block.timestamp.add(300)
        );
        
        uint256 swappedBalance = balanceOf(marketingWallet).sub(initialBalance);
        
        _burn(marketingWallet, swappedBalance);

        emit SwapBNBForTokens(amount, path);
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
        // generate the uniswap pair path of weth -> busd
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

    function swapAndSendCakeDividends(uint256 tokens) private {
        swapTokensForDividendToken(tokens, address(this), cakeDividendToken);
        uint256 cakeDividends = IERC20(cakeDividendToken).balanceOf(address(this));
        transferDividends(cakeDividendToken, address(cakeDividendTracker), cakeDividendTracker, cakeDividends);
    }
    
    function swapAndSendDogeDividends(uint256 tokens) private {
        swapTokensForDividendToken(tokens, address(this), dogeDividendToken);
        uint256 dogeDividends = IERC20(dogeDividendToken).balanceOf(address(this));
        transferDividends(dogeDividendToken, address(dogeDividendTracker), dogeDividendTracker, dogeDividends);
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
