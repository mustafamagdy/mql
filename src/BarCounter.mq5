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
input color TextColor = clrRed;       // Text color for bar count
input int TextSize = 10;              // Font size (6-20 recommended)
input string FontName = "Arial";      // Font name
input int TextOffset = 5;             // Vertical offset below bars (in ticks, 0=auto)
input bool VerticalText = true;       // Display text vertically (90 degrees rotation)
input int MaxBarsToProcess = 500;     // Maximum bars to process (0 = all bars)

// Global variables
string objPrefix = "BarCount_";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME, "Bar Counter");
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
   ArraySetAsSeries(low, true);
   
   // Skip if no bars
   if(rates_total <= 0) return(0);
   
   // Clear objects on first run
   if(prev_calculated == 0)
      DeleteAllObjects();
   
   // Determine bars to process
   int limit = MaxBarsToProcess > 0 ? MathMin(MaxBarsToProcess, rates_total) : rates_total;
   
   // Process bars
   for(int i = 1; i < limit; i++) // Skip current bar [0]
   {
      datetime barTime = time[i];
      MqlDateTime dt;
      TimeToStruct(barTime, dt);
      
      // Calculate bar number (00:00 = 1, 01:00 = 2, etc.)
      int barNumber = dt.hour + 1;
      
      // Display if interval matches
      if(barNumber % DisplayInterval == 0 || barNumber == 1)
      {
         string objName = objPrefix + TimeToString(barTime, TIME_DATE|TIME_MINUTES);
         StringReplace(objName, ":", "");
         StringReplace(objName, " ", "_");
         StringReplace(objName, ".", "_");
         
         // Skip if already exists
         if(ObjectFind(0, objName) >= 0)
            continue;
         
         // Create text object
         if(ObjectCreate(0, objName, OBJ_TEXT, 0, barTime, low[i]))
         {
            ObjectSetString(0, objName, OBJPROP_TEXT, IntegerToString(barNumber));
            ObjectSetInteger(0, objName, OBJPROP_COLOR, TextColor);
            ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, TextSize);
            ObjectSetString(0, objName, OBJPROP_FONT, FontName);
            ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_CENTER);
            ObjectSetDouble(0, objName, OBJPROP_ANGLE, VerticalText ? 90.0 : 0.0);
            
            // Calculate offset
            double offset = TextOffset > 0 ? 
                           TextOffset * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE) :
                           20 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            
            ObjectSetDouble(0, objName, OBJPROP_PRICE, low[i] - offset);
         }
      }
   }
   
   ChartRedraw();
   return(rates_total);
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