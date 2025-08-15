# Advanced Support & Resistance Indicator for MetaTrader 5

## Overview

This is a professional-grade Support and Resistance indicator for MT5 that significantly improves upon the Pine Script sample with advanced features, better accuracy, and comprehensive analysis capabilities.

## Key Improvements Over Pine Script Version

### 1. **Enhanced Detection Algorithm**
- Dynamic pivot point detection with configurable left/right bar parameters
- Zone clustering to merge nearby levels and reduce noise
- Strength calculation based on multiple factors (touches, age, volume, recent testing)

### 2. **Multi-Timeframe Analysis**
- Incorporates higher timeframe S/R levels for stronger confirmation
- Automatically adjusts level strength based on timeframe confluence
- Configurable higher timeframe selection

### 3. **Advanced Volume Analysis**
- Volume oscillator using dual EMA periods
- Volume-confirmed breaks for higher reliability
- Configurable volume thresholds

### 4. **Smart Level Management**
- Automatic level strength calculation (0-100%)
- Dynamic level classification (Strong vs Weak)
- Maximum level limit to prevent chart clutter
- Zone width configuration for better level grouping

### 5. **Visual Enhancements**
- Color-coded levels based on strength
- Break signals with directional arrows
- Wick rejection indicators
- Optional level labels with statistics
- Real-time statistics panel

### 6. **Professional Alert System**
- Multiple alert types (breaks, new levels, touches)
- Push notifications support
- Email alerts capability
- Alert spam prevention

### 7. **Performance Tracking**
- Live statistics panel showing:
  - Active level count
  - Break success rate
  - Total touches
  - Volume oscillator value
- Backtesting statistics for strategy validation

## Installation

1. Copy `SupportResistance.mq5` to your MT5 `Indicators` folder
2. Restart MT5 or refresh the Navigator window
3. Drag the indicator onto your chart
4. Configure settings according to your preferences

## Input Parameters

### Detection Settings
- **Left Bars** (15): Number of bars to the left for pivot detection
- **Right Bars** (15): Number of bars to the right for pivot detection
- **Zone Merge Distance** (0.1%): Minimum distance between levels
- **Min Touches** (2): Minimum touches for a strong level
- **Zone Width** (0.05%): Width of S/R zones

### Volume Analysis
- **Use Volume** (true): Enable volume-based filtering
- **Volume Threshold** (20%): Minimum volume oscillator value for valid signals
- **Volume EMA Short** (5): Short period for volume oscillator
- **Volume EMA Long** (10): Long period for volume oscillator

### Multi-Timeframe
- **Use MTF** (true): Enable multi-timeframe analysis
- **Higher TF** (H4): Higher timeframe to analyze

### Break Detection
- **Show Breaks** (true): Display break signals
- **Require Volume** (true): Volume confirmation for breaks
- **Break Buffer** (0.01%): Buffer zone for break confirmation
- **Show Wicks** (true): Show wick rejection signals

### Visual Settings
- **Strong Resistance Color**: Red
- **Weak Resistance Color**: Light Coral
- **Strong Support Color**: Blue
- **Weak Support Color**: Light Blue
- **Max Levels** (10): Maximum levels to display
- **Show Labels** (true): Display level information
- **Show Statistics** (true): Show statistics panel

### Alert Settings
- **Enable Alerts** (true): Master alert switch
- **Alert Breaks** (true): Alert on level breaks
- **Alert New Levels** (true): Alert on new level formation
- **Alert Touches** (true): Alert on level touches
- **Send Notification** (false): Push notifications to mobile
- **Send Email** (false): Email alerts

## Trading Strategies

### 1. **Breakout Trading**
- Wait for price to break a strong level with volume confirmation
- Enter in the direction of the break
- Use the broken level as stop-loss reference

### 2. **Bounce Trading**
- Look for wick rejections at strong levels
- Enter counter-trend trades at these rejections
- Use tight stops beyond the level

### 3. **Range Trading**
- Trade between strong support and resistance
- Buy at support, sell at resistance
- Exit when opposite level is reached

### 4. **Multi-Timeframe Confluence**
- Focus on levels confirmed by higher timeframe
- These levels have higher probability of holding
- Use for position trading setups

## Level Strength Interpretation

- **0-30%**: Weak level, likely to break
- **30-50%**: Moderate level, use with caution
- **50-70%**: Good level, reliable for trading
- **70-100%**: Strong level, high probability trades

## Statistics Panel

The live statistics panel provides:
- **Active Levels**: Current number of S/R levels
- **Breaks**: Total breaks and success rate
- **Total Touches**: Cumulative level touches
- **Volume Osc**: Current volume oscillator value

## Best Practices

1. **Timeframe Selection**: Works best on H1 and above
2. **Pair Selection**: Major pairs with good liquidity
3. **Confirmation**: Always use additional confirmation (price action, indicators)
4. **Risk Management**: Never risk more than 2% per trade
5. **Review**: Regularly review statistics to optimize settings

## Troubleshooting

### Indicator Not Showing Levels
- Increase the lookback period (Left/Right Bars)
- Reduce Zone Merge Distance
- Check if Max Levels is too low

### Too Many False Breaks
- Increase Volume Threshold
- Enable Require Volume for Breaks
- Increase Break Buffer

### Levels Not Accurate
- Adjust Left/Right Bars for your timeframe
- Fine-tune Zone Merge Distance
- Enable Multi-Timeframe analysis

## Performance Notes

- Optimized for real-time performance
- Minimal CPU usage with smart buffer management
- Automatic cleanup of old objects
- Efficient array operations

## Version History

- **v2.0** - Complete rewrite with advanced features
- **v1.0** - Initial Pine Script port (reference only)

## Support

For questions or feature requests, please refer to the source code comments or contact through the trading platform.

## Disclaimer

This indicator is for educational and informational purposes only. Always perform your own analysis and risk management before trading.