/*

-----------------------------------------------------------------
FILE INFORMATION
-----------------------------------------------------------------

file:       SafeDecimalMath.sol
version:    2.0
author:     Kevin Brown
            Gavin Conway
date:       2018-10-18

-----------------------------------------------------------------
MODULE DESCRIPTION
-----------------------------------------------------------------

A library providing safe mathematical operations for division and
multiplication with the capability to round or truncate the results
to the nearest increment. Operations can return a standard precision
or high precision decimal. High precision decimals are useful for
example when attempting to calculate percentages or fractions
accurately.

-----------------------------------------------------------------
*/

pragma solidity 0.5.12;

import "SafeMath.sol";


/**
 * @title Safely manipulate unsigned fixed-point decimals at a given precision level.
 * @dev Functions accepting uints in this contract and derived contracts
 * are taken to be such fixed point decimals of a specified precision (either standard
 * or high).
 */



 // OZ TODO: exponentiation can overflow
 // OZ TODO: obvs implement safemath where needed
library SafeDecimalMath {
    using SafeMath for uint;

    uint256 private constant MAX = uint256(-1);

    /* Number of decimal places in the representations. */
    uint256 public constant standardDecimalPrecision = 18;

    /* maximum precision of any uint256 */
    /* uint256 max value is roughly 1.15e77 */
    uint256 public constant maxPrecisionPossible = 77;

    /* The number representing 1.0. */
    uint256 public constant UNIT = 10**uint(standardDecimalPrecision);

    /* Creates new "type" to avoid confusing regular uint256's and standard decimals */
    struct StandardDecimal{
        uint256 value;
    }

    /** 
     * @return Provides an interface to UNIT.
     */
    function unit() external pure returns (uint) {
        return UNIT;
    }


    /**
     * @return The result of multiplying x and y, interpreting the operands as fixed-point
     * decimals.
     * 
     * @dev A unit factor is divided out after the product of x and y is evaluated,
     * so that product must be less than 2**256. As this is an integer division,
     * the internal division always rounds down. This helps save on gas. Rounding
     * is more expensive on gas.
     */
    function _multiplyStandardDecimals(StandardDecimal memory x, StandardDecimal memory y) internal pure returns (StandardDecimal memory) {
        /* Divide by UNIT to remove the extra factor introduced by the product. */
        return StandardDecimal(x.value.mul(y.value) / UNIT);
    }


// OZ TODO: consider changing "precisions" to uint8's to prevent crazy high numbers. 
//  |-> counterpoint: if you want 1e-1000 precision, you could and should theoretically be able to do math on that (but maybe not in this version)
    function multiplyVariablePrecisionDecimals(uint256 x, uint256 y, uint256 xPrecision, uint256 yPrecision, uint256 desiredPrecision) internal pure returns (uint256) {
// OZ TODO: determine how to calculate precision for passing into this function
        require(xPrecision <= maxPrecisionPossible, "xPrecision too high");
        require(yPrecision <= maxPrecisionPossible, "yPrecision too high");
        require(desiredPrecision <= maxPrecisionPossible, "desiredPrecision too high");
        
        uint256 resultingPrecision = xPrecision + yPrecision;

        uint256 rawResult = x.mul(y);

        if (resultingPrecision == desiredPrecision) {
            return rawResult;
        }
        else if(resultingPrecision > desiredPrecision) {
            uint256 quotientTimesTen = rawResult / (10 ** (resultingPrecision - desiredPrecision) / 10);

            if(quotientTimesTen % 10 >= 5) {
                quotientTimesTen += 10;
            }

            return (quotientTimesTen / 10);
        }
        else /* resultingPrecision < desiredPrecision */ {
// OZ TODO: check exponentiation for overflows
            return rawResult * (10 ** (desiredPrecision - resultingPrecision));            
        }
    }


// OZ TODO: migrate these comments to multiplyVariablePrecisionDecimals
// This function has been deprecated in favor of more versatile multiplyVariablePrecisionDecimals()
    /**
     * @return The result of safely multiplying x and y, interpreting the operands
     * as fixed-point decimals of a precise unit.
     *
     * @dev The operands should be in the precise unit factor which will be
     * divided out after the product of x and y is evaluated, so that product must be
     * less than 2**256.
     *
     * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
     * Rounding is useful when you need to retain fidelity for small decimal numbers
     * (eg. small fractions or percentages).
     */
//    function multiplyDecimalRoundPrecise(PreciseDecimal memory x, PreciseDecimal memory y) internal pure returns (uint) {
//        return _multiplyDecimalRound(x.value, y.value, PRECISE_UNIT);
//    }

    /**
     * @return The result of safely multiplying x and y, interpreting the operands
     * as fixed-point decimals of a standard unit.
     *
     * @dev The operands should be in the standard unit factor which will be
     * divided out after the product of x and y is evaluated, so that product must be
     * less than 2**256.
     *
     * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
     * Rounding is useful when you need to retain fidelity for small decimal numbers
     * (eg. small fractions or percentages).
     */
    function multiplyStandardDecimalRound(StandardDecimal memory x, StandardDecimal memory y) internal pure returns (uint) {
        return _multiplyDecimalRound(x.value, y.value, standardDecimalPrecision);
    }

    /**
     * @return The result of safely dividing x and y. The return value is a high
     * precision decimal.
     * 
     * @dev y is divided after the product of x and the standard precision unit
     * is evaluated, so the product of x and UNIT must be less than 2**256. As
     * this is an integer division, the result is always rounded down.
     * This helps save on gas. Rounding is more expensive on gas.
     */
    function divideStandardDecimal(StandardDecimal memory x, StandardDecimal memory y) internal pure returns (uint) {
        /* Reintroduce the UNIT factor that will be divided out by y. */
        return x.value.mul(UNIT).div(y.value);
    }

    /**
     * @return The result of safely dividing x and y. The return value is as a rounded
     * standard precision decimal.
     *
     * @dev y is divided after the product of x and the standard precision unit
     * is evaluated, so the product of x and the standard precision unit must
     * be less than 2**256. The result is rounded to the nearest increment.
     */
    function divideStandardDecimalRound(StandardDecimal memory x, StandardDecimal memory y) internal pure returns (uint) {
        return _divideDecimalRound(x.value, y.value, UNIT);
    }


// OZ TODO: implement a new function that will convert from one precision to the other
// OZ TODO: change comments to reflect final funcitonaliy
// OZ TODO: check style guidelines for solidity to see if this matches
// OZ TODO: check for overflow, especially when doing exponentiation
    /**
     * @dev Convert a standard decimal representation to a high precision one.
     */
    function standardPrecisionToCustom(StandardDecimal memory i, uint256 desiredPrecision) internal pure returns (uint256) {
        if(desiredPrecision == standardDecimalPrecision) {
            return i.value;
        }
        else if(desiredPrecision < standardDecimalPrecision) {
// OZ TODO: make a better error message
            require(standardDecimalPrecision - desiredPrecision <= maxPrecisionPossible, "Overflow due to too high precision");

            uint256 quotientTimesTen = i.value / (10 ** (standardDecimalPrecision - desiredPrecision) / 10);

            if (quotientTimesTen % 10 >= 5) {
                quotientTimesTen += 10;
            }

            return(quotientTimesTen / 10);            
        }
        else /* if desiredPrecision > standardDecimalPrecision */ {
            return(i.value * (10 ** (desiredPrecision - standardDecimalPrecision)));
        }
    }


// OZ TODO: natspec
// OZ TODO: exponentiation can overflow here
    function customPrecisionToStandard(uint256 value, uint256 precisionOfInput) internal pure returns (StandardDecimal memory) {
        if(precisionOfInput == standardDecimalPrecision) {
            return StandardDecimal(value);
        }
        else if(precisionOfInput < standardDecimalPrecision) {
            return StandardDecimal(value * (10 ** (standardDecimalPrecision - precisionOfInput)));
        }
        else /* if precisionOfInput > standardDecimalPrecision */ {
            uint256 quotientTimesTen = value / (10 ** (precisionOfInput - standardDecimalPrecision) / 10);

            if (quotientTimesTen % 10 >= 5) {
                quotientTimesTen += 10;
            }

            return StandardDecimal(quotientTimesTen / 10);
        }
    }

    /**
     * @return The result of safely multiplying x and y, interpreting the operands
     * as fixed-point decimals of the specified precision unit.
     *
     * @dev The operands should be in the form of a the specified unit factor which will be
     * divided out after the product of x and y is evaluated, so that product must be
     * less than 2**256.
     *
     * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
     * Rounding is useful when you need to retain fidelity for small decimal numbers
     * (eg. small fractions or percentages).
     */
// OZ TODO: change comments to reflect that desiredPrecision is now JUST the exponent (AKA, for 1e18, it's just 18, not 1e18)
    function _multiplyDecimalRound(uint x, uint y, uint precisionReductionFactor) private pure returns (uint) {
// OZ TODO: sanitize input on precisionReductionFactor to avoid overflows. verify that precisionReductionFactor == 0 works
        /* resulting precision will be (xPrecision + yPrecision). It can be optionally reduced by precisionReductionFactor number of digits */
        uint quotientTimesTen = x.mul(y) / ((10 ** precisionReductionFactor) / 10);

        if (quotientTimesTen % 10 >= 5) {
            quotientTimesTen += 10;
        }

        return quotientTimesTen / 10;
    }

    /**
     * @return The result of safely dividing x and y. The return value is as a rounded
     * decimal in the precision unit specified in the parameter.
     *
     * @dev y is divided after the product of x and the specified precision unit
     * is evaluated, so the product of x and the specified precision unit must
     * be less than 2**256. The result is rounded to the nearest increment.
     */
    function _divideDecimalRound(uint x, uint y, uint precisionUnit) private pure returns (uint) {
        uint resultTimesTen = x.mul(precisionUnit * 10).div(y);

        if (resultTimesTen % 10 >= 5) {
            resultTimesTen += 10;
        }

        return resultTimesTen / 10;
    }

    function exponentiationWillNotOverflow(uint x, uint e) private pure returns (bool) {

        uint256 factor = MAX / x;   //determine the max multiplier of x before the result overflows

        return(factor >= 10 ** e);  //if factor >= 10^e, it means x can safeley be multiplied by 10^e
    }
}
