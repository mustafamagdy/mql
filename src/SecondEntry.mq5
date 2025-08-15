//+------------------------------------------------------------------+
//|                                                  SecondEntry.mq5 |
//|                                   Al Brooks Second Entry Pattern |
//|                     Based on Price Action Trading Methodology    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots   8

// Indicator plot properties
#property indicator_label1  "H1 Signal"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrAqua
#property indicator_width1  2

#property indicator_label2  "H2 Signal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrLime
#property indicator_width2  3

#property indicator_label3  "L1 Signal"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrOrange
#property indicator_width3  2

#property indicator_label4  "L2 Signal"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrRed
#property indicator_width4  3

#property indicator_label5  "Primary EMA"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrOrange
#property indicator_width5  2

#property indicator_label6  "Secondary EMA"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrSilver
#property indicator_width6  1

#property indicator_label7  "New High"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  clrGreen
#property indicator_width7  1

#property indicator_label8  "New Low"
#property indicator_type8   DRAW_ARROW
#property indicator_color8  clrPurple
#property indicator_width8  1

//--- Input parameters
input bool     InpShowH1              = false;           // Show First Entry Long (H1)
input bool     InpShowL1              = false;           // Show First Entry Short (L1)
input bool     InpShowH2              = true;           // Show Second Entry Long (H2)
input bool     InpShowL2              = true;           // Show Second Entry Short (L2)
input bool     InpStrongSignalsOnly   = true;          // Show Strong Signals Only
input bool     InpWaitForClose        = true;           // Wait for candle to close
input int      InpPrimaryEMA          = 50;             // Primary EMA Period
input bool     InpShowSecondaryEMA    = false;          // Show Secondary EMA
input int      InpSecondaryEMA        = 20;             // Secondary EMA Period
input bool     InpShowNewHighLow      = true;          // Show New High/Low markers
input bool     InpEnableAlerts        = false;           // Enable Alert Notifications

//--- Range filtering parameters
input bool     InpFilterRanges        = true;           // Filter Trading Ranges
input double   InpMinBarSizeATR       = 0.5;            // Minimum Bar Size (ATR multiplier)
input int      InpRangeBarsThreshold  = 3;              // Consecutive Small Bars for Range
input double   InpRangeATRMultiplier  = 0.7;            // Range Detection ATR Multiplier
input int      InpATRPeriod           = 14;             // ATR Period for Range Detection

//--- SL/TP and Statistics parameters
input bool     InpShowSLTP            = true;           // Show Stop Loss/Take Profit Lines
input double   InpMinRiskReward       = 3.0;            // Minimum Risk:Reward Ratio
input bool     InpUseStructureTP      = true;           // Use Previous High/Low for TP
input bool     InpShowStatsPanel      = true;           // Show Statistics Panel
input int      InpMaxTradesToTrack    = 100;            // Maximum Trades to Track for Stats
input color    InpSLColor             = clrRed;         // Stop Loss Line Color
input color    InpTPColor             = clrLimeGreen;   // Take Profit Line Color
input int      InpPanelX              = 10;             // Stats Panel X Position
input int      InpPanelY              = 30;             // Stats Panel Y Position

//--- Al Brooks Quality Filters
input bool     InpUseTrendBarFilter   = true;           // Require Trend Bar (not doji)
input double   InpMinTrendBarRatio    = 0.6;            // Min Body/Range Ratio for Trend Bar
input bool     InpRequireEMAPosition  = true;           // Signal Bar Must Close Proper Side of EMA
input bool     InpRequireStrongClose  = true;           // Require Close in Top/Bottom Third
input int      InpMinConsecutiveBars  = 2;              // Min Consecutive Trend Bars Before Signal
input bool     InpWithTrendOnly       = true;           // Only Take With-Trend Entries
input double   InpMinBarSizeForSignal = 0.8;            // Min Bar Size (ATR) for Valid Signal

//--- Indicator buffers
double H1Buffer[];
double H2Buffer[];
double L1Buffer[];
double L2Buffer[];
double PrimaryEMABuffer[];
double SecondaryEMABuffer[];
double NewHighBuffer[];
double NewLowBuffer[];

//--- ATR buffer for range detection
double ATRBuffer[];

//--- Global variables for tracking
double highestHigh = 0;
double lowestLow = 0;
double legStart = 0;
double legExtreme = 0;
int legCount = 0;
int legDir = 0;  // 1 = up, -1 = down, 0 = none
int lastLegBar = -1;
bool waitForLegCompletion = false;
bool newHighDetected = false;
bool newLowDetected = false;

// Range detection variables
int consecutiveSmallBars = 0;
bool inTradingRange = false;
int rangeStartBar = -1;
double rangeHigh = 0;
double rangeLow = 0;

