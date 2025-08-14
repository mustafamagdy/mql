//+------------------------------------------------------------------+
//|                                                   BarCounter.mq5 |
//|                                      Bar Counting Indicator      |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

// Input parameters
input int DisplayInterval = 1;        // Display count every X bars (1 = every bar)
input color TextColor = clrWhite;     // Text color for bar count
input int TextSize = 10;              // Text size
input int TextOffset = 5;             // Vertical offset below bars (in ticks, 0=auto)
input bool VerticalText = true;       // Display text vertically (90 degrees rotation)
input int MaxBarsToProcess = 500;     // Maximum bars to process (0 = all bars)

// Global variables
datetime lastResetDate = 0;
int barCountSinceReset = 0;
string objPrefix = "BarCount_";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "Bar Counter (Reset Daily)");
   
   // Initialize last reset date
   lastResetDate = GetDayStart(TimeCurrent());
   
   // Clean up any existing objects
   DeleteAllObjects();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up all objects created by this indicator
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
   // Set array series flags
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   // Calculate starting position with limit
   int start = 0;
   int barsLimit = rates_total;
   
   // Apply max bars limit if specified
   if(MaxBarsToProcess > 0 && rates_total > MaxBarsToProcess)
   {
      barsLimit = MaxBarsToProcess;
   }
   
   if(prev_calculated > 0)
   {
      // Process only new bars
      start = rates_total - prev_calculated;
      if(start > barsLimit - 1)
         start = barsLimit - 1;
   }
   else
   {
      // First run - process limited number of bars
      start = barsLimit - 1;
      
      // Clean up old objects before processing
      DeleteAllObjects();
      
      // Find the day start for proper counting initialization
      if(start > 0 && start < rates_total)
      {
         datetime oldestBarTime = time[start];
         lastResetDate = GetDayStart(oldestBarTime);
         
         // Count bars from day start to get correct initial count
         barCountSinceReset = 0;
         for(int j = start; j >= 0; j--)
         {
            if(GetDayStart(time[j]) == lastResetDate)
               barCountSinceReset++;
            else
               break;
         }
         barCountSinceReset--; // Adjust for the loop counting
      }
   }
   
   // Process bars
   for(int i = start; i >= 0; i--)
   {
      // Skip the current bar (index 0) as it's not closed yet
      if(i == 0)
         continue;
      
      // Skip bars beyond our limit
      if(MaxBarsToProcess > 0 && i >= MaxBarsToProcess)
         continue;
         
      datetime barTime = time[i];
      datetime dayStart = GetDayStart(barTime);
      
      // Check if we need to reset the counter (new day)
      if(dayStart != lastResetDate)
      {
         // Clean up text objects from the previous day's last bars
         if(lastResetDate != 0 && i > 0)
         {
            // Remove text from the last few bars of previous day to avoid overlap
            for(int j = 1; j <= 5 && (i + j) < rates_total; j++)
            {
               string prevObjName = objPrefix + TimeToString(time[i + j]);
               if(ObjectFind(0, prevObjName) >= 0)
                  ObjectDelete(0, prevObjName);
            }
         }
         
         lastResetDate = dayStart;
         barCountSinceReset = 0;
      }
      
      // Increment bar count
      barCountSinceReset++;
      
      // Display count if this bar meets the display interval criteria
      if(barCountSinceReset % DisplayInterval == 0 || barCountSinceReset == 1)
      {
         // Create text object name with unique identifier including day
         string objName = objPrefix + TimeToString(dayStart, TIME_DATE) + "_" + IntegerToString(barCountSinceReset);
         
         // Check if object already exists (don't recreate for closed bars)
         if(ObjectFind(0, objName) < 0)
         {
            // Create text object only if it doesn't exist
            if(ObjectCreate(0, objName, OBJ_TEXT, 0, barTime, low[i]))
            {
               // Set text properties
               ObjectSetString(0, objName, OBJPROP_TEXT, IntegerToString(barCountSinceReset));
               ObjectSetInteger(0, objName, OBJPROP_COLOR, TextColor);
               ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, TextSize);
               ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_CENTER);
               
               // Set text rotation if vertical text is enabled
               if(VerticalText)
               {
                  ObjectSetDouble(0, objName, OBJPROP_ANGLE, 90.0);  // Rotate 90 degrees for vertical text
               }
               else
               {
                  ObjectSetDouble(0, objName, OBJPROP_ANGLE, 0.0);   // Horizontal text (default)
               }
               
               // Get the low price (bottom of the wick)
               double barLow = low[i];
               
               // Calculate offset based on symbol properties
               double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
               double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
               
               // Calculate a consistent offset below the wick
               double offset;
               if(TextOffset > 0)
               {
                  // Use tick size for more consistent spacing across different symbols
                  offset = TextOffset * tickSize;
                  if(offset == 0) // Fallback if tick size is not available
                     offset = TextOffset * point * 10;
               }
               else
               {
                  // Auto mode: calculate based on average bar range
                  double avgRange = 0;
                  int rangeBars = MathMin(20, rates_total - i - 1);
                  for(int k = i; k < i + rangeBars && k < rates_total; k++)
                  {
                     avgRange += (high[k] - low[k]);
                  }
                  if(rangeBars > 0)
                     avgRange = avgRange / rangeBars;
                  
                  // Set offset as 20% of average bar range
                  offset = avgRange * 0.2;
                  if(offset == 0) // Fallback
                     offset = 10 * tickSize;
               }
               
               // Position text below the bar's low (bottom of wick) with offset
               int barPeriod = PeriodSeconds() / 2;  // Half of bar period in seconds
               datetime centerTime = barTime - (datetime)barPeriod;  // Shift time to center of candle
               
               // Place text below the wick with offset
               double textPrice = barLow - offset;
               
               ObjectSetInteger(0, objName, OBJPROP_TIME, centerTime);
               ObjectSetDouble(0, objName, OBJPROP_PRICE, textPrice);
            }
         }
      }
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Get the start of the day for a given time                       |
//+------------------------------------------------------------------+
datetime GetDayStart(datetime time)
{
   MqlDateTime dt;
   TimeToStruct(time, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
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
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Chart event handler                                             |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // Handle chart changes to refresh display if needed
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      ChartRedraw();
   }
}
//+------------------------------------------------------------------+