//+------------------------------------------------------------------+
//|                                          SupportResistance.mq5   |
//|                     Advanced Support & Resistance Indicator      |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "2.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

// Input parameters - Detection Settings
input group "═══ Detection Settings ═══"
input int      InpLeftBars = 5;                     // Left Bars for Pivot Detection
input int      InpRightBars = 5;                    // Right Bars for Pivot Detection
input int      InpMaxLookback = 500;                // Maximum Bars to Analyze
input double   InpZoneMergeDistance = 0.0008;       // Zone Merge Distance (%)
input int      InpMinTouches = 2;                   // Minimum Touches for Strong Level
input double   InpZoneWidth = 0.0003;               // S/R Zone Width (%)
input double   InpMaxDistanceFromPrice = 0.05;      // Max Distance from Current Price (5%)
input int      InpMinPivotStrength = 2;             // Minimum Pivot Strength (1-15)

// Input parameters - Volume Settings
input group "═══ Volume Analysis ═══"
input bool     InpUseVolume = true;                 // Use Volume Filter
input double   InpVolumeThreshold = 20.0;           // Volume Threshold (%)
input int      InpVolumeEMAShort = 5;               // Volume EMA Short Period
input int      InpVolumeEMALong = 10;               // Volume EMA Long Period

// Input parameters - Multi-Timeframe
input group "═══ Multi-Timeframe ═══"
input bool     InpUseMTF = true;                    // Use Multi-Timeframe Analysis
input ENUM_TIMEFRAMES InpHigherTF = PERIOD_H4;      // Higher Timeframe

// Input parameters - Break Detection
input group "═══ Break Detection ═══"
input bool     InpShowBreaks = true;                // Show Break Signals
input bool     InpRequireVolumeForBreak = true;     // Require Volume for Breaks
input double   InpBreakBuffer = 0.0001;             // Break Buffer (%)
input bool     InpShowWicks = true;                 // Show Wick Rejections

// Input parameters - Visual Settings
input group "═══ Visual Settings ═══"
input color    InpStrongResistanceColor = clrRed;   // Strong Resistance Color
input color    InpWeakResistanceColor = clrLightCoral; // Weak Resistance Color
input color    InpStrongSupportColor = clrBlue;     // Strong Support Color
input color    InpWeakSupportColor = clrLightBlue;  // Weak Support Color
input int      InpMaxLevels = 10;                   // Maximum Levels to Display
input bool     InpShowLabels = true;                // Show Level Labels
input bool     InpShowStatistics = true;            // Show Statistics Panel

// Input parameters - Alerts
input group "═══ Alert Settings ═══"
input bool     InpEnableAlerts = true;              // Enable Alerts
input bool     InpAlertBreaks = true;               // Alert on Level Breaks
input bool     InpAlertNewLevels = true;            // Alert on New Levels
input bool     InpAlertTouches = true;              // Alert on Level Touches
input bool     InpSendNotification = false;         // Send Push Notifications
input bool     InpSendEmail = false;                // Send Email Alerts

// No buffers needed - using graphical objects only

// Structure for S/R levels
struct SRLevel
{
   double price;
   int touches;
   datetime firstSeen;
   datetime lastTested;
   bool isResistance;
   double strength;
   int timeframe;
   bool isBroken;         // Track if level has been broken
   datetime brokenTime;   // When it was broken
   bool hasFlipped;       // Has this level flipped from R to S or S to R
   int flipCount;         // Number of times it has flipped
   int retestCount;       // Number of successful retests after flip
};

// Global variables
SRLevel levels[];
int levelCount = 0;
double volumeOsc = 0;
datetime lastAlertTime = 0;
int statsHandle = INVALID_HANDLE;

// Statistics tracking
struct Statistics
{
   int totalBreaks;
   int successfulBreaks;
   int falseBreaks;
   int totalTouches;
   double avgHoldTime;
   double winRate;
};