// Previous candle tracking for real-time updates
int lastProcessedBar = -1;
bool lastBullBias = false;
bool lastBearBias = false;

//--- Trade tracking structure
struct TradeEntry
{
   datetime entryTime;
   double entryPrice;
   double stopLoss;
   double takeProfit;
   bool isLong;
   bool isClosed;
   bool isWin;
   double result;  // in R multiples
};

//--- Trade statistics
TradeEntry trades[];
int totalTrades = 0;
int winningTrades = 0;
int losingTrades = 0;
double totalRMultiple = 0;
double avgWin = 0;
double avgLoss = 0;

//--- Panel object names
string panelPrefix = "SecondEntryStats_";

//--- Current active trade lines
string currentSLLine = "";
string currentTPLine = "";
double currentEntryPrice = 0;
double currentSL = 0;
double currentTP = 0;
bool currentIsLong = false;
datetime currentEntryTime = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Indicator buffers mapping
   SetIndexBuffer(0, H1Buffer, INDICATOR_DATA);
   SetIndexBuffer(1, H2Buffer, INDICATOR_DATA);
   SetIndexBuffer(2, L1Buffer, INDICATOR_DATA);
   SetIndexBuffer(3, L2Buffer, INDICATOR_DATA);
   SetIndexBuffer(4, PrimaryEMABuffer, INDICATOR_DATA);
   SetIndexBuffer(5, SecondaryEMABuffer, INDICATOR_DATA);
   SetIndexBuffer(6, NewHighBuffer, INDICATOR_DATA);
   SetIndexBuffer(7, NewLowBuffer, INDICATOR_DATA);
   
   //--- Set arrow codes
   PlotIndexSetInteger(0, PLOT_ARROW, 233);  // H1 - Up arrow
   PlotIndexSetInteger(1, PLOT_ARROW, 241);  // H2 - Thick up arrow
   PlotIndexSetInteger(2, PLOT_ARROW, 234);  // L1 - Down arrow
   PlotIndexSetInteger(3, PLOT_ARROW, 242);  // L2 - Thick down arrow
   PlotIndexSetInteger(6, PLOT_ARROW, 117);  // New High - small up triangle
   PlotIndexSetInteger(7, PLOT_ARROW, 118);  // New Low - small down triangle
   
   //--- Set arrow shifts
   PlotIndexSetInteger(0, PLOT_ARROW_SHIFT, -20);
   PlotIndexSetInteger(1, PLOT_ARROW_SHIFT, -30);
   PlotIndexSetInteger(2, PLOT_ARROW_SHIFT, 20);
   PlotIndexSetInteger(3, PLOT_ARROW_SHIFT, 30);
   PlotIndexSetInteger(6, PLOT_ARROW_SHIFT, 10);
   PlotIndexSetInteger(7, PLOT_ARROW_SHIFT, -10);
   
   //--- Set empty values
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0);
   PlotIndexSetDouble(6, PLOT_EMPTY_VALUE, 0);
   PlotIndexSetDouble(7, PLOT_EMPTY_VALUE, 0);
   
   //--- Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "Al Brooks Second Entry");
   
   //--- Initialize trade tracking array
   ArrayResize(trades, 0);
   
   //--- Create statistics panel
   CreateStatsPanel();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up all objects
   ObjectsDeleteAll(0, panelPrefix);
}

//+------------------------------------------------------------------+
//| Check if bar is small (inside trading range)                    |
//+------------------------------------------------------------------+
bool IsSmallBar(double high, double low, double atr)
{
   if(!InpFilterRanges || atr == 0)
      return false;
      
   double barSize = high - low;
   return (barSize < atr * InpRangeATRMultiplier);
}

//+------------------------------------------------------------------+
//| Check if bar meets minimum size requirement                     |
//+------------------------------------------------------------------+
bool IsValidSizeBar(double high, double low, double atr)
{
   if(!InpFilterRanges || atr == 0)
      return true;
      
   double barSize = high - low;
   return (barSize >= atr * InpMinBarSizeATR);
}

//+------------------------------------------------------------------+
//| Update trading range detection                                   |
//+------------------------------------------------------------------+
void UpdateRangeDetection(int index, double high, double low, double atr)
{
   if(!InpFilterRanges)
   {
      inTradingRange = false;
      return;
   }
   
   if(IsSmallBar(high, low, atr))
   {
      consecutiveSmallBars++;
      
      if(consecutiveSmallBars >= InpRangeBarsThreshold)
      {
         if(!inTradingRange)
         {
            inTradingRange = true;
            rangeStartBar = index - InpRangeBarsThreshold + 1;
            rangeHigh = high;
            rangeLow = low;
         }
         else
         {
            // Update range boundaries
            if(high > rangeHigh) rangeHigh = high;
            if(low < rangeLow) rangeLow = low;
         }
      }
   }
   else
   {
      // Large bar detected - check if it breaks out of range
      if(inTradingRange)
      {
         double barSize = high - low;
         bool breakout = (high > rangeHigh + atr * 0.5) || (low < rangeLow - atr * 0.5) || 
                        (barSize > atr * 1.5);
         
         if(breakout)
         {
            inTradingRange = false;
            consecutiveSmallBars = 0;
            rangeStartBar = -1;
         }
      }
      else
      {
         consecutiveSmallBars = 0;
      }
   }
}

