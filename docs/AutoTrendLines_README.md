# Auto Trend Lines Indicator

## Overview
The Auto Trend Lines indicator automatically identifies and draws trend lines on your MetaTrader 5 charts by connecting pivot highs and lows. It validates trend lines based on multiple touch points and alerts you when price breaks through established trend lines.

## Features
- **Automatic Pivot Detection**: Identifies significant swing highs and lows
- **Multi-Touch Validation**: Validates trend lines based on configurable minimum touch points
- **Dynamic Trend Line Drawing**: Automatically connects pivot points to form trend lines
- **Breakout Detection**: Alerts when price breaks through established trend lines
- **Slope Calculation Methods**: ATR, Standard Deviation, or Linear Regression based slope adjustment
- **Visual Customization**: Configurable colors, line styles, and widths
- **Extended Lines**: Option to project trend lines into the future
- **Real-time Updates**: Continuously updates as new price data arrives

## Installation
1. Copy `AutoTrendLines.mq5` to your MetaTrader 5 `Indicators` folder
2. Restart MetaTrader 5 or refresh the Navigator panel
3. Drag the indicator onto your chart

## Parameters

### Detection Settings
- **Swing Detection Lookback** (14): Number of bars to look back for pivot identification
- **Minimum Touch Points** (3): Minimum number of price touches required to validate a trend line
- **Touch Point Tolerance** (0.0001): Tolerance for considering a price touch (as % of price)
- **Maximum Active Lines** (10): Maximum number of trend lines to display simultaneously

### Slope Configuration
- **Slope Multiplier** (1.0): Multiplier for slope calculation
- **Slope Calculation Method**:
  - 0: ATR-based slope adjustment
  - 1: Standard Deviation based
  - 2: Linear Regression

### Visual Settings
- **Show Extended Lines** (true): Project trend lines into the future
- **Up Trendline Color** (Aqua): Color for upward trend lines
- **Down Trendline Color** (Red): Color for downward trend lines
- **Line Width** (2): Width of trend lines
- **Line Style** (Solid): Style of trend lines (solid, dash, dot, etc.)

### Alert Settings
- **Show Breakout Labels** (true): Display "B" labels at breakout points
- **Alert on Breakouts** (true): Trigger alerts when price breaks trend lines

## How It Works

### 1. Pivot Point Detection
The indicator scans historical price data to identify pivot highs and lows:
- **Pivot High**: A bar where the high is greater than all surrounding bars within the lookback period
- **Pivot Low**: A bar where the low is lower than all surrounding bars within the lookback period

### 2. Trend Line Generation
- Connects pivot highs to form potential resistance lines (down trend lines)
- Connects pivot lows to form potential support lines (up trend lines)
- Lines are drawn between pivots that are within 10 bars of each other

### 3. Validation Process
Each trend line is validated by:
- Counting the number of times price touches the line (within tolerance)
- Removing lines that don't meet the minimum touch point requirement
- Marking lines as "broken" when price crosses through them

### 4. Breakout Detection
The indicator monitors for breakouts:
- **Upward Breakout**: When price closes above a down trend line
- **Downward Breakout**: When price closes below an up trend line
- Broken lines are displayed with dotted style
- Alerts and visual markers are generated on breakouts

## Trading Applications

### Trend Confirmation
- Multiple validated trend lines in the same direction confirm trend strength
- Lines with more touch points are considered more significant

### Support and Resistance
- Up trend lines act as dynamic support levels
- Down trend lines act as dynamic resistance levels

### Breakout Trading
- Trade breakouts when price decisively breaks through validated trend lines
- Use alerts to catch breakout opportunities in real-time

### Trend Reversal
- Watch for breaks of major trend lines as potential reversal signals
- Multiple broken lines may indicate trend exhaustion

## Tips for Best Results

1. **Adjust Lookback Period**: 
   - Use smaller values (5-10) for intraday trading
   - Use larger values (14-20) for daily/weekly charts

2. **Touch Point Tolerance**:
   - Increase tolerance for volatile instruments
   - Decrease for more precise trend line placement

3. **Minimum Touch Points**:
   - Higher values (4-5) for more reliable but fewer trend lines
   - Lower values (2-3) for more trend lines but potentially less reliable

4. **Slope Method Selection**:
   - ATR: Adapts to market volatility
   - StdDev: Good for ranging markets
   - LinReg: Best for trending markets

## Performance Optimization

- The indicator recalculates only on new bars to minimize CPU usage
- Limits the maximum number of active lines to prevent clutter
- Efficiently manages object creation and deletion

## Troubleshooting

### No Trend Lines Appearing
- Increase the lookback period
- Decrease minimum touch points
- Increase touch point tolerance

### Too Many Lines
- Decrease maximum active lines
- Increase minimum touch points
- Decrease lookback period

### Lines Not Matching Expected Pivots
- Adjust the lookback period to better match your chart's volatility
- Check that the tolerance setting is appropriate for your instrument

## Version History

### v1.0.0 (Current)
- Initial release with core functionality
- Automatic pivot detection
- Multi-touch validation
- Breakout detection and alerts
- Multiple slope calculation methods

## Future Enhancements
- Pattern recognition (triangles, wedges, channels)
- Multi-timeframe trend line analysis
- Volume confirmation for touch points
- Trend line strength scoring
- Historical performance statistics