Statistics stats;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize level array
   ArrayResize(levels, 100);
   levelCount = 0;
   
   // Initialize statistics
   stats.totalBreaks = 0;
   stats.successfulBreaks = 0;
   stats.falseBreaks = 0;
   stats.totalTouches = 0;
   stats.avgHoldTime = 0;
   stats.winRate = 0;
   
   // Set indicator name
   string shortName = StringFormat("S/R Advanced (L:%d, R:%d, Vol:%d%%)", 
                                   InpLeftBars, InpRightBars, (int)InpVolumeThreshold);
   IndicatorSetString(INDICATOR_SHORTNAME, shortName);
   
   // Create statistics panel if enabled
   if(InpShowStatistics)
      CreateStatisticsPanel();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up all S/R objects
   ObjectsDeleteAll(0, "SR_Label_");
   ObjectsDeleteAll(0, "SR_Line_");
   ObjectsDeleteAll(0, "SR_Stats_");
   
   // Delete statistics panel
   if(InpShowStatistics)
      DeleteStatisticsPanel();
   
   // Redraw chart
   ChartRedraw();
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
   // Check for minimum bars
   if(rates_total < InpLeftBars + InpRightBars + 1)
      return(0);
   
   // Set array series
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(tick_volume, true);
   ArraySetAsSeries(volume, true);
   
   // Reset levels completely every time to ensure we catch everything
   levelCount = 0;
   
   // Get current price for reference
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // First pass: Find ALL local highs and lows with minimal requirements
   int scanLimit = MathMin(InpMaxLookback, rates_total - 1);
   
   // Scan for swing points - Start from most recent and work backwards
   for(int i = 3; i < scanLimit - 3; i++)  // Start at bar 3 to have room for checking
   {
      // Simple swing high detection - minimum 3 bars each side
      bool isSwingHigh = true;
      bool isSwingLow = true;
      
      // For swing high: check if this bar's high is higher than surrounding bars
      double highValue = high[i];
      double lowValue = low[i];
      
      // Check left side (more recent bars - indices 0,1,2)
      for(int j = 0; j < i && j < 3; j++)
      {
         if(high[j] >= highValue)
         {
            isSwingHigh = false;
            break;
         }
      }
      
      // Check right side (older bars)
      for(int j = i + 1; j <= i + 3 && j < rates_total; j++)
      {
         if(high[j] >= highValue)
         {
            isSwingHigh = false;
            break;
         }
      }
      
      // For swing low: check if this bar's low is lower than surrounding bars
      // Check left side (more recent bars)
      for(int j = 0; j < i && j < 3; j++)
      {
         if(low[j] <= lowValue)
         {
            isSwingLow = false;
            break;
         }
      }
      
      // Check right side (older bars)
      for(int j = i + 1; j <= i + 3 && j < rates_total; j++)
      {
         if(low[j] <= lowValue)
         {
            isSwingLow = false;
            break;
         }
      }
      
      // Process swing points
      if(isSwingHigh)
      {
         double price = highValue;
         // Only process if within reasonable distance
         if(MathAbs(price - currentPrice) / currentPrice < InpMaxDistanceFromPrice)
         {
            ProcessNewLevel(price, price > currentPrice, time[i]);
         }
      }
      
      if(isSwingLow)
      {
         double price = lowValue;
         // Only process if within reasonable distance
         if(MathAbs(price - currentPrice) / currentPrice < InpMaxDistanceFromPrice)
         {
            ProcessNewLevel(price, price > currentPrice, time[i]);
         }
      }
   }
   
   // Second pass: Find price clusters in recent action
   ScanForPriceClusters(high, low, close, time, currentPrice);
   
   // Check for level breaks and role reversals
   for(int i = 1; i < MathMin(100, rates_total); i++)
   {
      CheckForBreaks(i, high, low, close, open, time);
   }
   
   // Multi-timeframe analysis
   if(InpUseMTF)
      AnalyzeHigherTimeframe();
   
   // Update statistics panel
   if(InpShowStatistics && prev_calculated != rates_total)
      UpdateStatisticsPanel();
   
   // Draw level labels and lines
   DrawLevelLabels();
   
   // Debug output
   static int lastLevelCount = 0;
   static datetime lastDebugTime = 0;
   
   // Print detailed info about levels
   if(levelCount != lastLevelCount || TimeCurrent() - lastDebugTime > 30)
   {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      Print("S/R Update: ", levelCount, " levels, Current Price=", currentPrice,
            ", Scanned ", scanLimit, " bars");
      
      // Show all current levels
      for(int i = 0; i < levelCount && i < 10; i++)
      {
         Print("Level ", i, ": ", levels[i].price, 
               " (", levels[i].isResistance ? "R" : "S", ")",
               " T:", levels[i].touches,
               " S:", DoubleToString(levels[i].strength, 2),
               " Flip:", levels[i].hasFlipped);
      }
      
      lastLevelCount = levelCount;
      lastDebugTime = TimeCurrent();
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Detect pivot high with variable strength                        |
//+------------------------------------------------------------------+
double DetectPivotHigh(const double &high[], int index)
{
   // Try different pivot strengths, starting from the configured bars down to minimum
   for(int strength = InpLeftBars; strength >= InpMinPivotStrength; strength--)
   {
      // Can't be a pivot if we're too close to the edges
      if(index - strength < 0 || index + strength >= ArraySize(high))
         continue;
         
      double pivotPrice = high[index];
      bool isPivot = true;
      
      // Check left side (older bars - higher indices in series array)
      for(int i = 1; i <= strength; i++)
      {
         if(high[index + i] >= pivotPrice)
         {
            isPivot = false;
            break;
         }
      }
      
      if(!isPivot) continue;
      
      // Check right side (newer bars - lower indices in series array)
      for(int i = 1; i <= strength; i++)
      {
         if(high[index - i] > pivotPrice)
         {
            isPivot = false;
            break;
         }
      }
      
      if(isPivot)
         return pivotPrice;
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Detect pivot low with variable strength                         |
//+------------------------------------------------------------------+
double DetectPivotLow(const double &low[], int index)
{
   // Try different pivot strengths, starting from the configured bars down to minimum
   for(int strength = InpLeftBars; strength >= InpMinPivotStrength; strength--)
   {
      // Can't be a pivot if we're too close to the edges
      if(index - strength < 0 || index + strength >= ArraySize(low))
         continue;
         
      double pivotPrice = low[index];
      bool isPivot = true;
      
      // Check left side (older bars - higher indices in series array)
      for(int i = 1; i <= strength; i++)
      {
         if(low[index + i] <= pivotPrice)
         {
            isPivot = false;
            break;
         }
      }
      
      if(!isPivot) continue;
      
      // Check right side (newer bars - lower indices in series array)
      for(int i = 1; i <= strength; i++)
      {
         if(low[index - i] < pivotPrice)
         {
            isPivot = false;
            break;
         }
      }
      
      if(isPivot)
         return pivotPrice;
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Process new S/R level                                           |
//+------------------------------------------------------------------+
void ProcessNewLevel(double price, bool isResistance, datetime time)
{
   // Get current price to filter out distant levels
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double priceDistance = MathAbs(price - currentPrice) / currentPrice;
   
   // Skip levels that are too far from current price
   if(priceDistance > InpMaxDistanceFromPrice)
   {
      return;
   }
   
   // Check if level already exists or merge with nearby level
   for(int i = 0; i < levelCount; i++)
   {
      double distance = MathAbs(levels[i].price - price) / price;
      if(distance < InpZoneMergeDistance)
      {
         // Only update if this is a more recent test
         if(time > levels[i].lastTested)
         {
            levels[i].touches++;
            levels[i].lastTested = time;
            levels[i].strength = CalculateLevelStrength(levels[i]);
         }
         return;
      }
   }
   
   // Add new level if under maximum
   if(levelCount < InpMaxLevels)
   {
      levels[levelCount].price = price;
      levels[levelCount].touches = 1;
      levels[levelCount].firstSeen = time;
      levels[levelCount].lastTested = time;
      levels[levelCount].isResistance = isResistance;
      levels[levelCount].strength = 0.5;
      levels[levelCount].timeframe = Period();
      levels[levelCount].isBroken = false;
      levels[levelCount].brokenTime = 0;
      levels[levelCount].hasFlipped = false;
      levels[levelCount].flipCount = 0;
      levels[levelCount].retestCount = 0;
      levelCount++;
      
      // Alert for new level
      if(InpEnableAlerts && InpAlertNewLevels)
      {
         string msg = StringFormat("New %s level at %.5f", 
                                  isResistance ? "Resistance" : "Support", price);
         SendAlert(msg);
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate level strength                                        |
//+------------------------------------------------------------------+
double CalculateLevelStrength(SRLevel &level)
{
   double strength = 0;
   
   // Factor 1: Number of touches (max contribution: 0.2)
   strength += MathMin(0.2, level.touches * 0.05);
   
   // Factor 2: Age of level (max contribution: 0.15)
   int ageBars = (int)((TimeCurrent() - level.firstSeen) / PeriodSeconds());
   strength += MathMin(0.15, ageBars / 1000.0);
   
   // Factor 3: Recent testing (max contribution: 0.15)
   int recentBars = (int)((TimeCurrent() - level.lastTested) / PeriodSeconds());
   if(recentBars < 100)
      strength += 0.15 * (1.0 - recentBars / 100.0);
   
   // Factor 4: Volume at level (max contribution: 0.2)
   if(InpUseVolume && volumeOsc > InpVolumeThreshold)
      strength += 0.2;
   
   // Factor 5: Role reversal bonus (max contribution: 0.3)
   if(level.hasFlipped)
   {
      // Flipped levels that successfully retest are very strong
      strength += 0.1; // Base bonus for flipping
      strength += MathMin(0.2, level.retestCount * 0.1); // Bonus for successful retests
   }
   
   return MathMin(1.0, strength);
}


//+------------------------------------------------------------------+
//| Check for level breaks and role reversals                       |
//+------------------------------------------------------------------+
void CheckForBreaks(int index, const double &high[], const double &low[], 
                   const double &close[], const double &open[], const datetime &time[])
{
   for(int i = 0; i < levelCount; i++)
   {
      double level = levels[i].price;
      double breakBuffer = level * InpBreakBuffer;
      
      // Check for breaks and role reversals
      if(levels[i].isResistance)
      {
         // Resistance level
         if(close[index] > level + breakBuffer && close[index + 1] <= level)
         {
            // Check volume condition
            if(!InpRequireVolumeForBreak || volumeOsc > InpVolumeThreshold)
            {
               // Resistance broken - flip to support
               levels[i].isResistance = false;  // Now becomes support
               levels[i].hasFlipped = true;
               levels[i].flipCount++;
               levels[i].brokenTime = time[index];
               levels[i].strength = MathMax(0.5, levels[i].strength * 0.8); // Reduce strength slightly
               stats.totalBreaks++;
               
               // Alert
               if(InpEnableAlerts && InpAlertBreaks)
               {
                  string msg = StringFormat("Resistance broken at %.5f - Now Support", level);
                  SendAlert(msg);
               }
            }
         }
      }
      else
      {
         // Support level
         if(close[index] < level - breakBuffer && close[index + 1] >= level)
         {
            // Check volume condition
            if(!InpRequireVolumeForBreak || volumeOsc > InpVolumeThreshold)
            {
               // Support broken - flip to resistance
               levels[i].isResistance = true;  // Now becomes resistance
               levels[i].hasFlipped = true;
               levels[i].flipCount++;
               levels[i].brokenTime = time[index];
               levels[i].strength = MathMax(0.5, levels[i].strength * 0.8); // Reduce strength slightly
               stats.totalBreaks++;
               
               // Alert
               if(InpEnableAlerts && InpAlertBreaks)
               {
                  string msg = StringFormat("Support broken at %.5f - Now Resistance", level);
                  SendAlert(msg);
               }
            }
         }
      }
      
      // Check for successful retests after flip
      if(levels[i].hasFlipped)
      {
         CheckForRetest(i, index, high, low, close, time);
      }
   }
}


//+------------------------------------------------------------------+
//| Scan for price clusters in recent price action                  |
//+------------------------------------------------------------------+
void ScanForPriceClusters(const double &high[], const double &low[], const double &close[],
                          const datetime &time[], double currentPrice)
{
   // Focus on recent 200 bars for cluster detection
   int scanBars = MathMin(200, ArraySize(high));
   
   // Price level counting - use tighter increments
   double priceStep = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10; // 10 point increments
   
   // Find price range to scan - focus on nearby levels
   double rangeHigh = currentPrice * 1.02;  // 2% above
   double rangeLow = currentPrice * 0.98;   // 2% below
   
   // Also find actual high/low from recent bars for better range
   double recentHigh = high[0];
   double recentLow = low[0];
   for(int i = 1; i < MathMin(100, ArraySize(high)); i++)
   {
      if(high[i] > recentHigh) recentHigh = high[i];
      if(low[i] < recentLow) recentLow = low[i];
   }
   
   // Adjust range based on recent price action
   rangeHigh = MathMax(rangeHigh, recentHigh * 1.01);
   rangeLow = MathMin(rangeLow, recentLow * 0.99);
   
   // Count touches at each price level
   for(double level = rangeLow; level <= rangeHigh; level += priceStep)
   {
      int touches = 0;
      int bounces = 0;
      datetime lastTouch = 0;
      
      // Count how many times price touched this level
      for(int i = 0; i < scanBars; i++)
      {
         // Check if high touched this level (potential resistance)
         if(MathAbs(high[i] - level) < priceStep * 1.5)
         {
            touches++;
            // Check if price bounced down from this level
            if(i > 0 && close[i] < level && close[i-1] > close[i])
               bounces++;
            if(time[i] > lastTouch)
               lastTouch = time[i];
         }
         // Check if low touched this level (potential support)
         else if(MathAbs(low[i] - level) < priceStep * 1.5)
         {
            touches++;
            // Check if price bounced up from this level
            if(i > 0 && close[i] > level && close[i-1] < close[i])
               bounces++;
            if(time[i] > lastTouch)
               lastTouch = time[i];
         }
      }
      
      // If we have enough touches OR strong bounces, add as a level
      if(touches >= 2 || bounces >= 1)  // Lowered threshold for better detection
      {
         bool isResistance = (level > currentPrice);
         ProcessNewLevel(level, isResistance, lastTouch);
      }
   }
}

//+------------------------------------------------------------------+
//| Detect horizontal price clusters                                |
//+------------------------------------------------------------------+
void DetectHorizontalClusters(int currentBar, const double &high[], const double &low[], 
                              const double &close[], const datetime &time[])
{
   // Look for price areas that have been touched multiple times
   int lookback = MathMin(100, currentBar);
   
   // Create price bins (round to nearest pip level)
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double binSize = point * 10; // 10 pips per bin
   
   // Count touches at each price level
   int touches[];
   double priceLevels[];
   datetime lastTouch[];
   int binCount = 0;
   
   ArrayResize(touches, 1000);
   ArrayResize(priceLevels, 1000);
   ArrayResize(lastTouch, 1000);
   
   // Scan recent price action
   for(int i = currentBar; i < currentBar + lookback && i < ArraySize(high); i++)
   {
      // Check high
      double highBin = MathRound(high[i] / binSize) * binSize;
      bool found = false;
      
      for(int j = 0; j < binCount; j++)
      {
         if(MathAbs(priceLevels[j] - highBin) < binSize / 2)
         {
            touches[j]++;
            lastTouch[j] = time[i];
            found = true;
            break;
         }
      }
      
      if(!found && binCount < 999)
      {
         priceLevels[binCount] = highBin;
         touches[binCount] = 1;
         lastTouch[binCount] = time[i];
         binCount++;
      }
      
      // Check low
      double lowBin = MathRound(low[i] / binSize) * binSize;
      found = false;
      
      for(int j = 0; j < binCount; j++)
      {
         if(MathAbs(priceLevels[j] - lowBin) < binSize / 2)
         {
            touches[j]++;
            lastTouch[j] = time[i];
            found = true;
            break;
         }
      }
      
      if(!found && binCount < 999)
      {
         priceLevels[binCount] = lowBin;
         touches[binCount] = 1;
         lastTouch[binCount] = time[i];
         binCount++;
      }
   }
   
   // Process bins with multiple touches
   for(int i = 0; i < binCount; i++)
   {
      if(touches[i] >= 2) // At least 2 touches to be significant
      {
         // Determine if it's resistance or support based on current price
         double currentPrice = close[currentBar];
         bool isResistance = (priceLevels[i] > currentPrice);
         
         // Process as a new level
         ProcessNewLevel(priceLevels[i], isResistance, lastTouch[i]);
      }
   }
}

//+------------------------------------------------------------------+
//| Check for successful retest after role reversal                 |
//+------------------------------------------------------------------+
void CheckForRetest(int levelIndex, int barIndex, const double &high[], 
                   const double &low[], const double &close[], const datetime &time[])
{
   double level = levels[levelIndex].price;
   double testBuffer = level * 0.002; // 0.2% buffer for retest
   
   if(levels[levelIndex].isResistance)
   {
      // Now resistance (was support) - check if it holds as resistance
      if(high[barIndex] >= level - testBuffer && close[barIndex] < level)
      {
         // Successful retest as resistance
         levels[levelIndex].retestCount++;
         levels[levelIndex].lastTested = time[barIndex];
         levels[levelIndex].strength = MathMin(1.0, levels[levelIndex].strength + 0.1);
         
         if(InpEnableAlerts && InpAlertTouches)
         {
            string msg = StringFormat("Flipped level at %.5f holding as Resistance (Retest #%d)", 
                                    level, levels[levelIndex].retestCount);
            SendAlert(msg);
         }
      }
   }
   else
   {
      // Now support (was resistance) - check if it holds as support
      if(low[barIndex] <= level + testBuffer && close[barIndex] > level)
      {
         // Successful retest as support
         levels[levelIndex].retestCount++;
         levels[levelIndex].lastTested = time[barIndex];
         levels[levelIndex].strength = MathMin(1.0, levels[levelIndex].strength + 0.1);
         
         if(InpEnableAlerts && InpAlertTouches)
         {
            string msg = StringFormat("Flipped level at %.5f holding as Support (Retest #%d)", 
                                    level, levels[levelIndex].retestCount);
            SendAlert(msg);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate volume oscillator                                     |
//+------------------------------------------------------------------+
double CalculateVolumeOscillator(const long &volume[], int index)
{
   if(!InpUseVolume)
      return 0;
   
   // Calculate EMAs
   double shortEMA = 0, longEMA = 0;
   double alphaShort = 2.0 / (InpVolumeEMAShort + 1);
   double alphaLong = 2.0 / (InpVolumeEMALong + 1);
   
   // Initialize with simple average
   if(index + InpVolumeEMALong >= ArraySize(volume))
      return 0;
   
   for(int i = 0; i < InpVolumeEMAShort; i++)
      shortEMA += (double)volume[index + i];
   shortEMA /= InpVolumeEMAShort;
   
   for(int i = 0; i < InpVolumeEMALong; i++)
      longEMA += (double)volume[index + i];
   longEMA /= InpVolumeEMALong;
   
   // Calculate oscillator
   if(longEMA > 0)
      return 100 * (shortEMA - longEMA) / longEMA;
   
   return 0;
}

//+------------------------------------------------------------------+
//| Analyze higher timeframe                                        |
//+------------------------------------------------------------------+
void AnalyzeHigherTimeframe()
{
   if(!InpUseMTF)
      return;
   
   // Get higher timeframe data
   double htfHigh[], htfLow[], htfClose[];
   ArraySetAsSeries(htfHigh, true);
   ArraySetAsSeries(htfLow, true);
   ArraySetAsSeries(htfClose, true);
   
   int htfBars = CopyHigh(_Symbol, InpHigherTF, 0, 100, htfHigh);
   CopyLow(_Symbol, InpHigherTF, 0, 100, htfLow);
   CopyClose(_Symbol, InpHigherTF, 0, 100, htfClose);
   
   if(htfBars < InpLeftBars + InpRightBars + 1)
      return;
   
   // Detect HTF pivots
   for(int i = InpRightBars; i < htfBars - InpLeftBars; i++)
   {
      double htfPivotHigh = DetectPivotHigh(htfHigh, i);
      double htfPivotLow = DetectPivotLow(htfLow, i);
      
      if(htfPivotHigh > 0)
      {
         // Add HTF resistance with higher strength
         bool found = false;
         for(int j = 0; j < levelCount; j++)
         {
            if(MathAbs(levels[j].price - htfPivotHigh) / htfPivotHigh < InpZoneMergeDistance)
            {
               levels[j].strength = MathMin(1.0, levels[j].strength + 0.3);
               found = true;
               break;
            }
         }
      }
      
      if(htfPivotLow > 0)
      {
         // Add HTF support with higher strength
         bool found = false;
         for(int j = 0; j < levelCount; j++)
         {
            if(MathAbs(levels[j].price - htfPivotLow) / htfPivotLow < InpZoneMergeDistance)
            {
               levels[j].strength = MathMin(1.0, levels[j].strength + 0.3);
               found = true;
               break;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Draw level labels                                               |
//+------------------------------------------------------------------+
void DrawLevelLabels()
{
   // Delete ALL old labels and lines first
   int totalObjects = ObjectsTotal(0);
   for(int i = totalObjects - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i);
      if(StringFind(objName, "SR_Line_") == 0 || StringFind(objName, "SR_Label_") == 0)
      {
         ObjectDelete(0, objName);
      }
   }
   
   // Get current price and time
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   datetime currentTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   datetime futureTime = currentTime + PeriodSeconds() * 100; // Extend line 100 bars into future
   
   for(int i = 0; i < levelCount; i++)
   {
      double price = levels[i].price;
      bool isStrong = (levels[i].strength >= 0.7);
      bool hasFlipped = levels[i].hasFlipped;
      
      // Draw trend line from first seen to future
      string lineName = "SR_Line_" + IntegerToString(i);
      
      // Delete if exists, then create
      ObjectDelete(0, lineName);
      
      // Use trend line instead of horizontal line for better control
      datetime startTime = hasFlipped ? levels[i].brokenTime : levels[i].firstSeen;
      
      if(ObjectCreate(0, lineName, OBJ_TREND, 0, startTime, price, futureTime, price))
      {
         // Determine color and style based on level type, strength, and if flipped
         color lineColor;
         int lineStyle;
         int lineWidth;
         
         if(levels[i].isResistance)
         {
            // Resistance
            if(hasFlipped)
            {
               // Flipped level (was support, now resistance)
               lineColor = C'255,150,150'; // Light red with purple tint to show it flipped
               lineStyle = (levels[i].retestCount > 0) ? STYLE_SOLID : STYLE_DASHDOT;
               lineWidth = (levels[i].retestCount > 0) ? 2 : 1;
            }
            else
            {
               lineColor = isStrong ? InpStrongResistanceColor : InpWeakResistanceColor;
               lineStyle = isStrong ? STYLE_SOLID : STYLE_DOT;
               lineWidth = isStrong ? 2 : 1;
            }
         }
         else
         {
            // Support
            if(hasFlipped)
            {
               // Flipped level (was resistance, now support)
               lineColor = C'150,150,255'; // Light blue with purple tint to show it flipped
               lineStyle = (levels[i].retestCount > 0) ? STYLE_SOLID : STYLE_DASHDOT;
               lineWidth = (levels[i].retestCount > 0) ? 2 : 1;
            }
            else
            {
               lineColor = isStrong ? InpStrongSupportColor : InpWeakSupportColor;
               lineStyle = isStrong ? STYLE_SOLID : STYLE_DOT;
               lineWidth = isStrong ? 2 : 1;
            }
         }
         
         ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(0, lineName, OBJPROP_STYLE, lineStyle);
         ObjectSetInteger(0, lineName, OBJPROP_WIDTH, lineWidth);
         ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, true); // Extend to the right
         ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
         ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, lineName, OBJPROP_SELECTED, false);
         ObjectSetInteger(0, lineName, OBJPROP_ZORDER, 0);
      }
      
      // Draw label if enabled
      if(InpShowLabels)
      {
         string labelName = "SR_Label_" + IntegerToString(i);
         
         // Delete if exists
         ObjectDelete(0, labelName);
         
         // Position label at the right edge of the chart
         int firstVisibleBar = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
         int barsOnChart = (int)ChartGetInteger(0, CHART_WIDTH_IN_BARS);
         int rightmostBar = MathMax(0, firstVisibleBar - barsOnChart + 10);
         datetime labelTime = iTime(_Symbol, PERIOD_CURRENT, rightmostBar);
         
         if(ObjectCreate(0, labelName, OBJ_TEXT, 0, labelTime, price))
         {
            string statusText = "";
            if(hasFlipped)
            {
               statusText = StringFormat(" [FLIP:%d RT:%d]", levels[i].flipCount, levels[i].retestCount);
            }
            
            string text = StringFormat("%s %.5f (T:%d, S:%.0f%%)%s",
                                      levels[i].isResistance ? "R" : "S",
                                      price,
                                      levels[i].touches,
                                      levels[i].strength * 100,
                                      statusText);
            
            color textColor;
            if(hasFlipped)
            {
               // Flipped levels get special coloring
               textColor = (levels[i].retestCount > 0) ? C'128,0,128' : clrGray; // Purple for tested flips
            }
            else
            {
               textColor = (levels[i].isResistance || price > currentPrice) ? 
                          (isStrong ? InpStrongResistanceColor : InpWeakResistanceColor) :
                          (isStrong ? InpStrongSupportColor : InpWeakSupportColor);
            }
            
            ObjectSetString(0, labelName, OBJPROP_TEXT, text);
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, textColor);
            ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);
            ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
            ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
            ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, labelName, OBJPROP_ZORDER, 1);
         }
      }
   }
   
   // Force chart redraw
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Create statistics panel                                         |
//+------------------------------------------------------------------+
void CreateStatisticsPanel()
{
   int x = 10, y = 50;
   string prefix = "SR_Stats_";
   
   // Background
   ObjectCreate(0, prefix + "BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, prefix + "BG", OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, prefix + "BG", OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, prefix + "BG", OBJPROP_XSIZE, 250);
   ObjectSetInteger(0, prefix + "BG", OBJPROP_YSIZE, 150);
   ObjectSetInteger(0, prefix + "BG", OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, prefix + "BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, prefix + "BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, prefix + "BG", OBJPROP_BACK, false);
   
   // Title
   CreateLabel(prefix + "Title", x + 10, y + 10, "S/R Statistics", clrYellow, 10, true);
   
   // Stats labels
   CreateLabel(prefix + "Levels", x + 10, y + 30, "", clrWhite, 9);
   CreateLabel(prefix + "Breaks", x + 10, y + 50, "", clrWhite, 9);
   CreateLabel(prefix + "WinRate", x + 10, y + 70, "", clrWhite, 9);
   CreateLabel(prefix + "Touches", x + 10, y + 90, "", clrWhite, 9);
   CreateLabel(prefix + "Volume", x + 10, y + 110, "", clrWhite, 9);
}

//+------------------------------------------------------------------+
//| Update statistics panel                                         |
//+------------------------------------------------------------------+
void UpdateStatisticsPanel()
{
   string prefix = "SR_Stats_";
   
   // Calculate win rate
   if(stats.totalBreaks > 0)
      stats.winRate = (double)stats.successfulBreaks / stats.totalBreaks * 100;
   
   // Update labels
   ObjectSetString(0, prefix + "Levels", OBJPROP_TEXT, 
                  StringFormat("Active Levels: %d", levelCount));
   ObjectSetString(0, prefix + "Breaks", OBJPROP_TEXT, 
                  StringFormat("Breaks: %d (%.1f%% success)", stats.totalBreaks, stats.winRate));
   ObjectSetString(0, prefix + "Touches", OBJPROP_TEXT, 
                  StringFormat("Total Touches: %d", stats.totalTouches));
   ObjectSetString(0, prefix + "Volume", OBJPROP_TEXT, 
                  StringFormat("Volume Osc: %.1f%%", volumeOsc));
}

//+------------------------------------------------------------------+
//| Delete statistics panel                                         |
//+------------------------------------------------------------------+
void DeleteStatisticsPanel()
{
   ObjectsDeleteAll(0, "SR_Stats_");
}

//+------------------------------------------------------------------+
//| Create label helper                                             |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, color clr, int size, bool bold = false)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, name, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
}

//+------------------------------------------------------------------+
//| Cleanup old levels that are too far from current price          |
//+------------------------------------------------------------------+
void CleanupOldLevels()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int newCount = 0;
   
   // Keep only levels within acceptable distance from current price
   for(int i = 0; i < levelCount; i++)
   {
      double distance = MathAbs(levels[i].price - currentPrice) / currentPrice;
      
      // Keep level if it's within acceptable distance
      if(distance <= InpMaxDistanceFromPrice)
      {
         // Move to new position if needed
         if(newCount != i)
         {
            levels[newCount] = levels[i];
         }
         newCount++;
      }
   }
   
   levelCount = newCount;
   
   Print("Cleaned up levels. Kept ", levelCount, " levels near current price ", currentPrice);
}

//+------------------------------------------------------------------+
//| Send alert                                                      |
//+------------------------------------------------------------------+
void SendAlert(string message)
{
   // Prevent alert spam
   if(TimeCurrent() - lastAlertTime < 60)
      return;
   
   lastAlertTime = TimeCurrent();
   
   // Terminal alert
   Alert(message);
   
   // Push notification
   if(InpSendNotification)
      SendNotification(message);
   
   // Email
   if(InpSendEmail)
      SendMail("S/R Alert", message);
}

//+------------------------------------------------------------------+
//| Chart event handler                                             |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      // Redraw labels on chart change
      if(InpShowLabels)
         DrawLevelLabels();
   }
}
//+------------------------------------------------------------------+