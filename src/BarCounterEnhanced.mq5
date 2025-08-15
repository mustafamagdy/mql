//+------------------------------------------------------------------+
//|                                            BarCounterEnhanced.mq5|
//|                                 Enhanced Bar Counting Indicator   |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "2.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots 1

// Plot for average bar range
#property indicator_label1  "AvgRange"
#property indicator_type1   DRAW_NONE

// Input parameters - Display Settings
input group "Display Settings"
input int DisplayInterval = 1;                // Display count every X bars (1 = every bar)
input bool DisplayAboveBar = false;           // Display above high (true) or below low (false)
input color TextColor = clrRed;               // Text color for bar count
input int TextSize = 10;                      // Font size (6-20 recommended)
input string FontName = "Arial";              // Font name
input int TextOffset = 5;                     // Vertical offset (in ticks, 0=auto)
input bool VerticalText = true;               // Display text vertically (90 degrees rotation)
input int MaxBarsToProcess = 500;             // Maximum bars to process (0 = all bars)

// Input parameters - Enhanced Features
input group "Enhanced Features"
input bool UseCountBoxes = true;              // Use boxes instead of text
input color BoxColor = clrRed;                // Box fill color
input color BoxBorderColor = clrWhite;        // Box border color
input int BoxAlpha = 30;                      // Box transparency (0-255, 0=transparent)
input bool ShowTimeUntilNextBar = true;       // Show time remaining for current bar
input color TimeRemainingColor = clrYellow;   // Color for time remaining display
input bool ShowAverageRange = true;           // Show average bar range
input int AvgRangePeriod = 20;                // Period for average range calculation
input color AvgRangeColor = clrAqua;          // Color for average range display

// Input parameters - Highlighting
input group "Highlighting Settings"
input bool EnableBackgroundHighlight = true;   // Enable background highlighting
input int HighlightStart = 5;                 // Start highlighting from bar X
input int HighlightEnd = 15;                  // End highlighting at bar X
input color HighlightColor = clrGold;         // Highlight color
input int HighlightAlpha = 20;                // Highlight transparency (0-255)

// Input parameters - Milestone Markers
input group "Milestone Settings"
input bool EnableMilestones = true;           // Enable milestone markers
input int Milestone1 = 5;                     // First milestone
input int Milestone2 = 10;                    // Second milestone
input int Milestone3 = 25;                    // Third milestone
input color MilestoneColor1 = clrLime;        // Milestone 1 color
input color MilestoneColor2 = clrGold;        // Milestone 2 color
input color MilestoneColor3 = clrMagenta;     // Milestone 3 color
input int MilestoneSize = 14;                 // Milestone text size

// Input parameters - Weekend Handling
input group "Weekend Settings"
input bool SkipWeekends = true;               // Skip weekend bars in counting
input bool HighlightWeekends = false;         // Highlight weekend bars
input color WeekendColor = clrGray;           // Weekend highlight color

// Global variables
string objPrefix = "BarCountEnhanced_";
double AvgRangeBuffer[];
int barCounter = 0;
datetime lastCountedBar = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME, "Bar Counter Enhanced");
   
   // Set up average range buffer
   SetIndexBuffer(0, AvgRangeBuffer, INDICATOR_DATA);
   ArraySetAsSeries(AvgRangeBuffer, true);
   
   DeleteAllObjects();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
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
   
   // Show time until next bar for current bar
   if(ShowTimeUntilNextBar)
   {
      DisplayTimeUntilNextBar();
   }
   
   // Determine bars to process
   int limit = MaxBarsToProcess > 0 ? MathMin(MaxBarsToProcess, rates_total) : rates_total;
   
   // Calculate average range
   if(ShowAverageRange)
   {
      for(int i = 0; i < limit && i < rates_total - 1; i++)
      {
         double sum = 0;
         int count = 0;
         for(int j = i; j < i + AvgRangePeriod && j < rates_total; j++)
         {
            sum += (high[j] - low[j]);
            count++;
         }
         AvgRangeBuffer[i] = count > 0 ? sum / count : 0;
      }
   }
   
   // Process bars
   for(int i = 1; i < limit; i++) // Skip current bar [0]
   {
      datetime barTime = time[i];
      MqlDateTime dt;
      TimeToStruct(barTime, dt);
      
      // Check if weekend and should skip
      bool isWeekend = (dt.day_of_week == 0 || dt.day_of_week == 6);
      
      // Calculate bar number
      int barNumber = CalculateBarNumber(barTime, dt, isWeekend);
      
      // Skip weekend bars if requested
      if(SkipWeekends && isWeekend)
      {
         if(HighlightWeekends)
         {
            CreateWeekendHighlight(barTime, high[i], low[i]);
         }
         continue;
      }
      
      // Create background highlight if needed
      if(EnableBackgroundHighlight && barNumber >= HighlightStart && barNumber <= HighlightEnd)
      {
         CreateBackgroundHighlight(barTime, high[i], low[i], barNumber);
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
         
         // Create count display
         if(UseCountBoxes)
         {
            CreateCountBox(objName, barTime, displayPrice, barNumber, isMilestone);
         }
         else
         {
            CreateCountText(objName, barTime, displayPrice, barNumber, isMilestone);
         }
         
         // Display average range if enabled
         if(ShowAverageRange && i < ArraySize(AvgRangeBuffer))
         {
            DisplayAverageRange(barTime, displayPrice, AvgRangeBuffer[i], barNumber);
         }
      }
   }
   
   ChartRedraw();
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate bar number based on settings                           |
//+------------------------------------------------------------------+
int CalculateBarNumber(datetime barTime, MqlDateTime &dt, bool isWeekend)
{
   static int dayCounter = 0;
   static int lastDay = -1;
   static int weekendSkipCount = 0;
   
   // Reset counter at day start
   if(dt.day != lastDay)
   {
      dayCounter = 0;
      lastDay = dt.day;
      if(!isWeekend)
         weekendSkipCount = 0;
   }
   
   if(!isWeekend || !SkipWeekends)
   {
      dayCounter++;
      return dt.hour + 1 - weekendSkipCount;
   }
   else
   {
      weekendSkipCount++;
      return -1; // Skip this bar
   }
}