//+------------------------------------------------------------------+
//| Check if we have a swing high                                   |
//+------------------------------------------------------------------+
bool IsSwingHigh(const double &high[], int index)
{
   if(index < 2 || index >= ArraySize(high) - 1)
      return false;
      
   return (high[index-1] > high[index-2] && high[index-1] > high[index]);
}

//+------------------------------------------------------------------+
//| Check if we have a swing low                                    |
//+------------------------------------------------------------------+
bool IsSwingLow(const double &low[], int index)
{
   if(index < 2 || index >= ArraySize(low) - 1)
      return false;
      
   return (low[index-1] < low[index-2] && low[index-1] < low[index]);
}

//+------------------------------------------------------------------+
//| Check if bar is a trend bar (not doji)                         |
//+------------------------------------------------------------------+
bool IsTrendBar(double open, double high, double low, double close, double atr)
{
   if(!InpUseTrendBarFilter)
      return true;
      
   double range = high - low;
   double body = MathAbs(close - open);
   
   // Check minimum bar size
   if(range < atr * InpMinBarSizeForSignal)
      return false;
   
   // Check body to range ratio
   if(range > 0 && body / range < InpMinTrendBarRatio)
      return false;
      
   return true;
}

//+------------------------------------------------------------------+
//| Check if bar closes in strong position                         |
//+------------------------------------------------------------------+
bool HasStrongClose(double open, double high, double low, double close, bool isLong)
{
   if(!InpRequireStrongClose)
      return true;
      
   double range = high - low;
   if(range == 0)
      return false;
      
   if(isLong)
   {
      // For long signals, close should be in top third
      return (close > low + range * 0.67);
   }
   else
   {
      // For short signals, close should be in bottom third
      return (close < high - range * 0.67);
   }
}

//+------------------------------------------------------------------+
//| Check EMA position requirement                                  |
//+------------------------------------------------------------------+
bool CheckEMAPosition(double close, double ema, bool isLong)
{
   if(!InpRequireEMAPosition)
      return true;
      
   if(isLong)
   {
      // For long signals, bar should close above EMA
      return close > ema;
   }
   else
   {
      // For short signals, bar should close below EMA
      return close < ema;
   }
}

