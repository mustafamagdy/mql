//+------------------------------------------------------------------+
//|                                            BarCounterEnhanced.mq5|
//|                                 Enhanced Bar Counting Indicator   |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "2.70"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots 0

// Font size enumeration
enum ENUM_FONT_SIZE
{
   FONT_SMALL = 0,     // Small (8pt)
   FONT_MEDIUM = 1,    // Medium (10pt)
   FONT_LARGE = 2,     // Large (12pt)
   FONT_CUSTOM = 3     // Custom Size
};

// Input parameters - Display Settings
input group "Display Settings"
input int DisplayInterval = 1;                // Display count every X bars (1 = every bar)
input bool DisplayAboveBar = false;           // Display above high (true) or below low (false)
input color TextColor = clrRed;               // Text color for bar count
input ENUM_FONT_SIZE FontSizeOption = FONT_MEDIUM; // Font size option
input int CustomFontSize = 10;                // Custom font size (used when Custom is selected)
input string FontName = "Arial";              // Font name
input int TextOffset = 0;                     // Vertical offset (in ticks, 0=auto)
input bool VerticalText = true;               // Display text vertically (90 degrees rotation)
input int MaxBarsToProcess = 500;             // Maximum bars to process (0 = all bars)

// Input parameters - Enhanced Features
input group "Enhanced Features"
input bool ShowTimeUntilNextBar = true;       // Show time remaining in corner
input color TimeRemainingColor = clrYellow;   // Color for corner time display
input bool ShowCurrentBarTimer = true;        // Show timer on right side of current candle
input color CurrentBarTimerColor = clrDarkOrange;   // Color for current bar timer
input int TimerFontSize = 10;                 // Timer font size

// Input parameters - Milestone Markers
input group "Milestone Settings"
input bool EnableMilestones = true;           // Enable milestone markers
input int MilestoneInterval = 5;              // Highlight every X bars (e.g., 5 = every 5th bar)
input color MilestoneColor = clrLime;         // Milestone color

// Input parameters - Weekend Handling
input group "Weekend Settings"
input bool SkipWeekends = true;               // Skip weekend bars in counting
input bool HighlightWeekends = false;         // Highlight weekend bars
input color WeekendColor = clrGray;           // Weekend highlight color

// Global variables
string objPrefix = "BarCountEnhanced_";
int barCounter = 0;
datetime lastCountedBar = 0;

