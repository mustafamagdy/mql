# Bar Counter Enhanced v3.0

Professional bar counting indicator with trading session visualization for MetaTrader 5

## Overview

Market Session & Bar Counter displays bar numbers on your chart while highlighting major trading sessions with semi-transparent overlays. Perfect for traders who need to track bar progression and monitor session activity simultaneously.

## Key Features

### Bar Counting
- Numbers each bar from the start of the trading day
- Customizable display intervals (show every bar or every Nth bar)
- Milestone highlighting for important bar numbers
- Real-time countdown timer showing time until next bar
- Weekend bar handling (skip or highlight)

### Trading Sessions
- 4 configurable trading sessions with semi-transparent overlays
- Sessions don't block your price action - you can see through them
- Each session fully customizable:
  - Time range (24-hour format)
  - Color and transparency level
  - Border style (solid, dashed, dotted)
  - Session name labels

### Timezone Support
- Multiple timezone options:
  - Broker/Server time
  - Local computer time
  - UTC/GMT
  - New York (EST/EDT)
  - London (GMT/BST)
  - Tokyo (JST)
  - Sydney (AEST/AEDT)
  - Custom UTC offset
- Automatic Daylight Saving Time detection
- Timezone indicator on chart

## Input Parameters

### Display Settings
- **Display Interval** - Show count every X bars (default: 5)
- **Display Above Bar** - Position text above or below candles
- **Text Color** - Color for bar numbers
- **Font Size** - Small/Medium/Large/Custom
- **Vertical Text** - Rotate text 90 degrees
- **Max Bars to Process** - Limit bars for performance (default: 500)

### Session Configuration
- **Session Timezone** - Reference timezone for all sessions
- **Auto Detect DST** - Automatic Daylight Saving Time adjustment
- **Show Session 1-4** - Enable/disable each session
- **Session Time** - Time range in HH:MM-HH:MM format
- **Session Color** - Base color for session box
- **Session Alpha** - Transparency (0-255, lower = more transparent)
- **Session Name** - Label displayed on chart

### Timer Settings
- **Show Current Bar Timer** - Display countdown to next bar
- **Timer Color** - Countdown display color
- **Timer Font Size** - Timer text size

### Milestone Settings
- **Enable Milestones** - Highlight significant bar numbers
- **Milestone Interval** - Every Nth bar to highlight
- **Milestone Color** - Color for milestone bars

## Default Sessions

### Forex Market Sessions
- **London**: 08:00-17:00
- **New York**: 13:00-22:00  
- **Tokyo**: 00:00-09:00
- **Sydney**: 22:00-07:00

Times are in the selected timezone and automatically adjust for DST.

## How It Works

1. **Bar Counting**: The indicator numbers each bar starting from the beginning of each trading day. You can display every bar number or only show specific intervals.

2. **Session Visualization**: Trading sessions appear as semi-transparent colored boxes behind your price action. The transparency effect is achieved by blending colors, allowing you to see both sessions and candlesticks clearly.

3. **Timezone Handling**: All session times are converted to your selected timezone. When DST is active in the selected region, times adjust automatically.

4. **Timer Display**: A countdown timer appears to the right of the current candle, showing exactly how much time remains until the next bar forms.

## Installation

1. Copy `BarCounter.mq5` to your `MQL5/Indicators` folder
2. Restart MetaTrader 5 or refresh the Navigator
3. Drag the indicator onto any chart
4. Configure settings as needed

## Use Cases

### Session Trading
Enable all four sessions to see when major markets are active. Session overlaps often indicate increased volatility.

### Scalping
Set bar display interval to 1 and use the countdown timer for precise entry timing.

### Day Trading
Track bar progression throughout the day with milestone markers at key intervals.

### Multi-Market Trading
Use timezone settings to display sessions correctly regardless of your broker's server location.

## Performance

- Lightweight code with minimal CPU usage
- Automatic cleanup of old objects
- Optimized for all timeframes
- Works with all symbols (Forex, Stocks, Indices, Crypto)

## Compatibility

- MetaTrader 5 build 2560 or higher
- All brokers supported
- All account types (demo, live, prop firm)
- VPS compatible

## Version History

**v3.0 (Current)**
- Added semi-transparent session overlays
- Implemented multi-timezone support
- Added DST auto-detection
- Improved performance

**v2.0**
- Added countdown timer
- Milestone markers
- Weekend handling

**v1.0**
- Initial release with basic bar counting

## Support

For questions or issues, please contact through the MQL5 marketplace messaging system.

## License

One license per trading account. The indicator is bound to your account number and cannot be shared or resold.