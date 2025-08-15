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
input int      InpLeftBars = 7;                     // Left Bars for Pivot Detection (7 optimal for H1)
input int      InpRightBars = 7;                    // Right Bars for Pivot Detection (7 optimal for H1)
input int      InpMaxLookback = 400;                // Maximum Bars to Analyze (400 bars = ~16 days on H1)
input double   InpZoneMergeDistance = 0.0012;       // Zone Merge Distance (12 pips - prevents duplicates)
input int      InpMinTouches = 3;                   // Minimum Touches for Strong Level (3 = reliable)
input double   InpZoneWidth = 0.0004;               // S/R Zone Width (4 pips zone thickness)
input double   InpMaxDistanceFromPrice = 0.03;      // Max Distance from Current Price (3% = ~300 pips)
input int      InpMinPivotStrength = 3;             // Minimum Pivot Strength (3 bars minimum)

// Input parameters - Volume Settings
input group "═══ Volume Analysis ═══"
input bool     InpUseVolume = true;                 // Use Volume Filter
input double   InpVolumeThreshold = 25.0;           // Volume Threshold (25% = balanced filter)
input int      InpVolumeEMAShort = 5;               // Volume EMA Short Period
input int      InpVolumeEMALong = 10;               // Volume EMA Long Period

// Input parameters - Multi-Timeframe
input group "═══ Multi-Timeframe ═══"
input bool     InpUseMTF = true;                    // Use Multi-Timeframe Analysis
input ENUM_TIMEFRAMES InpHigherTF = PERIOD_H4;      // Higher Timeframe

// Input parameters - Break Detection
input group "═══ Break Detection ═══"
input bool     InpShowBreaks = true;                // Show Break Signals
input bool     InpRequireVolumeForBreak = true;     // Require Volume for Breaks (reduces false breaks)
input double   InpBreakBuffer = 0.0003;             // Break Buffer (3 pips - accounts for spread)
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

// Structure for S/R levels with behavior tracking
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
   
   // Behavior tracking
   int struggleCount;     // Number of times price struggled at this level
   int cleanBreakCount;   // Times price broke through without resistance
   int falseBreakCount;   // Times price broke but returned (fake outs)
   int bounceCount;       // Strong rejections from this level
   double avgHoldTime;    // Average time price respects this level
   datetime lastStruggle; // Last time price struggled here
   bool wasRetested;      // If level was retested after break
   double retestQuality;  // Quality of retest (0-1, higher is better)
   int consecutiveFails;  // Consecutive times level failed to hold
   double behaviorScore;  // Overall behavior score (0-100)
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
//| Calculate level strength based on behavior                      |
//+------------------------------------------------------------------+
double CalculateLevelStrength(SRLevel &level)
{
   // Behavior-weighted strength calculation
   double strength = 0;
   
   // 1. Struggle behavior (30% weight) - More struggles = stronger level
   double struggleScore = MathMin(1.0, level.struggleCount / 5.0); // Max at 5 struggles
   strength += struggleScore * 0.30;
   
   // 2. Bounce quality (25% weight) - Strong rejections indicate strength
   double bounceScore = MathMin(1.0, level.bounceCount / 3.0); // Max at 3 strong bounces
   strength += bounceScore * 0.25;
   
   // 3. Retest quality (20% weight) - Successful retests after break
   if(level.wasRetested)
   {
      strength += level.retestQuality * 0.20;
   }
   else if(level.isBroken && !level.wasRetested)
   {
      strength -= 0.10; // Penalty for unretested breaks
   }
   
   // 4. False break resistance (15% weight) - Surviving false breaks = strength
   double falseBreakScore = MathMin(1.0, level.falseBreakCount / 2.0) * 0.8; // Some false breaks are good
   strength += falseBreakScore * 0.15;
   
   // 5. Clean break penalty (negative weight) - Easy breaks = weakness
   double cleanBreakPenalty = MathMin(0.3, level.cleanBreakCount * 0.15);
   strength -= cleanBreakPenalty;
   
   // 6. Consecutive fails penalty - Multiple failures = dying level
   double failPenalty = level.consecutiveFails * 0.15;
   strength -= failPenalty;
   
   // 7. Time-based factors (10% weight)
   int recentBars = (int)((TimeCurrent() - level.lastTested) / PeriodSeconds());
   if(recentBars < 50) // Recently tested
   {
      strength += 0.10 * (1.0 - recentBars / 50.0);
   }
   
   // 8. Role reversal bonus - Flipped levels that hold are very strong
   if(level.hasFlipped && level.retestCount > 0)
   {
      strength += 0.15 + (level.retestCount * 0.05); // Big bonus for proven role reversal
   }
   
   // Normalize to 0-1 range
   strength = MathMax(0.0, MathMin(1.0, strength));
   
   // Update behavior score (0-100 for display)
   level.behaviorScore = strength * 100;
   
   return strength;
}


