# Bar Counter Indicator for MetaTrader 5

## Overview
The Bar Counter indicator is a custom MQL5 indicator that counts bars on your chart with automatic daily reset functionality. It displays the bar count below each bar (or at configurable intervals) and resets the count at the beginning of each trading day.

## Features
- **Automatic Bar Counting**: Counts each bar as it forms on the chart
- **Daily Reset**: Automatically resets the count at midnight (broker time)
- **Configurable Display Interval**: Choose to display count on every bar or every X bars
- **Customizable Appearance**: Adjust text color, size, and positioning
- **Clean Chart Management**: Automatically removes old text objects to keep chart clean

## Installation

1. Copy the `BarCounter.mq5` file to your MetaTrader 5 installation directory:
   ```
   [MT5 Directory]/MQL5/Indicators/
   ```

2. Open MetaTrader 5 and go to the Navigator panel (Ctrl+N)

3. Under "Indicators" → "Custom", find "BarCounter"

4. Drag and drop the indicator onto your chart, or right-click and select "Attach to Chart"

## Input Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| **DisplayInterval** | Integer | 1 | Display count every X bars (1 = every bar, 5 = every 5th bar, etc.) |
| **TextColor** | Color | White | Color of the bar count text |
| **TextSize** | Integer | 10 | Font size (6=tiny, 8=small, 10=medium, 12=large, 14+=extra large) |
| **FontName** | String | Arial | Font family (Arial, Verdana, Times New Roman, Courier New, etc.) |
| **TextOffset** | Integer | 5 | Vertical distance below bars (in ticks, use 0 for auto) |
| **VerticalText** | Boolean | true | Display text vertically (90 degrees rotation) |
| **MaxBarsToProcess** | Integer | 500 | Maximum bars to process (0 = all bars, recommended 200-500 for M1) |

## Usage Examples

### Example 1: Display on Every Bar
- Set `DisplayInterval = 1`
- Shows count below each bar: 1, 2, 3, 4, 5...

### Example 2: Display Every 5 Bars
- Set `DisplayInterval = 5`
- Shows count only on bars 5, 10, 15, 20...

### Example 3: Clean Display for Higher Timeframes
- For H4 or Daily charts, use `DisplayInterval = 10` or higher
- Reduces clutter while maintaining count visibility

## How It Works

1. **Bar Counting Logic**:
   - Starts counting from 1 at the beginning of each day
   - Increments count only for closed bars
   - Does not display count on the current (still forming) bar
   - Maintains count across timeframe changes

2. **Daily Reset**:
   - Detects day boundary based on bar timestamps
   - Resets counter to 0 at midnight (00:00 broker time)

3. **Display Management**:
   - Creates text objects only for closed bars
   - Labels are created once per bar and not updated on every tick
   - Automatically positions text based on bar low and offset
   - Removes old text objects to prevent memory issues

## Performance Considerations

- The indicator is optimized to process only new bars
- Text objects are created only at display intervals, reducing resource usage
- Old objects are automatically cleaned up to maintain performance
- **MaxBarsToProcess** parameter limits processing on lower timeframes:
  - M1: Use 200-300 bars for best performance
  - M5-M15: Use 300-500 bars
  - H1+: Can use 0 (all bars) as there are fewer bars to process
- Limiting bars significantly improves initialization speed on small timeframes

## Troubleshooting

### Text Not Visible
- Check if `TextColor` contrasts with your chart background
- Increase `TextSize` for better visibility
- Adjust `TextOffset` if text overlaps with price action

### Count Not Resetting
- Verify your broker's server time
- The reset occurs at 00:00 broker time, not local time

### Performance Issues
- Increase `DisplayInterval` to reduce the number of text objects
- Consider disabling on lower timeframes with many bars

## Compatibility
- **Platform**: MetaTrader 5
- **Version**: Build 3000 or higher recommended
- **Timeframes**: All timeframes supported
- **Symbols**: Works with all trading instruments

## License
This indicator is provided as-is for educational and trading purposes.

## Support
For issues or feature requests, please refer to the documentation or contact support.