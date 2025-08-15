# Session Highlighting Guide for BarCounterEnhanced v2.80

## Overview
The new session highlighting feature allows you to visually mark trading sessions on your chart with elegant transparent overlays and dashed borders, similar to professional trading platforms.

## Key Improvements in v2.80
- **Transparent Overlays**: Sessions use semi-transparent fills that don't obscure price action
- **Dashed Borders**: Professional-looking dashed outlines define session boundaries
- **Dual-Layer Rendering**: Separate border and fill objects for optimal visual quality
- **ARGB Color Support**: Proper alpha channel implementation for true transparency

## Configuration Guide

### Transparency Settings
The alpha parameter controls transparency (0-255):
- **0**: Completely invisible
- **15**: Very light overlay (recommended for dark charts)
- **30**: Light overlay (recommended for light charts)
- **50**: Semi-transparent
- **100**: More visible overlay
- **255**: Fully opaque (not recommended)

### Recommended Settings by Chart Style

#### For Dark Chart Backgrounds:
```
Session 1 (London):
- Color: clrLightBlue or clrCyan
- Alpha: 15-20
- Border Style: STYLE_DASH

Session 2 (New York):
- Color: clrOrange or clrGold
- Alpha: 15-20
- Border Style: STYLE_DASH
```

#### For Light Chart Backgrounds:
```
Session 1 (London):
- Color: clrBlue
- Alpha: 25-35
- Border Style: STYLE_DASH

Session 2 (New York):
- Color: clrOrange
- Alpha: 25-35
- Border Style: STYLE_DASH
```

## Border Styles Available
- **STYLE_SOLID**: Solid line
- **STYLE_DASH**: Dashed line (recommended)
- **STYLE_DOT**: Dotted line
- **STYLE_DASHDOT**: Dash-dot pattern
- **STYLE_DASHDOTDOT**: Dash-dot-dot pattern

## Session Time Format
Times are in 24-hour format (HH:MM-HH:MM):
- London: "08:00-17:00"
- New York: "13:00-22:00"
- Tokyo: "00:00-09:00"
- Sydney: "22:00-07:00" (crosses midnight)

## Tips for Best Results

1. **Start with Low Alpha Values**: Begin with alpha=15 and increase if needed
2. **Use Contrasting Colors**: Choose colors that stand out against your chart background
3. **Dashed Borders**: Keep the dashed border style for a professional look
4. **Session Labels**: Position labels at the top of sessions for clarity
5. **Overlapping Sessions**: When sessions overlap, transparency allows both to be visible

## Troubleshooting

### Sessions Not Visible
- Increase alpha value (make less transparent)
- Check if session times match your broker's server time
- Ensure "Show Session" is enabled

### Sessions Too Prominent
- Decrease alpha value (make more transparent)
- Use lighter colors
- Consider disabling fill and keeping only borders

### Performance Issues
- Reduce MaxBarsToProcess in Display Settings
- Disable unused sessions
- Use CleanOldSessionObjects to limit historical objects

## Example Complete Setup

For a professional forex trading setup:

```
Display Settings:
- MaxBarsToProcess: 500

Session 1 (London):
- Show: Yes
- Time: "08:00-17:00"
- Color: clrDodgerBlue
- Alpha: 20
- Name: "London"

Session 2 (New York):
- Show: Yes
- Time: "13:00-22:00"  
- Color: clrOrange
- Alpha: 20
- Name: "New York"

Session 3 (Tokyo):
- Show: Yes
- Time: "00:00-09:00"
- Color: clrMediumPurple
- Alpha: 20
- Name: "Tokyo"

Session Labels:
- Show: Yes
- Font Size: 8
- Border Style: STYLE_DASH
```

## Visual Comparison

### Before (Opaque Boxes):
- Blocks price action visibility
- Looks unprofessional
- Difficult to analyze price within sessions

### After (Transparent with Dashed Borders):
- Price action clearly visible
- Professional appearance
- Easy to identify session boundaries
- Multiple sessions can overlap without confusion

## Advanced Usage

### Custom Trading Sessions
Define your own sessions based on:
- Market open/close times
- High-volume periods
- Economic news windows
- Personal trading hours

### Multiple Timeframe Analysis
The session boxes automatically adjust to any timeframe, making them perfect for:
- Scalping (M1-M5)
- Day trading (M15-H1)
- Swing trading (H4-D1)

## Support
For issues or suggestions, please refer to the main BarCounterEnhanced documentation or contact support.