//+------------------------------------------------------------------+
//| Count consecutive trend bars                                    |
//+------------------------------------------------------------------+
int CountConsecutiveTrendBars(const double &open[], const double &high[], 
                             const double &low[], const double &close[], 
                             int startIndex, bool isLong, int maxBars)
{
   int count = 0;
   
   for(int i = startIndex; i >= 0 && count < maxBars; i--)
   {
      if(i >= ArraySize(open))
         break;
         
      bool isBullBar = close[i] > open[i];
      bool isBearBar = close[i] < open[i];
      
      if(isLong && !isBullBar)
         break;
      if(!isLong && !isBearBar)
         break;
         
      count++;
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Send alert notification                                         |
//+------------------------------------------------------------------+
void SendSignalAlert(string signalType, int barIndex)
{
   if(!InpEnableAlerts)
      return;
      
   string message = StringFormat("%s signal detected at bar %d", signalType, barIndex);
   Alert(message);
}

//+------------------------------------------------------------------+
//| Calculate smart stop loss based on pullback extreme              |
//+------------------------------------------------------------------+
double CalculateSmartSL(bool isLong, double entryPrice, double pullbackExtreme, double atr)
{
   double buffer = atr * 0.2;  // Small buffer beyond extreme
   
   if(isLong)
   {
      // For longs, SL below the pullback low
      return pullbackExtreme - buffer;
   }
   else
   {
      // For shorts, SL above the pullback high
      return pullbackExtreme + buffer;
   }
}

//+------------------------------------------------------------------+
//| Calculate smart take profit                                      |
//+------------------------------------------------------------------+
double CalculateSmartTP(bool isLong, double entryPrice, double stopLoss, 
                        double previousHigh, double previousLow, double atr)
{
   double risk = MathAbs(entryPrice - stopLoss);
   double minTP = entryPrice + (isLong ? 1 : -1) * risk * InpMinRiskReward;
   
   if(InpUseStructureTP)
   {
      double structureTP;
      if(isLong)
      {
         // For longs, use previous high as potential TP
         structureTP = previousHigh;
         // Ensure minimum RR is met
         if(structureTP < minTP)
            structureTP = minTP;
      }
      else
      {
         // For shorts, use previous low as potential TP
         structureTP = previousLow;
         // Ensure minimum RR is met
         if(structureTP > minTP)
            structureTP = minTP;
      }
      return structureTP;
   }
   
   return minTP;
}

//+------------------------------------------------------------------+
//| Draw SL/TP lines                                                 |
//+------------------------------------------------------------------+
void DrawSLTPLines(datetime time1, datetime time2, double sl, double tp, bool isLong)
{
   // Only remove old lines when a new signal appears or trade is closed
   // Lines persist until hit or new signal
   
   // Create unique names for lines
   string newSLLine = panelPrefix + "SL_" + TimeToString(time1);
   string newTPLine = panelPrefix + "TP_" + TimeToString(time1);
   
   // Check if we're creating new lines (new signal)
   if(newSLLine != currentSLLine && currentSLLine != "")
   {
      // Remove old lines only when new signal appears
      ObjectDelete(0, currentSLLine);
      ObjectDelete(0, currentTPLine);
      ObjectDelete(0, StringSubstr(currentSLLine, 0, StringLen(currentSLLine)) + "_Label");
      ObjectDelete(0, StringSubstr(currentTPLine, 0, StringLen(currentTPLine)) + "_Label");
   }
   
   currentSLLine = newSLLine;
   currentTPLine = newTPLine;
   
   // Draw SL line (horizontal line that extends indefinitely)
   ObjectCreate(0, currentSLLine, OBJ_HLINE, 0, 0, sl);
   ObjectSetInteger(0, currentSLLine, OBJPROP_COLOR, InpSLColor);
   ObjectSetInteger(0, currentSLLine, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, currentSLLine, OBJPROP_STYLE, STYLE_DASH);
   
   // Draw TP line (horizontal line that extends indefinitely)
   ObjectCreate(0, currentTPLine, OBJ_HLINE, 0, 0, tp);
   ObjectSetInteger(0, currentTPLine, OBJPROP_COLOR, InpTPColor);
   ObjectSetInteger(0, currentTPLine, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, currentTPLine, OBJPROP_STYLE, STYLE_DASH);
   
   // Add text labels
   string slLabel = currentSLLine + "_Label";
   string tpLabel = currentTPLine + "_Label";
   
   ObjectCreate(0, slLabel, OBJ_TEXT, 0, time2, sl);
   ObjectSetString(0, slLabel, OBJPROP_TEXT, StringFormat("SL: %.5f", sl));
   ObjectSetInteger(0, slLabel, OBJPROP_COLOR, InpSLColor);
   ObjectSetInteger(0, slLabel, OBJPROP_ANCHOR, ANCHOR_LEFT);
   
   ObjectCreate(0, tpLabel, OBJ_TEXT, 0, time2, tp);
   ObjectSetString(0, tpLabel, OBJPROP_TEXT, StringFormat("TP: %.5f (%.1fR)", tp, InpMinRiskReward));
   ObjectSetInteger(0, tpLabel, OBJPROP_COLOR, InpTPColor);
   ObjectSetInteger(0, tpLabel, OBJPROP_ANCHOR, ANCHOR_LEFT);
}

//+------------------------------------------------------------------+
//| Remove SL/TP lines when trade closes                            |
//+------------------------------------------------------------------+
void RemoveSLTPLines()
{
   if(currentSLLine != "")
   {
      ObjectDelete(0, currentSLLine);
      ObjectDelete(0, currentTPLine);
      ObjectDelete(0, currentSLLine + "_Label");
      ObjectDelete(0, currentTPLine + "_Label");
      currentSLLine = "";
      currentTPLine = "";
   }
}

//+------------------------------------------------------------------+
//| Check if trade hit SL or TP                                      |
//+------------------------------------------------------------------+
void CheckTradeOutcome(int currentBar, const double &high[], const double &low[])
{
   if(currentEntryPrice == 0 || currentBar < 1)
      return;
   
   // Check if current bar hit SL or TP
   bool hitSL = false;
   bool hitTP = false;
   
   if(currentIsLong)
   {
      hitSL = low[currentBar] <= currentSL;
      hitTP = high[currentBar] >= currentTP;
   }
   else
   {
      hitSL = high[currentBar] >= currentSL;
      hitTP = low[currentBar] <= currentTP;
   }
   
   if(hitSL || hitTP)
   {
      // Record trade outcome
      int idx = ArraySize(trades);
      ArrayResize(trades, idx + 1);
      
      trades[idx].entryTime = currentEntryTime;
      trades[idx].entryPrice = currentEntryPrice;
      trades[idx].stopLoss = currentSL;
      trades[idx].takeProfit = currentTP;
      trades[idx].isLong = currentIsLong;
      trades[idx].isClosed = true;
      trades[idx].isWin = hitTP;
      
      double risk = MathAbs(currentEntryPrice - currentSL);
      if(hitTP)
      {
         trades[idx].result = MathAbs(currentTP - currentEntryPrice) / risk;
         winningTrades++;
      }
      else
      {
         trades[idx].result = -1.0;
         losingTrades++;
      }
      
      totalTrades++;
      totalRMultiple += trades[idx].result;
      
      // Remove SL/TP lines when trade closes
      RemoveSLTPLines();
      
      // Clear current trade
      currentEntryPrice = 0;
      currentSL = 0;
      currentTP = 0;
      currentIsLong = false;
      currentEntryTime = 0;
      
      // Update statistics
      UpdateStatistics();
   }
}

//+------------------------------------------------------------------+
//| Update statistics calculations                                   |
//+------------------------------------------------------------------+
void UpdateStatistics()
{
   if(totalTrades == 0)
      return;
   
   double sumWins = 0;
   double sumLosses = 0;
   int wins = 0;
   int losses = 0;
   
   for(int i = 0; i < ArraySize(trades); i++)
   {
      if(trades[i].isClosed)
      {
         if(trades[i].isWin)
         {
            sumWins += trades[i].result;
            wins++;
         }
         else
         {
            sumLosses += MathAbs(trades[i].result);
            losses++;
         }
      }
   }
   
   avgWin = wins > 0 ? sumWins / wins : 0;
   avgLoss = losses > 0 ? sumLosses / losses : 0;
}

//+------------------------------------------------------------------+
//| Create statistics panel                                          |
//+------------------------------------------------------------------+
void CreateStatsPanel()
{
   if(!InpShowStatsPanel)
      return;
   
   // Panel background
   string bgName = panelPrefix + "Background";
   ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, InpPanelX);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, InpPanelY);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 250);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, 200);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
   ObjectSetInteger(0, bgName, OBJPROP_COLOR, clrWhite);
   
   // Title
   CreatePanelLabel("Title", "H2/L2 Statistics", InpPanelX + 10, InpPanelY + 10, clrGold, 10);
   
   // Stats labels
   int yOffset = InpPanelY + 35;
   int lineHeight = 20;
   
   CreatePanelLabel("TotalTrades", "Total Trades: 0", InpPanelX + 10, yOffset, clrWhite, 9);
   yOffset += lineHeight;
   
   CreatePanelLabel("WinRate", "Win Rate: 0.0%", InpPanelX + 10, yOffset, clrLimeGreen, 9);
   yOffset += lineHeight;
   
   CreatePanelLabel("WinLoss", "Wins/Losses: 0/0", InpPanelX + 10, yOffset, clrWhite, 9);
   yOffset += lineHeight;
   
   CreatePanelLabel("AvgWin", "Avg Win: 0.0R", InpPanelX + 10, yOffset, clrLimeGreen, 9);
   yOffset += lineHeight;
   
   CreatePanelLabel("AvgLoss", "Avg Loss: 0.0R", InpPanelX + 10, yOffset, clrRed, 9);
   yOffset += lineHeight;
   
   CreatePanelLabel("ExpValue", "Expectancy: 0.0R", InpPanelX + 10, yOffset, clrYellow, 9);
   yOffset += lineHeight;
   
   CreatePanelLabel("TotalR", "Total R: 0.0", InpPanelX + 10, yOffset, clrAqua, 9);
}