//+------------------------------------------------------------------+
//| Get actual font size based on selection                          |
//+------------------------------------------------------------------+
int GetFontSize()
{
   switch(FontSizeOption)
   {
      case FONT_SMALL:  return 8;
      case FONT_MEDIUM: return 10;
      case FONT_LARGE:  return 12;
      case FONT_CUSTOM: return CustomFontSize;
      default:          return 10;
   }
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME, "Bar Counter Enhanced");
   DeleteAllObjects();
   
   // Set timer for 1-second updates if timers are enabled
   if(ShowTimeUntilNextBar || ShowCurrentBarTimer)
   {
      EventSetTimer(1); // Update every second
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer(); // Stop the timer
   DeleteAllObjects();
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // Set arrays as series
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   // Skip if no bars
   if(rates_total <= 0) return(0);
   
   // Clear objects on first run
   if(prev_calculated == 0)
   {
      DeleteAllObjects();
      barCounter = 0;
   }
   
   // Show time until next bar in corner
   if(ShowTimeUntilNextBar)
   {
      DisplayTimeUntilNextBar();
   }
   
   // Show timer on right side of current candle
   if(ShowCurrentBarTimer)
   {
      DisplayCurrentBarTimer(time, close);
   }
   
   // Determine bars to process
   int limit = MaxBarsToProcess > 0 ? MathMin(MaxBarsToProcess, rates_total) : rates_total;
   
   // Process bars from oldest to newest for correct counting
   // First pass: build bar numbers from oldest to newest
   int barNumbers[];
   ArrayResize(barNumbers, limit);
   ArrayInitialize(barNumbers, -1);
   
   // Reset the counter for a fresh count
   ResetBarCounter();
   
   // Count from oldest to newest
   for(int i = limit - 1; i >= 1; i--) // Process from oldest to newest, skip current bar [0]
   {
      datetime barTime = time[i];
      MqlDateTime dt;
      TimeToStruct(barTime, dt);
      
      // Check if weekend
      bool isWeekend = (dt.day_of_week == 0 || dt.day_of_week == 6);
      
      // Calculate and store bar number
      barNumbers[i] = CalculateBarNumber(barTime, dt, isWeekend);
   }
   
   // Second pass: display the bars
   for(int i = 1; i < limit; i++) // Skip current bar [0]
   {
      datetime barTime = time[i];
      MqlDateTime dt;
      TimeToStruct(barTime, dt);
      
      // Check if weekend
      bool isWeekend = (dt.day_of_week == 0 || dt.day_of_week == 6);
      
      // Get the pre-calculated bar number
      int barNumber = barNumbers[i];
      
      // Skip weekend bars if requested
      if(SkipWeekends && isWeekend)
      {
         if(HighlightWeekends)
         {
            CreateWeekendHighlight(barTime, high[i], low[i]);
         }
         continue;
      }
      
      // Display if interval matches or is a milestone
      bool isMilestone = IsMilestone(barNumber);
      if(barNumber % DisplayInterval == 0 || barNumber == 1 || isMilestone)
      {
         string objName = GetObjectName(barTime, "count");
         
         // Skip if already exists
         if(ObjectFind(0, objName) >= 0)
            continue;
         
         // Determine display position
         double displayPrice = DisplayAboveBar ? high[i] : low[i];
         double offset = CalculateOffset();
         if(DisplayAboveBar)
            displayPrice += offset;
         else
            displayPrice -= offset;
         
         // Create count display (text only)
         CreateCountText(objName, barTime, displayPrice, barNumber, isMilestone);
      }
   }
   
   ChartRedraw();
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Reset bar counter static variables                               |
//+------------------------------------------------------------------+
void ResetBarCounter()
{
   // This will force the static variables to reset in CalculateBarNumber
   MqlDateTime dt;
   dt.day = -1;
   bool dummy = false;
   CalculateBarNumber(0, dt, dummy);
}

//+------------------------------------------------------------------+
//| Calculate bar number based on settings                           |
//+------------------------------------------------------------------+
int CalculateBarNumber(datetime barTime, MqlDateTime &dt, bool isWeekend)
{
   static int dayCounter = 0;
   static int lastDay = -1;
   static datetime lastBarTime = 0;
   static int currentDayBarCount = 0;
   
   // Reset counter at day start (00:00)
   if(dt.day != lastDay)
   {
      lastDay = dt.day;
      currentDayBarCount = 0;
      lastBarTime = 0;
   }
   
   // Skip weekend bars if requested
   if(isWeekend && SkipWeekends)
   {
      return -1; // Skip this bar
   }
   
   // Only count if this is a new bar (different time)
   if(barTime != lastBarTime)
   {
      currentDayBarCount++;
      lastBarTime = barTime;
   }
   
   return currentDayBarCount;
}

//+------------------------------------------------------------------+
//| Check if bar number is a milestone                               |
//+------------------------------------------------------------------+
bool IsMilestone(int barNumber)
{
   if(!EnableMilestones || MilestoneInterval <= 0) return false;
   return (barNumber % MilestoneInterval == 0);
}

//+------------------------------------------------------------------+
//| Create count text                                                |
//+------------------------------------------------------------------+
void CreateCountText(string objName, datetime barTime, double price, int barNumber, bool isMilestone)
{
   if(ObjectCreate(0, objName, OBJ_TEXT, 0, barTime, price))
   {
      ObjectSetString(0, objName, OBJPROP_TEXT, IntegerToString(barNumber));
      ObjectSetInteger(0, objName, OBJPROP_COLOR, isMilestone ? MilestoneColor : TextColor);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, GetFontSize());
      ObjectSetString(0, objName, OBJPROP_FONT, FontName);
      ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetDouble(0, objName, OBJPROP_ANGLE, VerticalText ? 90.0 : 0.0);
   }
}

//+------------------------------------------------------------------+
//| Create weekend highlight                                         |
//+------------------------------------------------------------------+
void CreateWeekendHighlight(datetime barTime, double high, double low)
{
   string weekendName = GetObjectName(barTime, "weekend");
   
   if(ObjectFind(0, weekendName) >= 0)
      return;
   
   datetime endTime = barTime + PeriodSeconds(PERIOD_CURRENT);
   
   if(ObjectCreate(0, weekendName, OBJ_RECTANGLE, 0, barTime, high, endTime, low))
   {
      long argbColor = ColorToARGB(WeekendColor, 30);
      ObjectSetInteger(0, weekendName, OBJPROP_COLOR, argbColor);
      ObjectSetInteger(0, weekendName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, weekendName, OBJPROP_WIDTH, 0);
      ObjectSetInteger(0, weekendName, OBJPROP_FILL, true);
      ObjectSetInteger(0, weekendName, OBJPROP_BACK, true);
   }
}

