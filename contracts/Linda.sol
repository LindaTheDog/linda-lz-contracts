// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 ___        __    _____  ___   ________       __      
|"  |      |" \  (\"   \|"  \ |"      "\     /""\     
||  |      ||  | |.\\   \    |(.  ___  :)   /    \    
|:  |      |:  | |: \.   \\  ||: \   ) ||  /' /\  \   
 \  |___   |.  | |.  \    \. |(| (___\ || //  __'  \  
( \_|:  \  /\  |\|    \    \ ||:       :)/   /  \\  \ 
 \_______)(__\_|_)\___|\____\)(________/(___/    \___)


Website:  https://lindathedog.com
Telegram: https://t.me/LindaCommunity
*/


import "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IFeeSharing.sol";

contract Linda is OFT {

    uint256 public constant FEE_BASIS_DENOMINATOR = 10000;

    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) private automatedMarketMakerPairs;

    IUniswapV2Router02 private uniswapV2Router;
    address private _routeWETH;
    bool private inSwap;
    bool private swapEnabled;
    uint256 private ethNativeType; 

    address public lindaPool;
    address public liquidityWallet;
    address public developmentWallet;
    address public burnWallet;

    bool public isLimited;
    uint256 public maxWallet;
    uint256 public distributeThreshold;
    
    uint256 public buyTotalFees;
    uint256 private buyBurningFee;
    uint256 private buyDevelopmentFee;
    uint256 private buyLiquidityFee;

    uint256 public sellTotalFees;
    uint256 private sellBurningFee;
    uint256 private sellDevelopmentFee;
    uint256 private sellLiquidityFee;

    uint256 private tokensForBurning;
    uint256 private tokensForDevelopment;
    uint256 private tokensForLiquidity;

    uint256 public bridgeInFee;
    uint256 public bridgeOutFee;

    event DistributedTokens(uint256 burn, uint256 liquidity, uint256 dev);
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event BurnWalletUpdated(address indexed newWallet, address indexed oldWallet);
    event DevelopmentWalletUpdated(address indexed newWallet, address indexed oldWallet);
    event LiquidityWalletUpdated(address indexed newWallet, address indexed oldWallet);
    event MaxWalletUpdated(bool isLimited, uint256 maxAmount);
    event SwapAndLiquify(uint256 amountToSwap, uint256 ethLiquidity, uint256 tokenLiquidity);
    event BridgeInFeeUpdated(uint256 newFee, uint256 priorFee);
    event BridgeOutFeeUpdated(uint256 newFee, uint256 priorFee);

    constructor(
        address _lzEndpoint,
        address _owner
    ) OFT("Linda", "LINDA", _lzEndpoint, _owner) {
        // Register this contract in initial setup
        IFeeSharing(0x8680CEaBcb9b56913c519c069Add6Bc3494B7020).register(msg.sender); 

        excludeFromFees(_msgSender(), true);
        excludeFromFees(address(this), true);
    }

    receive() external payable {}

    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    /**
     * @dev either manually add pool address OR use router input to create pair
     * @param _pool (optional) manual add address of pool pair
     * @param _router address of DEX router 
     * @param _weth the native wrapper contract for ether
     * @param _nativeType indication if eth is native token (1 = native, 2 = non-native) 
     * @param _ethAmount the ether amount to add on initial liquidity
     */
    function lindaGoesOmni(
        address _pool, 
        address _router, 
        address _weth, 
        uint256 _nativeType, 
        uint256 _ethAmount
    ) external onlyOwner {
        if (_pool == address(0)) {
            initPool(_router, _weth, _nativeType, _ethAmount);
        } else {
            lindaPool = _pool;
            _setAutomatedMarketMakerPair(_pool, true);
            swapEnabled = false;
        }
    }

    function setThreshold(uint256 newAmount) external onlyOwner returns (bool) {
        require(newAmount >= (totalSupply() * 1) / 100000, "Threshold floor cannot be lower than 0.001% total supply");
        require(newAmount <= (totalSupply() * 2) / 100, "Threshold ceiling cannot be higher than 2.000% total supply");
        distributeThreshold = newAmount;
        return true;
    }

    function setMaxWallet(bool _limited, uint256 _maxWalletAmount) external onlyOwner {
        require(_maxWalletAmount >= (totalSupply() * 5) / 1000, "Invalid amount: cannot set max lower than 0.5% of total supply");
        isLimited = _limited;
        maxWallet = _maxWalletAmount;
        emit MaxWalletUpdated(_limited, _maxWalletAmount);
    }

    function setBurnWallet(address _burnWallet) external onlyOwner {
        require(_burnWallet != address(0), "Invalid Address: must be non-zero address");
        address oldWallet = burnWallet;
        burnWallet = _burnWallet;
        emit BurnWalletUpdated(burnWallet, oldWallet);
    }

    function setDevelopmentWallet(address _developmentWallet) external onlyOwner {
        require(_developmentWallet != address(0), "Invalid Address: must be non-zero address");
        address oldWallet = developmentWallet;
        developmentWallet = _developmentWallet;
        emit DevelopmentWalletUpdated(developmentWallet, oldWallet);
    }

    function setLiquidityWallet(address _liquidityWallet) external onlyOwner {
        require(_liquidityWallet != address(0), "Invalid Address: must be non-zero address");
        address oldWallet = liquidityWallet;
        liquidityWallet = _liquidityWallet;
        emit LiquidityWalletUpdated(liquidityWallet, oldWallet);
    }

    function setSwapBackSettings(bool _enabled) external onlyOwner {
        swapEnabled = _enabled;
    }

    function initPool(address _router, address _weth, uint256 _nativeType, uint256 _ethAmount) internal {
        uniswapV2Router = IUniswapV2Router02(_router);
        _approve(address(this), address(uniswapV2Router), type(uint).max);
        _routeWETH = _weth;
        ethNativeType = _nativeType;
        
        // native is ETH
        if (_nativeType == 1 && _weth == uniswapV2Router.WETH()) {
            lindaPool = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
            uniswapV2Router.addLiquidityETH{value: address(this).balance}(address(this),balanceOf(address(this)),0,0,owner(),block.timestamp);
            _setAutomatedMarketMakerPair(lindaPool, true);
            swapEnabled = true;
        }

        // non-native
        if (_nativeType == 2) {
            lindaPool = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), _weth);

            IERC20(_weth).approve(address(uniswapV2Router), _ethAmount);

            uniswapV2Router.addLiquidity(
                address(this),
                _weth,
                balanceOf(address(this)),
                _ethAmount,
                0,
                0,
                owner(),
                block.timestamp
            );
            _setAutomatedMarketMakerPair(lindaPool, true);
            swapEnabled = true;
        }        
    }

    function setBuyFees(
        uint256 _liquidityFee,
        uint256 _devFee,
        uint256 _burnFee
    ) external onlyOwner {
        require(_liquidityFee + _devFee + _burnFee <= 100, "Fees are capped at 1%");
        buyLiquidityFee = _liquidityFee;
        buyDevelopmentFee = _devFee;
        buyBurningFee = _burnFee;
        buyTotalFees = _liquidityFee + _devFee + _burnFee;
    }

    function setSellFees(
        uint256 _liquidityFee,
        uint256 _devFee,
        uint256 _burnFee
    ) external onlyOwner {
        require(_liquidityFee + _devFee + _burnFee <= 100, "Fees are capped at 1%");
        sellLiquidityFee = _liquidityFee;
        sellDevelopmentFee = _devFee;
        sellBurningFee = _burnFee;
        sellTotalFees = _liquidityFee + _devFee + _burnFee;
    }

    function manualDistribute() external {
        _distributeTokens();
    }

    function setBridgeInFee(uint256 _amount) external onlyOwner {
        require(_amount <= 10, "Invalid: over max limit of 0.10%");
        emit BridgeInFeeUpdated(_amount, bridgeInFee);
        bridgeInFee = _amount;
    }

    function setBridgeOutFee(uint256 _amount) external onlyOwner {
        require(_amount <= 30, "Invalid: over max limit of 0.30%");
        emit BridgeOutFeeUpdated(_amount, bridgeOutFee);
        bridgeOutFee = _amount;
    }

    function setAMMPair(address _pair, bool _value) external onlyOwner {
        _setAutomatedMarketMakerPair(_pair, _value);
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        return _lindaTransfer(_msgSender(), to, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(sender, spender, amount);
        return _lindaTransfer(sender, recipient, amount);
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function _lindaTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        if (inSwap || amount == 0) {
            _transfer(sender, recipient, amount);
            return true;
        }

        if (isLimited && automatedMarketMakerPairs[sender]) {
            require(balanceOf(recipient) + amount <= maxWallet, "Limit enabled: exceeds max wallet amount");
        }

        if (shouldSwapBack()) {
            swapBack();
        } else if (!swapEnabled && balanceOf(address(this)) >= distributeThreshold && !automatedMarketMakerPairs[sender]) {
            _distributeTokens();
        }

        bool shouldTakeFee = (!_isExcludedFromFees[sender] && !_isExcludedFromFees[recipient]);
        uint256 fees = 0;

        if (shouldTakeFee) {
            if (automatedMarketMakerPairs[sender] && buyTotalFees > 0) {
                fees = (amount * buyTotalFees) / FEE_BASIS_DENOMINATOR;
                tokensForLiquidity += (fees * buyLiquidityFee) / buyTotalFees;
                tokensForBurning += (fees * buyBurningFee) / buyTotalFees;
                tokensForDevelopment += (fees * buyDevelopmentFee) / buyTotalFees;
            } else if (automatedMarketMakerPairs[recipient] && sellTotalFees > 0) {
                fees = (amount * sellTotalFees) / FEE_BASIS_DENOMINATOR;
                tokensForLiquidity += (fees * sellLiquidityFee) / sellTotalFees;
                tokensForBurning += (fees * sellBurningFee) / sellTotalFees;
                tokensForDevelopment += (fees * sellDevelopmentFee) / sellTotalFees;
            } else {
                fees = buyTotalFees < sellTotalFees ? amount * (buyTotalFees / 2) / FEE_BASIS_DENOMINATOR : amount * (sellTotalFees / 2) / FEE_BASIS_DENOMINATOR;
                
                if (fees > 0) {tokensForLiquidity += fees;}
            }
            if (fees > 0) {
                _transfer(sender, address(this), fees);
            }
            amount -= fees;
        }

        _transfer(sender, recipient, amount);
        return true;
    }

    function shouldSwapBack() internal view returns (bool) {
        return !inSwap && swapEnabled && balanceOf(address(this)) >= distributeThreshold && !automatedMarketMakerPairs[_msgSender()];
    }

    function swapBack() internal swapping {
        _transfer(address(this), burnWallet, tokensForBurning);
        uint256 contractBalance = balanceOf(address(this));
        uint256 totalTokensToSwap = tokensForLiquidity + tokensForDevelopment;
        uint256 liquidityPortion = (contractBalance * tokensForLiquidity) / totalTokensToSwap;
        uint256 liquidityTokens = liquidityPortion / 2;
        uint256 amountToSwapForETH = contractBalance - liquidityTokens;
        uint256 initialETHBalance = address(this).balance;
        if (ethNativeType == 2) {
            initialETHBalance = IERC20(_routeWETH).balanceOf(address(this));
        }
        bool success;
        _swapTokensForETH(amountToSwapForETH);

        uint256 ethBalance;
        if (ethNativeType == 1) {
            ethBalance = address(this).balance - initialETHBalance;
        } else if (ethNativeType == 2) {
            ethBalance = IERC20(_routeWETH).balanceOf(address(this)) - initialETHBalance;
        }
        
        uint256 ethForDevelopment = (ethBalance * tokensForDevelopment) / totalTokensToSwap;
        uint256 ethForLiquidity = ethBalance - ethForDevelopment;

        tokensForBurning = 0;
        tokensForLiquidity = 0;
        tokensForDevelopment = 0;

        if (liquidityTokens > 0 && ethForLiquidity > 0) {
            _addLiquidity(liquidityTokens, ethForLiquidity);
            emit SwapAndLiquify(
                amountToSwapForETH,
                ethForLiquidity,
                liquidityTokens
            );
        }

        if (ethNativeType == 1 && address(this).balance > 0) {
            (success, ) = payable(liquidityWallet).call{value: address(this).balance}("");
        } else if (ethNativeType == 2) {
            uint256 ethDevelopmentAmount = IERC20(_routeWETH).balanceOf(address(this));
            IERC20(_routeWETH).transfer(developmentWallet, ethDevelopmentAmount);
        }
    }

    function _swapTokensForETH(uint256 tokenAmount) internal {
        if (ethNativeType == 1) {
            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = uniswapV2Router.WETH();
            _approve(address(this), address(uniswapV2Router), tokenAmount);
            uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                tokenAmount,
                0,
                path,
                address(this),
                block.timestamp
            );
        } else if (ethNativeType == 2) {
            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = _routeWETH;
            _approve(address(this), address(uniswapV2Router), tokenAmount);
            uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                tokenAmount,
                0,
                path,
                address(this),
                block.timestamp
            );
        }
    }

    function _addLiquidity(uint256 tokenAmount, uint256 ethAmount) internal {
        if (ethNativeType == 1) {
            _approve(address(this), address(uniswapV2Router), tokenAmount);
            uniswapV2Router.addLiquidityETH{value: ethAmount}(
                address(this),
                tokenAmount,
                0,
                0,
                liquidityWallet,
                block.timestamp
            );
        } else if (ethNativeType == 2) {
            _approve(address(this), address(uniswapV2Router), tokenAmount);
            IERC20(_routeWETH).approve(address(uniswapV2Router), ethAmount);
            uniswapV2Router.addLiquidity(
                address(this),
                _routeWETH,
                tokenAmount,
                ethAmount,
                0,
                0,
                liquidityWallet,
                block.timestamp
            );
        }
    }

    function _distributeTokens() internal {
        _transfer(address(this), burnWallet, tokensForBurning);
        _transfer(address(this), liquidityWallet, tokensForLiquidity);
        _transfer(address(this), developmentWallet, tokensForDevelopment);

        emit DistributedTokens(tokensForBurning, tokensForLiquidity, tokensForDevelopment);

        tokensForBurning = 0;
        tokensForLiquidity = 0;
        tokensForDevelopment = 0;

        if (address(this).balance > 0) {
            bool success;
            (success, ) = payable(liquidityWallet).call{value: address(this).balance}("");
        }
    }

    function _debit(
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 _dstEid
    ) internal override returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        (amountSentLD, amountReceivedLD) = _debitView(_amountLD, _minAmountLD, _dstEid);

        uint256 reserves = amountSentLD > amountReceivedLD ? amountSentLD - amountReceivedLD : 0;
        if(reserves > 0) {
            _transfer(msg.sender, liquidityWallet, reserves);
            _burn(msg.sender, amountReceivedLD);
        } else {
            _burn(msg.sender, amountSentLD);
        }
    }

    function _debitView(
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 /*_dstEid*/
    ) internal view override returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        amountSentLD = _removeDust(_amountLD);

        uint256 bridgeFee = 0;
        if (bridgeOutFee > 0) {
            bridgeFee = amountSentLD * bridgeOutFee / FEE_BASIS_DENOMINATOR;
        }

        amountReceivedLD = amountSentLD - bridgeFee;

        if (amountReceivedLD < _minAmountLD) {
            revert SlippageExceeded(amountReceivedLD, _minAmountLD);
        }
    }

    function _credit(
        address _to,
        uint256 _amountLD,
        uint32 /*_srcEid*/
    ) internal override returns (uint256 amountReceivedLD) {
        if (bridgeInFee > 0) {
            uint256 fee = _amountLD * bridgeInFee / FEE_BASIS_DENOMINATOR;
            uint256 amountToCreditLDAfterFee = _amountLD - fee;
            _mint(liquidityWallet, fee);
            _mint(_to, amountToCreditLDAfterFee);
            return amountToCreditLDAfterFee;
        } else {
            _mint(_to, _amountLD);
            return _amountLD;
        }
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;
        emit SetAutomatedMarketMakerPair(pair, value);
    }
}