//+------------------------------------------------------------------+
//| Create panel label                                               |
//+------------------------------------------------------------------+
void CreatePanelLabel(string name, string text, int x, int y, color clr, int fontSize)
{
   string objName = panelPrefix + name;
   ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetString(0, objName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
}

//+------------------------------------------------------------------+
//| Update statistics panel                                          |
//+------------------------------------------------------------------+
void UpdateStatsPanel()
{
   if(!InpShowStatsPanel)
      return;
   
   double winRate = totalTrades > 0 ? (double)winningTrades / totalTrades * 100 : 0;
   double expectancy = totalTrades > 0 ? totalRMultiple / totalTrades : 0;
   
   ObjectSetString(0, panelPrefix + "TotalTrades", OBJPROP_TEXT, 
                   StringFormat("Total Trades: %d", totalTrades));
   
   ObjectSetString(0, panelPrefix + "WinRate", OBJPROP_TEXT, 
                   StringFormat("Win Rate: %.1f%%", winRate));
   
   ObjectSetString(0, panelPrefix + "WinLoss", OBJPROP_TEXT, 
                   StringFormat("Wins/Losses: %d/%d", winningTrades, losingTrades));
   
   ObjectSetString(0, panelPrefix + "AvgWin", OBJPROP_TEXT, 
                   StringFormat("Avg Win: %.2fR", avgWin));
   
   ObjectSetString(0, panelPrefix + "AvgLoss", OBJPROP_TEXT, 
                   StringFormat("Avg Loss: %.2fR", avgLoss));
   
   ObjectSetString(0, panelPrefix + "ExpValue", OBJPROP_TEXT, 
                   StringFormat("Expectancy: %.2fR", expectancy));
   
   ObjectSetString(0, panelPrefix + "TotalR", OBJPROP_TEXT, 
                   StringFormat("Total R: %.1f", totalRMultiple));
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
   //--- Check for minimum bars
   int minBars = MathMax(InpPrimaryEMA + 2, InpATRPeriod + 1);
   if(rates_total < minBars)
      return(0);
      
   //--- Resize ATR buffer
   ArrayResize(ATRBuffer, rates_total);
   
   //--- Calculate starting position
   int start = 0;
   if(prev_calculated > 0)
      start = prev_calculated - 1;
   else
      start = minBars;
      
   //--- Calculate ATR first (needed for range detection)
   for(int i = 0; i < rates_total; i++)
   {
      if(i == 0)
      {
         ATRBuffer[i] = high[i] - low[i];
      }
      else if(i < InpATRPeriod)
      {
         double sum = 0;
         for(int j = 0; j <= i; j++)
         {
            double tr = MathMax(high[j] - low[j], 
                       MathMax(MathAbs(high[j] - close[j > 0 ? j-1 : 0]), 
                               MathAbs(low[j] - close[j > 0 ? j-1 : 0])));
            sum += tr;
         }
         ATRBuffer[i] = sum / (i + 1);
      }
      else
      {
         double tr = MathMax(high[i] - low[i], 
                    MathMax(MathAbs(high[i] - close[i-1]), 
                            MathAbs(low[i] - close[i-1])));
         ATRBuffer[i] = ((InpATRPeriod - 1) * ATRBuffer[i-1] + tr) / InpATRPeriod;
      }
   }
   
   //--- Calculate Primary EMA
   for(int i = start; i < rates_total; i++)
   {
      if(i == InpPrimaryEMA)
      {
         // Simple average for the first value
         double sum = 0;
         for(int j = 0; j < InpPrimaryEMA; j++)
            sum += close[i - j];
         PrimaryEMABuffer[i] = sum / InpPrimaryEMA;
      }
      else if(i > InpPrimaryEMA)
      {
         double alpha = 2.0 / (InpPrimaryEMA + 1.0);
         PrimaryEMABuffer[i] = alpha * close[i] + (1 - alpha) * PrimaryEMABuffer[i-1];
      }
   }
   
   //--- Calculate Secondary EMA if needed
   if(InpShowSecondaryEMA)
   {
      for(int i = start; i < rates_total; i++)
      {
         if(i == InpSecondaryEMA)
         {
            double sum = 0;
            for(int j = 0; j < InpSecondaryEMA; j++)
               sum += close[i - j];
            SecondaryEMABuffer[i] = sum / InpSecondaryEMA;
         }
         else if(i > InpSecondaryEMA)
         {
            double alpha = 2.0 / (InpSecondaryEMA + 1.0);
            SecondaryEMABuffer[i] = alpha * close[i] + (1 - alpha) * SecondaryEMABuffer[i-1];
         }
      }
   }
   
   //--- Main signal processing
   for(int i = MathMax(start, InpPrimaryEMA + 2); i < rates_total; i++)
   {
      // Clear buffers
      H1Buffer[i] = 0;
      H2Buffer[i] = 0;
      L1Buffer[i] = 0;
      L2Buffer[i] = 0;
      NewHighBuffer[i] = 0;
      NewLowBuffer[i] = 0;
      
      // Skip if waiting for close and current bar is still forming
      if(InpWaitForClose && i == rates_total - 1)
         continue;
      
      // Update range detection
      UpdateRangeDetection(i, high[i], low[i], ATRBuffer[i]);
      
      // Skip signals if we're in a trading range
      if(inTradingRange && InpFilterRanges)
         continue;
      
      // Check if current bar is too small to be meaningful
      if(!IsValidSizeBar(high[i], low[i], ATRBuffer[i]) && InpFilterRanges)
         continue;
         
      // Determine trend bias
      bool bullBias = close[i] > PrimaryEMABuffer[i];
      bool bearBias = close[i] < PrimaryEMABuffer[i];
      
      // Check for bias change
      bool bullBiasPrev = (i > 0) ? close[i-1] > PrimaryEMABuffer[i-1] : false;
      bool bearBiasPrev = (i > 0) ? close[i-1] < PrimaryEMABuffer[i-1] : false;
      bool biasChanged = (bullBias && !bullBiasPrev) || (bearBias && !bearBiasPrev);
      
      // Reset on bias change
      if(biasChanged)
      {
         legCount = 0;
         legDir = 0;
         legStart = 0;
         legExtreme = 0;
         lastLegBar = -1;
         waitForLegCompletion = false;
         newHighDetected = false;
         newLowDetected = false;
         
         if(bullBias)
         {
            highestHigh = high[i];
            lowestLow = 0;
         }
         else
         {
            lowestLow = low[i];
            highestHigh = 0;
         }
      }
      
      //--- BULL TREND LOGIC
      if(bullBias)
      {
         // Track highest high (only count meaningful bars)
         bool isValidBar = !InpFilterRanges || IsValidSizeBar(high[i], low[i], ATRBuffer[i]);
         
         if(isValidBar && (highestHigh == 0 || high[i] > highestHigh))
         {
            highestHigh = high[i];
            newHighDetected = true;
            if(InpShowNewHighLow)
               NewHighBuffer[i] = high[i];
         }
         else
         {
            newHighDetected = false;
         }
         
         // Reset on new high
         if(newHighDetected)
         {
            legCount = 0;
            legDir = 0;
            legStart = 0;
            legExtreme = 0;
            waitForLegCompletion = false;
         }
         
         // Track pullback (downleg) - only count meaningful price moves
         bool validDownMove = i > 0 && high[i] < high[i-1] && low[i] < low[i-1];
         bool validBarSize = !InpFilterRanges || IsValidSizeBar(high[i], low[i], ATRBuffer[i]);
         
         if(validDownMove && validBarSize)
         {
            if(legDir != -1)  // Starting new downleg
            {
               legCount = (legCount == 0) ? 1 : 2;
               legDir = -1;
               legStart = high[i-1];
               legExtreme = low[i];
               waitForLegCompletion = true;
            }
            else
            {
               // Continue existing downleg
               if(low[i] < legExtreme || legExtreme == 0)
                  legExtreme = low[i];
            }
            lastLegBar = i;
         }
         
         // Check for end of downleg and potential H1/H2 signals
         if(i > 0 && legDir == -1 && high[i] > high[i-1])
         {
            // Generate H1/H2 signals
            if(legCount == 1)
            {
               if(InpShowH1 && waitForLegCompletion)
               {
                  H1Buffer[i] = low[i];
                  SendSignalAlert("H1", i);
               }
               legDir = 0;  // Reset direction
            }
            else if(legCount == 2)
            {
               bool strongSignal = true;
               
               // Al Brooks quality filters
               bool passesFilters = true;
               
               // 1. Check if signal bar is a trend bar
               if(!IsTrendBar(open[i], high[i], low[i], close[i], ATRBuffer[i]))
                  passesFilters = false;
               
               // 2. Check strong close position
               if(!HasStrongClose(open[i], high[i], low[i], close[i], true))
                  passesFilters = false;
               
               // 3. Check EMA position
               if(!CheckEMAPosition(close[i], PrimaryEMABuffer[i], true))
                  passesFilters = false;
               
               // 4. Check consecutive trend bars before signal
               if(i > 0)
               {
                  int consecBars = CountConsecutiveTrendBars(open, high, low, close, i-1, true, 5);
                  if(consecBars < InpMinConsecutiveBars)
                     passesFilters = false;
               }
               
               // 5. With-trend only filter
               if(InpWithTrendOnly)
               {
                  // For longs, we want overall uptrend (higher highs)
                  if(i > 20 && high[i] < high[ArrayMaximum(high, i-20, 20)])
                     passesFilters = false;
               }
               
               if(InpStrongSignalsOnly)
               {
                  // Original strong signal criteria
                  double range = high[i] - low[i];
                  bool isBullish = close[i] > open[i];
                  bool closesHigh = close[i] > (high[i] - range * 0.3);
                  bool higherClose = close[i] > close[i-1];
                  strongSignal = isBullish && closesHigh && higherClose;
               }
               
               if(InpShowH2 && waitForLegCompletion && strongSignal && passesFilters)
               {
                  H2Buffer[i] = low[i];
                  SendSignalAlert("H2", i);
                  
                  // Calculate and draw SL/TP for H2 signals
                  if(InpShowSLTP)
                  {
                     double entryPrice = close[i];
                     double sl = CalculateSmartSL(true, entryPrice, legExtreme, ATRBuffer[i]);
                     double tp = CalculateSmartTP(true, entryPrice, sl, highestHigh, lowestLow, ATRBuffer[i]);
                     
                     DrawSLTPLines(time[i], time[i] + PeriodSeconds() * 20, sl, tp, true);
                     
                     // Store current trade info
                     currentEntryPrice = entryPrice;
                     currentSL = sl;
                     currentTP = tp;
                     currentIsLong = true;
                     currentEntryTime = time[i];
                  }
               }
            }
            waitForLegCompletion = false;
         }
      }
      
      //--- BEAR TREND LOGIC
      if(bearBias)
      {
         // Track lowest low (only count meaningful bars)
         bool isValidBar = !InpFilterRanges || IsValidSizeBar(high[i], low[i], ATRBuffer[i]);
         
         if(isValidBar && (lowestLow == 0 || low[i] < lowestLow))
         {
            lowestLow = low[i];
            newLowDetected = true;
            if(InpShowNewHighLow)
               NewLowBuffer[i] = low[i];
         }
         else
         {
            newLowDetected = false;
         }
         
         // Reset on new low
         if(newLowDetected)
         {
            legCount = 0;
            legDir = 0;
            legStart = 0;
            legExtreme = 0;
            waitForLegCompletion = false;
         }
         
         // Track pullback (upleg) - only count meaningful price moves
         bool validUpMove = i > 0 && low[i] > low[i-1] && high[i] > high[i-1];
         bool validBarSize = !InpFilterRanges || IsValidSizeBar(high[i], low[i], ATRBuffer[i]);
         
         if(validUpMove && validBarSize)
         {
            if(legDir != 1)  // Starting new upleg
            {
               legCount = (legCount == 0) ? 1 : 2;
               legDir = 1;
               legStart = low[i-1];
               legExtreme = high[i];
               waitForLegCompletion = true;
            }
            else
            {
               // Continue existing upleg
               if(high[i] > legExtreme || legExtreme == 0)
                  legExtreme = high[i];
            }
            lastLegBar = i;
         }
         
         // Check for end of upleg and potential L1/L2 signals
         if(i > 0 && legDir == 1 && low[i] < low[i-1])
         {
            // Generate L1/L2 signals
            if(legCount == 1)
            {
               if(InpShowL1 && waitForLegCompletion)
               {
                  L1Buffer[i] = high[i];
                  SendSignalAlert("L1", i);
               }
               legDir = 0;  // Reset direction
            }
            else if(legCount == 2)
            {
               bool strongSignal = true;
               
               // Al Brooks quality filters
               bool passesFilters = true;
               
               // 1. Check if signal bar is a trend bar
               if(!IsTrendBar(open[i], high[i], low[i], close[i], ATRBuffer[i]))
                  passesFilters = false;
               
               // 2. Check strong close position
               if(!HasStrongClose(open[i], high[i], low[i], close[i], false))
                  passesFilters = false;
               
               // 3. Check EMA position
               if(!CheckEMAPosition(close[i], PrimaryEMABuffer[i], false))
                  passesFilters = false;
               
               // 4. Check consecutive trend bars before signal
               if(i > 0)
               {
                  int consecBars = CountConsecutiveTrendBars(open, high, low, close, i-1, false, 5);
                  if(consecBars < InpMinConsecutiveBars)
                     passesFilters = false;
               }
               
               // 5. With-trend only filter
               if(InpWithTrendOnly)
               {
                  // For shorts, we want overall downtrend (lower lows)
                  if(i > 20 && low[i] > low[ArrayMinimum(low, i-20, 20)])
                     passesFilters = false;
               }
               
               if(InpStrongSignalsOnly)
               {
                  // Original strong signal criteria
                  double range = high[i] - low[i];
                  bool isBearish = close[i] < open[i];
                  bool closesLow = close[i] < (low[i] + range * 0.3);
                  bool lowerClose = close[i] < close[i-1];
                  strongSignal = isBearish && closesLow && lowerClose;
               }
               
               if(InpShowL2 && waitForLegCompletion && strongSignal && passesFilters)
               {
                  L2Buffer[i] = high[i];
                  SendSignalAlert("L2", i);
                  
                  // Calculate and draw SL/TP for L2 signals
                  if(InpShowSLTP)
                  {
                     double entryPrice = close[i];
                     double sl = CalculateSmartSL(false, entryPrice, legExtreme, ATRBuffer[i]);
                     double tp = CalculateSmartTP(false, entryPrice, sl, highestHigh, lowestLow, ATRBuffer[i]);
                     
                     DrawSLTPLines(time[i], time[i] + PeriodSeconds() * 20, sl, tp, false);
                     
                     // Store current trade info
                     currentEntryPrice = entryPrice;
                     currentSL = sl;
                     currentTP = tp;
                     currentIsLong = false;
                     currentEntryTime = time[i];
                  }
               }
            }
            waitForLegCompletion = false;
         }
      }
      
      // Check if any active trade hit SL or TP
      if(currentEntryPrice > 0)
      {
         CheckTradeOutcome(i, high, low);
      }
   }
   
   // Update statistics panel
   UpdateStatsPanel();
   
   return(rates_total);
}
//+------------------------------------------------------------------+