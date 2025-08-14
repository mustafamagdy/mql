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
input color TextColor = clrRed;     // Text color for bar count
input int TextSize = 10;              // Font size (6-20 recommended, default: 10)
input string FontName = "Arial";      // Font name (Arial, Verdana, Times New Roman, etc.)
input int TextOffset = 5;             // Vertical offset below bars (in ticks, 0=auto)
input bool VerticalText = true;       // Display text vertically (90 degrees rotation)
input int MaxBarsToProcess = 500;     // Maximum bars to process (0 = all bars)
input bool EnableDebugLog = false;    // Enable debug logging

// Global variables
string objPrefix = "BarCount_";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "Bar Counter (Reset Daily)");
   
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
   
   // ALWAYS clean up ALL objects to remove previous days' numbers
   DeleteAllObjects();
   
   // Get current time
   datetime currentTime = TimeCurrent();
   MqlDateTime currentDT;
   TimeToStruct(currentTime, currentDT);
   
   // Get today's midnight
   MqlDateTime todayDT = currentDT;
   todayDT.hour = 0;
   todayDT.min = 0;
   todayDT.sec = 0;
   datetime todayMidnight = StructToTime(todayDT);
   
   if(EnableDebugLog && prev_calculated == 0)
   {
      Print("=== SIMPLIFIED BAR COUNTER - TODAY ONLY ===");
      Print("Current time: ", TimeToString(currentTime, TIME_DATE|TIME_MINUTES));
      Print("Today midnight: ", TimeToString(todayMidnight, TIME_DATE|TIME_MINUTES));
   }
   
   // Count and display bars for TODAY ONLY
   for(int i = 0; i < rates_total; i++)
   {
      datetime barTime = time[i];
      
      // Stop if we've gone past today
      if(barTime < todayMidnight)
         break;
      
      // Skip current incomplete bar
      if(i == 0)
         continue;
         
      MqlDateTime barDT;
      TimeToStruct(barTime, barDT);
      
      // Calculate bar number: hour + 1 (00:00 = 1, 01:00 = 2, etc.)
      int barNumber = barDT.hour + 1;
      
      if(EnableDebugLog && i < 30)
      {
         Print("Index [", i, "] = ", TimeToString(barTime, TIME_DATE|TIME_MINUTES), 
               " (Hour: ", barDT.hour, ") -> Bar #", barNumber);
      }
      
      // Display count if this bar meets the display interval criteria
      if(barNumber % DisplayInterval == 0 || barNumber == 1)
      {
         // Create text object name
         string timeStr = TimeToString(barTime, TIME_DATE|TIME_MINUTES);
         StringReplace(timeStr, ":", "");
         StringReplace(timeStr, " ", "_");
         StringReplace(timeStr, ".", "_");
         string objName = objPrefix + timeStr;
         
         // Delete any existing object at this position first
         if(ObjectFind(0, objName) >= 0)
            ObjectDelete(0, objName);
         
         // Create text object
         if(ObjectCreate(0, objName, OBJ_TEXT, 0, barTime, low[i]))
         {
            // Set text properties
            ObjectSetString(0, objName, OBJPROP_TEXT, IntegerToString(barNumber));
            ObjectSetInteger(0, objName, OBJPROP_COLOR, TextColor);
            ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, TextSize);
            ObjectSetString(0, objName, OBJPROP_FONT, FontName);
            ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_CENTER);
            
            // Set text rotation if vertical text is enabled
            if(VerticalText)
            {
               ObjectSetDouble(0, objName, OBJPROP_ANGLE, 90.0);
            }
            else
            {
               ObjectSetDouble(0, objName, OBJPROP_ANGLE, 0.0);
            }
            
            // Calculate offset
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
            
            double offset;
            if(TextOffset > 0)
            {
               offset = TextOffset * tickSize;
               if(offset == 0)
                  offset = TextOffset * point * 10;
            }
            else
            {
               // Auto mode - simple fixed offset
               offset = 20 * point;
            }
            
            // Position text below the bar - USE EXACT BAR TIME
            double textPrice = low[i] - offset;
            
            ObjectSetInteger(0, objName, OBJPROP_TIME, barTime);
            ObjectSetDouble(0, objName, OBJPROP_PRICE, textPrice);
         }
      }
   }
   
   if(EnableDebugLog && prev_calculated == 0)
   {
      Print("=== END ===");
   }
   
   return(rates_total);
}


//+------------------------------------------------------------------+
//| Delete all objects created by this indicator                    |
//+------------------------------------------------------------------+
void DeleteAllObjects()
{
   // Delete all objects with our prefix
   int deleted = 0;
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, objPrefix) == 0)
      {
         if(ObjectDelete(0, name))
            deleted++;
      }
   }
   
   if(EnableDebugLog && deleted > 0)
      Print("Deleted ", deleted, " old bar count objects");
      
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