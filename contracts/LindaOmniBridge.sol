// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTAdapter.sol";
import "./interfaces/ILinda.sol";

contract LindaOmniBridge is OFTAdapter {
    using SafeERC20 for IERC20;

    uint256 private constant BASIS_POINTS = 10000;
    uint256 public bridgeInFee;
    uint256 public constant bridgeOutFee = 0;

    event BridgeInFeeUpdated(uint256 newFee, uint256 priorFee);

    constructor(
        address _token, // a deployed, already existing ERC20 token address
        address _lzEndpoint, // local endpoint address
        address _owner // token owner
    ) OFTAdapter(_token, _lzEndpoint, _owner) {
    }

    function _debitView(
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 /*_dstEid*/
    ) internal view override returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        amountSentLD = _removeDust(_amountLD);

        uint256 transferTaxFactor = 0;
        if (!ILinda(address(innerToken)).isExcludedFromFees(msg.sender)) {
            // internal accounting must factor in the 1.5% transfer tax of underlying innerToken LINDA
            transferTaxFactor = amountSentLD * 150 / BASIS_POINTS;
        }

        amountReceivedLD = amountSentLD - transferTaxFactor;

        if (amountReceivedLD < _minAmountLD) {
            revert SlippageExceeded(amountReceivedLD, _minAmountLD);
        }
    }

    function _credit(
        address _to,
        uint256 _amountLD,
        uint32 /*_srcEid*/
    ) internal override returns (uint256 amountReceivedLD) {
        if (bridgeInFee > 0 && !ILinda(address(innerToken)).isExcludedFromFees(_to)) {
            uint256 fee = _amountLD * bridgeInFee / BASIS_POINTS;
            uint256 amountToCreditLDAfterFee = _amountLD - fee;
            innerToken.safeTransfer(owner(), fee);
            innerToken.safeTransfer(_to, amountToCreditLDAfterFee);
            return amountToCreditLDAfterFee;
        } else {
            innerToken.safeTransfer(_to, _amountLD);
            return _amountLD;
        }
    }

    function setBridgeInFee(uint256 _amount) external onlyOwner {
        require(_amount <= 1000, "Invalid: over max limit of 10%");
        emit BridgeInFeeUpdated(_amount, bridgeInFee);
        bridgeInFee = _amount;
    }

}