//+------------------------------------------------------------------+
//| Detect if price is struggling at a level                        |
//+------------------------------------------------------------------+
bool DetectStruggle(SRLevel &level, int index, const double &high[], const double &low[], 
                   const double &close[], const datetime &time[])
{
   double levelZone = level.price * InpZoneWidth;
   int struggleBars = 0;
   double priceRange = 0;
   
   // Look at last 5-10 bars for struggle behavior
   for(int i = index; i < MathMin(index + 10, ArraySize(high)); i++)
   {
      // Check if price is near the level
      if((MathAbs(high[i] - level.price) < levelZone) || 
         (MathAbs(low[i] - level.price) < levelZone))
      {
         struggleBars++;
         priceRange += (high[i] - low[i]);
      }
   }
   
   // Struggle = multiple bars near level with small range (consolidation)
   if(struggleBars >= 3)
   {
      double avgRange = priceRange / struggleBars;
      double normalRange = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 50; // Normal bar range
      
      if(avgRange < normalRange * 1.5) // Compressed range = struggle
      {
         level.struggleCount++;
         level.lastStruggle = time[index];
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Detect bounce from level                                        |
//+------------------------------------------------------------------+
bool DetectBounce(SRLevel &level, int index, const double &high[], const double &low[], 
                 const double &close[], const double &open[])
{
   double levelZone = level.price * InpZoneWidth;
   
   if(level.isResistance)
   {
      // Strong bearish rejection from resistance
      if(MathAbs(high[index] - level.price) < levelZone && 
         close[index] < open[index] && 
         (open[index] - close[index]) > (high[index] - low[index]) * 0.6)
      {
         level.bounceCount++;
         return true;
      }
   }
   else
   {
      // Strong bullish rejection from support
      if(MathAbs(low[index] - level.price) < levelZone && 
         close[index] > open[index] && 
         (close[index] - open[index]) > (high[index] - low[index]) * 0.6)
      {
         level.bounceCount++;
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check for retest after break                                    |
//+------------------------------------------------------------------+
void CheckForRetest(SRLevel &level, int index, const double &high[], const double &low[], 
                   const double &close[], const datetime &time[])
{
   if(!level.isBroken || level.wasRetested) return;
   
   double levelZone = level.price * InpZoneWidth;
   int barsSinceBreak = (int)((time[index] - level.brokenTime) / PeriodSeconds());
   
   // Look for retest within 20 bars of break
   if(barsSinceBreak > 0 && barsSinceBreak < 20)
   {
      // Check if price returned to test the level
      if(level.hasFlipped) // Was resistance, now support
      {
         if(MathAbs(low[index] - level.price) < levelZone && close[index] > level.price)
         {
            level.wasRetested = true;
            level.retestCount++;
            
            // Calculate retest quality (how cleanly it held)
            double wickRatio = 0;
            if(close[index] > open[index])
               wickRatio = (close[index] - low[index]) / (high[index] - low[index]);
            else
               wickRatio = (open[index] - low[index]) / (high[index] - low[index]);
               
            level.retestQuality = MathMin(1.0, wickRatio * 1.5);
         }
      }
      else if(!level.hasFlipped) // Still broken, checking for failed retest
      {
         if(MathAbs(high[index] - level.price) < levelZone && close[index] < level.price)
         {
            level.wasRetested = true;
            level.retestQuality = 0.3; // Failed retest = weak level
         }
      }
   }
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
      
      // First check for struggles and bounces
      DetectStruggle(levels[i], index, high, low, close, time);
      DetectBounce(levels[i], index, high, low, close, open);
      CheckForRetest(levels[i], index, high, low, close, time);
      
      // Check for breaks and role reversals
      if(levels[i].isResistance)
      {
         // Resistance level
         if(close[index] > level + breakBuffer && close[index + 1] <= level)
         {
            // Determine break quality
            bool isCleanBreak = (close[index] - level) > breakBuffer * 3; // Strong break
            bool hasVolume = volumeOsc > InpVolumeThreshold;
            
            if(!InpRequireVolumeForBreak || hasVolume)
            {
               levels[i].isBroken = true;
               levels[i].brokenTime = time[index];
               
               // Check if this becomes a false break later (look ahead 3 bars)
               bool isFalseBreak = false;
               for(int j = MathMax(0, index - 3); j < index; j++)
               {
                  if(close[j] < level) // Price came back below
                  {
                     isFalseBreak = true;
                     break;
                  }
               }
               
               if(isFalseBreak)
               {
                  levels[i].falseBreakCount++;
                  levels[i].isBroken = false; // Reset
                  levels[i].strength = CalculateLevelStrength(levels[i]); // Recalculate
               }
               else
               {
                  // True break - flip to support
                  if(isCleanBreak)
                  {
                     levels[i].cleanBreakCount++;
                     levels[i].consecutiveFails = 0; // Reset fail counter
                  }
                  
                  levels[i].isResistance = false;  // Now becomes support
                  levels[i].hasFlipped = true;
                  levels[i].flipCount++;
                  levels[i].strength = CalculateLevelStrength(levels[i]);
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
      // Use InpMinTouches parameter for consistency
      if(touches >= InpMinTouches || bounces >= 2)  // Use configured min touches
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
      // Use behavior score for strength assessment
      double behaviorStrength = levels[i].behaviorScore / 100.0; // Convert to 0-1 range
      bool isStrong = (behaviorStrength >= 0.7);
      bool isMedium = (behaviorStrength >= 0.4 && behaviorStrength < 0.7);
      bool isWeak = (behaviorStrength < 0.4);
      bool hasFlipped = levels[i].hasFlipped;
      
      // Draw trend line from first seen to future
      string lineName = "SR_Line_" + IntegerToString(i);
      
      // Delete if exists, then create
      ObjectDelete(0, lineName);
      
      // Use trend line instead of horizontal line for better control
      datetime startTime = hasFlipped ? levels[i].brokenTime : levels[i].firstSeen;
      
      if(ObjectCreate(0, lineName, OBJ_TREND, 0, startTime, price, futureTime, price))
      {
         // Determine color and style based on behavior score
         color lineColor;
         int lineStyle;
         int lineWidth;
         
         // Enhanced coloring based on behavior patterns
         if(levels[i].isResistance)
         {
            // Resistance levels
            if(hasFlipped)
            {
               // Flipped level with behavior-based coloring
               if(levels[i].wasRetested && levels[i].retestQuality > 0.7)
               {
                  lineColor = C'200,0,200'; // Strong purple for well-tested flips
                  lineStyle = STYLE_SOLID;
                  lineWidth = 3;
               }
               else
               {
                  lineColor = C'255,150,150'; // Light red with purple tint
                  lineStyle = STYLE_DASHDOT;
                  lineWidth = 2;
               }
            }
            else
            {
               // Color based on behavior score
               if(isStrong)
               {
                  lineColor = InpStrongResistanceColor;
                  lineStyle = STYLE_SOLID;
                  lineWidth = (levels[i].struggleCount > 5) ? 3 : 2;
               }
               else if(isMedium)
               {
                  lineColor = C'255,100,100'; // Medium red
                  lineStyle = STYLE_DASH;
                  lineWidth = 2;
               }
               else
               {
                  lineColor = InpWeakResistanceColor;
                  lineStyle = STYLE_DOT;
                  lineWidth = 1;
               }
               
               // Special case: many clean breaks = weakening level
               if(levels[i].cleanBreakCount > 2)
               {
                  lineColor = C'255,200,200'; // Very light red
                  lineStyle = STYLE_DASHDOTDOT;
               }
            }
         }
         else
         {
            // Support levels
            if(hasFlipped)
            {
               // Flipped level with behavior-based coloring
               if(levels[i].wasRetested && levels[i].retestQuality > 0.7)
               {
                  lineColor = C'0,200,200'; // Strong cyan for well-tested flips
                  lineStyle = STYLE_SOLID;
                  lineWidth = 3;
               }
               else
               {
                  lineColor = C'150,150,255'; // Light blue with purple tint
                  lineStyle = STYLE_DASHDOT;
                  lineWidth = 2;
               }
            }
            else
            {
               // Color based on behavior score
               if(isStrong)
               {
                  lineColor = InpStrongSupportColor;
                  lineStyle = STYLE_SOLID;
                  lineWidth = (levels[i].struggleCount > 5) ? 3 : 2;
               }
               else if(isMedium)
               {
                  lineColor = C'100,100,255'; // Medium blue
                  lineStyle = STYLE_DASH;
                  lineWidth = 2;
               }
               else
               {
                  lineColor = InpWeakSupportColor;
                  lineStyle = STYLE_DOT;
                  lineWidth = 1;
               }
               
               // Special case: many clean breaks = weakening level
               if(levels[i].cleanBreakCount > 2)
               {
                  lineColor = C'200,200,255'; // Very light blue
                  lineStyle = STYLE_DASHDOTDOT;
               }
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
            
            // Add behavior indicators to label
            string behaviorText = "";
            if(levels[i].struggleCount > 0)
               behaviorText += StringFormat(" ST:%d", levels[i].struggleCount);
            if(levels[i].bounceCount > 0)
               behaviorText += StringFormat(" B:%d", levels[i].bounceCount);
            if(levels[i].cleanBreakCount > 0)
               behaviorText += StringFormat(" CB:%d", levels[i].cleanBreakCount);
            if(levels[i].falseBreakCount > 0)
               behaviorText += StringFormat(" FB:%d", levels[i].falseBreakCount);
            
            string text = StringFormat("%s %.5f (BS:%.0f%%)%s%s",
                                      levels[i].isResistance ? "R" : "S",
                                      price,
                                      levels[i].behaviorScore,
                                      behaviorText,
                                      statusText);
            
            color textColor;
            if(hasFlipped)
            {
               // Flipped levels get special coloring based on retest quality
               if(levels[i].wasRetested && levels[i].retestQuality > 0.7)
                  textColor = C'128,0,128'; // Strong purple for well-tested flips
               else if(levels[i].retestCount > 0)
                  textColor = C'200,100,200'; // Light purple for tested flips
               else
                  textColor = clrGray; // Gray for untested flips
            }
            else
            {
               // Color based on behavior score
               if(levels[i].isResistance)
               {
                  if(isStrong)
                     textColor = InpStrongResistanceColor;
                  else if(isMedium)
                     textColor = C'255,100,100'; // Medium red
                  else
                     textColor = InpWeakResistanceColor;
               }
               else
               {
                  if(isStrong)
                     textColor = InpStrongSupportColor;
                  else if(isMedium)
                     textColor = C'100,100,255'; // Medium blue
                  else
                     textColor = InpWeakSupportColor;
               }
               
               // Special case: weakened levels
               if(levels[i].cleanBreakCount > 2)
                  textColor = clrLightGray;
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