//+------------------------------------------------------------------+
//| Check if bar number is a milestone                               |
//+------------------------------------------------------------------+
bool IsMilestone(int barNumber)
{
   if(!EnableMilestones) return false;
   return (barNumber == Milestone1 || barNumber == Milestone2 || barNumber == Milestone3);
}

//+------------------------------------------------------------------+
//| Get milestone color                                              |
//+------------------------------------------------------------------+
color GetMilestoneColor(int barNumber)
{
   if(barNumber == Milestone1) return MilestoneColor1;
   if(barNumber == Milestone2) return MilestoneColor2;
   if(barNumber == Milestone3) return MilestoneColor3;
   return TextColor;
}

//+------------------------------------------------------------------+
//| Create count box                                                 |
//+------------------------------------------------------------------+
void CreateCountBox(string objName, datetime barTime, double price, int barNumber, bool isMilestone)
{
   // Create rectangle label for box effect
   string boxName = objName + "_box";
   
   // Calculate box dimensions
   datetime endTime = barTime + PeriodSeconds(PERIOD_CURRENT);
   double boxHeight = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * TextSize * 2;
   
   if(ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, barTime, price - boxHeight/2, endTime, price + boxHeight/2))
   {
      color fillColor = isMilestone ? GetMilestoneColor(barNumber) : BoxColor;
      color borderColor = isMilestone ? GetMilestoneColor(barNumber) : BoxBorderColor;
      
      ObjectSetInteger(0, boxName, OBJPROP_COLOR, borderColor);
      ObjectSetInteger(0, boxName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, boxName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, boxName, OBJPROP_FILL, true);
      ObjectSetInteger(0, boxName, OBJPROP_BACK, true);
      
      // Set fill color with transparency
      long argbColor = ColorToARGB(fillColor, BoxAlpha);
      ObjectSetInteger(0, boxName, OBJPROP_COLOR, argbColor);
   }
   
   // Create text inside box
   if(ObjectCreate(0, objName, OBJ_TEXT, 0, barTime, price))
   {
      ObjectSetString(0, objName, OBJPROP_TEXT, IntegerToString(barNumber));
      ObjectSetInteger(0, objName, OBJPROP_COLOR, isMilestone ? clrWhite : TextColor);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, isMilestone ? MilestoneSize : TextSize);
      ObjectSetString(0, objName, OBJPROP_FONT, FontName);
      ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetDouble(0, objName, OBJPROP_ANGLE, VerticalText ? 90.0 : 0.0);
   }
}

//+------------------------------------------------------------------+
//| Create count text                                                |
//+------------------------------------------------------------------+
void CreateCountText(string objName, datetime barTime, double price, int barNumber, bool isMilestone)
{
   if(ObjectCreate(0, objName, OBJ_TEXT, 0, barTime, price))
   {
      ObjectSetString(0, objName, OBJPROP_TEXT, IntegerToString(barNumber));
      ObjectSetInteger(0, objName, OBJPROP_COLOR, isMilestone ? GetMilestoneColor(barNumber) : TextColor);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, isMilestone ? MilestoneSize : TextSize);
      ObjectSetString(0, objName, OBJPROP_FONT, FontName);
      ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetDouble(0, objName, OBJPROP_ANGLE, VerticalText ? 90.0 : 0.0);
   }
}

//+------------------------------------------------------------------+
//| Create background highlight                                      |
//+------------------------------------------------------------------+
void CreateBackgroundHighlight(datetime barTime, double high, double low, int barNumber)
{
   string highlightName = GetObjectName(barTime, "highlight");
   
   if(ObjectFind(0, highlightName) >= 0)
      return;
   
   datetime endTime = barTime + PeriodSeconds(PERIOD_CURRENT);
   
   if(ObjectCreate(0, highlightName, OBJ_RECTANGLE, 0, barTime, high, endTime, low))
   {
      long argbColor = ColorToARGB(HighlightColor, HighlightAlpha);
      ObjectSetInteger(0, highlightName, OBJPROP_COLOR, argbColor);
      ObjectSetInteger(0, highlightName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, highlightName, OBJPROP_WIDTH, 0);
      ObjectSetInteger(0, highlightName, OBJPROP_FILL, true);
      ObjectSetInteger(0, highlightName, OBJPROP_BACK, true);
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
//| Display time until next bar                                      |
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
//| Display average range                                            |
//+------------------------------------------------------------------+
void DisplayAverageRange(datetime barTime, double price, double avgRange, int barNumber)
{
   string objName = GetObjectName(barTime, "avgrange");
   
   if(ObjectFind(0, objName) >= 0)
      return;
   
   // Format average range display
   double rangeInPoints = avgRange / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   string rangeText = "R:" + DoubleToString(rangeInPoints, 0);
   
   // Position below the count
   double offset = CalculateOffset() * 2;
   double displayPrice = DisplayAboveBar ? price - offset : price - offset;
   
   if(ObjectCreate(0, objName, OBJ_TEXT, 0, barTime, displayPrice))
   {
      ObjectSetString(0, objName, OBJPROP_TEXT, rangeText);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, AvgRangeColor);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, TextSize - 2);
      ObjectSetString(0, objName, OBJPROP_FONT, FontName);
      ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_CENTER);
   }
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