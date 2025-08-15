# Bar Counter Enhanced v2.0

An advanced bar counting indicator for MetaTrader 5 with multiple display modes and enhanced visual features.

## Features Implemented

### 1. **Count Above/Below Toggle**
- Display bar counts above the high or below the low of each bar
- Configurable via `DisplayAboveBar` parameter

### 2. **Background Highlighting**
- Highlight specific bar ranges with customizable colors
- Set start and end bar numbers for highlighting
- Adjustable transparency for subtle visual effects

### 3. **Time Until Next Bar**
- Real-time countdown showing remaining time for current bar
- Displayed in the top-right corner
- Format: HH:MM:SS or MM:SS depending on timeframe

### 4. **Milestone Markers**
- Special highlighting for significant bar counts (5, 10, 25)
- Customizable milestone values and colors
- Larger text size for milestone numbers

### 5. **Count Boxes**
- Option to display counts inside styled boxes instead of plain text
- Customizable box colors and transparency
- Better visibility against chart backgrounds

### 6. **Average Bar Range**
- Calculates and displays average range over specified period
- Shows as "R:XXX" below the bar count
- Helps identify volatility patterns

### 7. **Skip Weekends**
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
- **TextSize**: Font size (6-20)
- **FontName**: Font family
- **TextOffset**: Vertical spacing
- **VerticalText**: Rotate text 90 degrees
- **MaxBarsToProcess**: Limit processing for performance

### Enhanced Features
- **UseCountBoxes**: Enable box display mode
- **BoxColor**: Fill color for boxes
- **BoxBorderColor**: Border color
- **BoxAlpha**: Box transparency (0-255)
- **ShowTimeUntilNextBar**: Enable countdown timer
- **TimeRemainingColor**: Timer text color
- **ShowAverageRange**: Display average range
- **AvgRangePeriod**: Bars for range calculation
- **AvgRangeColor**: Range text color

### Highlighting Settings
- **EnableBackgroundHighlight**: Enable range highlighting
- **HighlightStart**: First bar to highlight
- **HighlightEnd**: Last bar to highlight
- **HighlightColor**: Background color
- **HighlightAlpha**: Background transparency

### Milestone Settings
- **EnableMilestones**: Enable special markers
- **Milestone1/2/3**: Bar numbers for milestones
- **MilestoneColor1/2/3**: Colors for each milestone
- **MilestoneSize**: Text size for milestones

### Weekend Settings
- **SkipWeekends**: Exclude weekend bars from count
- **HighlightWeekends**: Show weekend bars differently
- **WeekendColor**: Weekend highlight color

## Usage Examples

### Basic Setup
- Set `DisplayInterval = 1` to show all bars
- Enable `UseCountBoxes` for better visibility
- Set `DisplayAboveBar = false` for below-bar display

### Session Trading
- Set `HighlightStart = 1` and `HighlightEnd = 8` for Asian session
- Enable milestones at 5, 10, 15 for session markers
- Use `ShowTimeUntilNextBar` for bar close timing

### Range Analysis
- Enable `ShowAverageRange` with period of 20
- Use background highlighting for high-volatility zones
- Skip weekends for accurate daily counts

## Performance Notes

- Use `MaxBarsToProcess` to limit history processing
- Disable unused features for better performance
- Objects are automatically cleaned on indicator removal

## Version History

- **v2.0** - Added all enhanced features
- **v1.0** - Basic bar counting functionality