# Al Brooks Second Entry Indicator for MT5

## Overview
This MQL5 indicator implements Al Brooks' Second Entry pattern detection system for MetaTrader 5. It identifies high-probability entry points based on price action methodology, specifically focusing on second entry opportunities after pullbacks in trending markets.

## Key Features

### Signal Types
- **H1 (First Entry Long)**: First pullback in an uptrend after a new high
- **H2 (Second Entry Long)**: Second pullback in an uptrend - higher probability setup
- **L1 (First Entry Short)**: First pullback in a downtrend after a new low
- **L2 (Second Entry Short)**: Second pullback in a downtrend - higher probability setup

### Core Components

1. **Trend Bias Detection**
   - Uses EMA (default 50-period) to determine market bias
   - Bull bias: Price closes above EMA
   - Bear bias: Price closes below EMA

2. **Leg Tracking System**
   - Tracks price movements (legs) within the trend
   - Identifies pullback patterns
   - Counts legs to determine first vs second entries

3. **Signal Generation Logic**
   - **Bull Trend (H1/H2)**:
     - Tracks new highs in uptrend
     - Identifies downward pullbacks
     - Signals when pullback ends and price resumes upward
   - **Bear Trend (L1/L2)**:
     - Tracks new lows in downtrend
     - Identifies upward pullbacks
     - Signals when pullback ends and price resumes downward

## Input Parameters

### Signal Settings
| Parameter | Default | Description |
|-----------|---------|-------------|
| Show First Entry Long (H1) | true | Display H1 signals |
| Show First Entry Short (L1) | true | Display L1 signals |
| Show Second Entry Long (H2) | true | Display H2 signals |
| Show Second Entry Short (L2) | true | Display L2 signals |
| Show Strong Signals Only | false | Filter for high-quality setups |
| Wait for candle to close | true | Confirm signals on bar close |
| Primary EMA Period | 50 | EMA for trend bias |
| Show Secondary EMA | false | Display additional EMA |
| Secondary EMA Period | 21 | Secondary EMA period |
| Show New High/Low | false | Mark new highs/lows |
| Enable Alerts | true | Alert notifications |

### Range Filtering Parameters
| Parameter | Default | Description |
|-----------|---------|-------------|
| Filter Trading Ranges | true | Enable trading range detection |
| Minimum Bar Size (ATR) | 0.5 | Minimum bar size as ATR multiplier |
| Range Bars Threshold | 3 | Consecutive small bars to identify range |
| Range ATR Multiplier | 0.7 | Bar size threshold for range detection |
| ATR Period | 14 | Period for ATR calculation |

## Signal Visualization

- **H1**: Aqua up arrow below bar
- **H2**: Green thick up arrow below bar (stronger signal)
- **L1**: Orange down arrow above bar
- **L2**: Red thick down arrow above bar (stronger signal)
- **New High**: Olive triangle (optional)
- **New Low**: Purple triangle (optional)

## Strong Signal Criteria

When "Show Strong Signals Only" is enabled, second entries (H2/L2) must meet:

### For H2 (Long):
- Candle must be bullish (close > open)
- Close must be higher than previous close
- Close must be in top 30% of candle range

### For L2 (Short):
- Candle must be bearish (close < open)
- Close must be lower than previous close
- Close must be in bottom 30% of candle range

## Trading Strategy

### Entry Rules

**Long Entries (H1/H2):**
1. Market in uptrend (price above EMA)
2. Wait for pullback (1-2 legs down)
3. Enter when price resumes upward movement
4. H2 preferred over H1 (higher probability)

**Short Entries (L1/L2):**
1. Market in downtrend (price below EMA)
2. Wait for pullback (1-2 legs up)
3. Enter when price resumes downward movement
4. L2 preferred over L1 (higher probability)

### Risk Management
- Place stops beyond the pullback extreme
- Target previous highs/lows or measured moves
- Consider scaling out at key levels
- Use proper position sizing

## Installation

1. Copy `SecondEntry.mq5` to `MQL5/Indicators` folder
2. Compile in MetaEditor (F7)
3. Attach to chart in MT5
4. Configure parameters as needed

## Alert System

The indicator includes built-in alerts for:
- H1/H2 long entry signals
- L1/L2 short entry signals
- New highs in uptrends
- New lows in downtrends

## Best Practices

1. **Timeframe Selection**: Works on all timeframes, but H4 and Daily recommended for reliability
2. **Market Conditions**: Best in trending markets with clear directional bias
3. **Confirmation**: Consider using with other confluences (support/resistance, volume)
4. **Risk Management**: Always use stops and proper position sizing

## Range Filtering Feature

The indicator includes advanced range filtering to avoid false signals in choppy, low-volatility markets:

### How It Works
1. **Trading Range Detection**: Identifies periods of small, consecutive bars that indicate consolidation
2. **Bar Size Validation**: Filters out bars that are too small to be meaningful (< 0.5 × ATR by default)
3. **Signal Suppression**: No signals are generated when the market is in a detected trading range
4. **Breakout Recognition**: Resumes normal signal generation when price breaks out of the range

### Range Detection Criteria
- **Small Bar**: Bar range < 0.7 × ATR (configurable)
- **Trading Range**: 3+ consecutive small bars (configurable)
- **Range Exit**: Large bar (> 1.5 × ATR) or price breaks beyond range boundaries

### Benefits
- Reduces false signals in sideways markets
- Focuses on trending conditions where second entries work best
- Improves signal quality and reliability
- Prevents whipsaws in consolidation zones

## Differences from Pine Script Version

This MQL5 implementation includes:
- **Enhanced range filtering** to eliminate signals in consolidation zones
- **ATR-based bar validation** to ensure only meaningful price moves are counted
- Core Al Brooks second entry logic remains intact

Excluded features (as requested):
- Bar counting display
- Pullback zone visualization boxes
- Debug mode display

## Support

For questions or improvements, please refer to Al Brooks' price action trading resources for deeper understanding of the methodology.