# Bar Counter Enhanced v2.0

An advanced bar counting indicator for MetaTrader 5 with multiple display modes and enhanced visual features.

## Features Implemented

### 1. **Count Above/Below Toggle**
- Display bar counts above the high or below the low of each bar
- Configurable via `DisplayAboveBar` parameter

### 2. **Time Until Next Bar**
- Real-time countdown showing remaining time for current bar
- Displayed in the top-right corner
- Format: HH:MM:SS or MM:SS depending on timeframe

### 3. **Milestone Markers**
- Highlight every Nth bar (e.g., every 5th, 10th bar)
- Single interval configuration for consistent highlighting
- Only the counter text changes color and size
- Perfect for identifying key bar positions

### 4. **Skip Weekends**
- Option to exclude weekend bars from counting
- Maintains continuous count across trading days
- Optional weekend highlighting

## Installation

1. Copy `BarCounterEnhanced.mq5` to your MT5 `Indicators` folder
2. Compile the indicator in MetaEditor
3. Attach to any chart

## Input Parameters

### Display Settings
- **DisplayInterval**: Show count every X bars
- **DisplayAboveBar**: Toggle display position (above/below)
- **TextColor**: Main text color
- **FontSizeOption**: Choose from Small (8pt), Medium (10pt), Large (12pt), or Custom
- **CustomFontSize**: Custom size value (used when Custom is selected)
- **FontName**: Font family
- **TextOffset**: Vertical spacing
- **VerticalText**: Rotate text 90 degrees
- **MaxBarsToProcess**: Limit processing for performance

### Enhanced Features
- **ShowTimeUntilNextBar**: Enable countdown timer
- **TimeRemainingColor**: Timer text color

### Milestone Settings
- **EnableMilestones**: Enable special markers
- **MilestoneInterval**: Highlight every X bars (e.g., 5 = every 5th bar)
- **MilestoneColor**: Color for milestone bars
- **MilestoneSize**: Text size for milestones

### Weekend Settings
- **SkipWeekends**: Exclude weekend bars from count
- **HighlightWeekends**: Show weekend bars differently
- **WeekendColor**: Weekend highlight color

## Usage Examples

### Basic Setup
- Set `DisplayInterval = 1` to show all bars
- Set `DisplayAboveBar = false` for below-bar display
- Enable milestones for key bar numbers

### Session Trading
- Set `MilestoneInterval = 5` to highlight every 5th bar
- Use `ShowTimeUntilNextBar` for bar close timing
- Skip weekends for accurate daily counts

## Performance Notes

- Use `MaxBarsToProcess` to limit history processing
- Disable unused features for better performance
- Objects are automatically cleaned on indicator removal

## Version History

- **v2.4** - Removed bar range highlighting and average range calculation for cleaner display
- **v2.3** - Simplified milestone system with single interval configuration
- **v2.2** - Fixed bar counting to count actual candles instead of hours (works on all timeframes)
- **v2.1** - Added font size presets (Small/Medium/Large/Custom), removed box display
- **v2.0** - Added all enhanced features
- **v1.0** - Basic bar counting functionality