//+------------------------------------------------------------------+
//| Timer event - updates countdown displays every second            |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Update both timer displays
   if(ShowTimeUntilNextBar)
   {
      DisplayTimeUntilNextBar();
   }
   
   if(ShowCurrentBarTimer)
   {
      // Get current bar data for timer update
      datetime time[];
      double close[];
      ArraySetAsSeries(time, true);
      ArraySetAsSeries(close, true);
      
      if(CopyTime(_Symbol, PERIOD_CURRENT, 0, 1, time) > 0 &&
         CopyClose(_Symbol, PERIOD_CURRENT, 0, 1, close) > 0)
      {
         DisplayCurrentBarTimer(time, close);
      }
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Display timer on right side of current candle                    |
//+------------------------------------------------------------------+
void DisplayCurrentBarTimer(const datetime &time[], const double &close[])
{
   string objName = objPrefix + "CurrentBarTimer";
   
   // Get current time and period
   datetime currentTime = TimeCurrent();
   int period = PeriodSeconds(PERIOD_CURRENT);
   
   // Calculate time until next bar
   datetime barStartTime = (currentTime / period) * period;
   datetime nextBarTime = barStartTime + period;
   int secondsRemaining = (int)(nextBarTime - currentTime);
   
   // Format time display
   string timeDisplay = FormatTimeRemaining(secondsRemaining);
   
   // Get current bar position and price (index 0)
   datetime currentBarTime = time[0];
   double currentPrice = close[0];
   
   // Calculate position below the price line with offset
   double offset = CalculateOffset();
   double displayPrice = currentPrice - offset;
   
   // Calculate position to the right of current candle
   // Add time offset to place text to the right (40% of the period)
   datetime displayTime = currentBarTime + (period * 2 / 5); // Place 2/5 period to the right
   
   // Create or update timer display
   if(ObjectFind(0, objName) < 0)
   {
      if(ObjectCreate(0, objName, OBJ_TEXT, 0, displayTime, displayPrice))
      {
         ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT);
         ObjectSetString(0, objName, OBJPROP_FONT, FontName);
      }
   }
   else
   {
      // Update position to follow current price and stay to the right
      ObjectSetInteger(0, objName, OBJPROP_TIME, displayTime);
      ObjectSetDouble(0, objName, OBJPROP_PRICE, displayPrice);
   }
   
   // Update timer text and properties
   ObjectSetString(0, objName, OBJPROP_TEXT, timeDisplay);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, CurrentBarTimerColor);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, TimerFontSize);
}

//+------------------------------------------------------------------+
//| Display time until next bar in corner                            |
//+------------------------------------------------------------------+
void DisplayTimeUntilNextBar()
{
   string objName = objPrefix + "TimeRemaining";
   
   // Get current time and period
   datetime currentTime = TimeCurrent();
   int period = PeriodSeconds(PERIOD_CURRENT);
   
   // Calculate time until next bar
   datetime barStartTime = (currentTime / period) * period;
   datetime nextBarTime = barStartTime + period;
   int secondsRemaining = (int)(nextBarTime - currentTime);
   
   // Format time display
   string timeDisplay = FormatTimeRemaining(secondsRemaining);
   
   // Create or update display
   if(ObjectFind(0, objName) < 0)
   {
      ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 30);
   }
   
   ObjectSetString(0, objName, OBJPROP_TEXT, "Next Bar: " + timeDisplay);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, TimeRemainingColor);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, objName, OBJPROP_FONT, "Arial");
}

//+------------------------------------------------------------------+
//| Format time remaining display                                    |
//+------------------------------------------------------------------+
string FormatTimeRemaining(int seconds)
{
   int hours = seconds / 3600;
   int minutes = (seconds % 3600) / 60;
   int secs = seconds % 60;
   
   if(hours > 0)
      return StringFormat("%d:%02d:%02d", hours, minutes, secs);
   else
      return StringFormat("%d:%02d", minutes, secs);
}

//+------------------------------------------------------------------+
//| Calculate display offset                                         |
//+------------------------------------------------------------------+
double CalculateOffset()
{
   if(TextOffset > 0)
      return TextOffset * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   else
      return 20 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
}

//+------------------------------------------------------------------+
//| Get unique object name                                           |
//+------------------------------------------------------------------+
string GetObjectName(datetime barTime, string suffix)
{
   string name = objPrefix + suffix + "_" + TimeToString(barTime, TIME_DATE|TIME_MINUTES);
   StringReplace(name, ":", "");
   StringReplace(name, " ", "_");
   StringReplace(name, ".", "_");
   return name;
}

//+------------------------------------------------------------------+
//| Convert color to ARGB format with alpha                          |
//+------------------------------------------------------------------+
long ColorToARGB(color clr, int alpha)
{
   return ((long)alpha << 24) | ((long)clr & 0xFFFFFF);
}

//+------------------------------------------------------------------+
//| Delete all objects created by this indicator                    |
//+------------------------------------------------------------------+
void DeleteAllObjects()
{
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, objPrefix) == 0)
         ObjectDelete(0, name);
   }
}
//+------------------------------------------------------------------+