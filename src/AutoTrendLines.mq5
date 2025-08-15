//+------------------------------------------------------------------+
//|                                               AutoTrendLines.mq5 |
//|                                     Automatic Trend Line Drawer  |
//|                                                        v1.0.0    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input int      InpLookback           = 14;        // Swing Detection Lookback
input double   InpSlopeMultiplier    = 1.0;       // Slope Multiplier
input ENUM_MA_METHOD InpSlopeMethod  = MODE_SMA;  // Slope Calculation Method (0=ATR, 1=StdDev, 2=LinReg)
input bool     InpShowExtended       = true;      // Show Extended Lines
input color    InpUpTrendColor       = clrAqua;   // Up Trendline Color
input color    InpDownTrendColor     = clrRed;    // Down Trendline Color
input int      InpLineWidth          = 2;         // Line Width
input ENUM_LINE_STYLE InpLineStyle   = STYLE_SOLID; // Line Style
input int      InpMinTouchPoints     = 3;         // Minimum Touch Points for Validation
input double   InpTouchTolerance     = 0.0001;    // Touch Point Tolerance (as % of price)
input int      InpMaxLines           = 10;        // Maximum Active Lines
input bool     InpShowBreaks         = true;      // Show Breakout Labels
input bool     InpAlertOnBreak       = true;      // Alert on Breakouts

//+------------------------------------------------------------------+
//| Structure for Pivot Points                                       |
//+------------------------------------------------------------------+
struct SPivot
{
    datetime time;
    double   price;
    int      bar;
    bool     isHigh;
};

//+------------------------------------------------------------------+
//| Structure for Trend Lines                                        |
//+------------------------------------------------------------------+
struct STrendLine
{
    string   name;
    datetime time1;
    double   price1;
    datetime time2;
    double   price2;
    double   slope;
    bool     isUp;
    int      touchPoints;
    datetime lastTouch;
    bool     isBroken;
};

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
SPivot     g_pivots[];
STrendLine g_trendLines[];
int        g_lineCounter = 0;
datetime   g_lastCalculation = 0;
double     g_atrValue = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize arrays
    ArrayResize(g_pivots, 0);
    ArrayResize(g_trendLines, 0);
    
    // Set indicator properties
    IndicatorSetString(INDICATOR_SHORTNAME, "Auto Trend Lines");
    
    // Clean up any existing objects
    CleanupObjects();
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    CleanupObjects();
    Comment("");
}

//+------------------------------------------------------------------+
//| Clean up all trend line objects                                  |
//+------------------------------------------------------------------+
void CleanupObjects()
{
    ObjectsDeleteAll(0, "ATL_");
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
    // Check if we have enough bars
    if(rates_total < InpLookback * 2 + 1)
        return(0);
    
    // Calculate only on new bar or first run
    if(time[rates_total - 1] != g_lastCalculation)
    {
        g_lastCalculation = time[rates_total - 1];
        
        // Update ATR value for slope calculations
        UpdateATR();
        
        // Find pivot points
        FindPivotPoints(high, low, time, rates_total);
        
        // Generate trend lines from pivots
        GenerateTrendLines();
        
        // Validate trend lines with touch points
        ValidateTrendLines(high, low, close, time, rates_total);
        
        // Draw trend lines
        DrawTrendLines();
        
        // Check for breakouts
        if(InpShowBreaks || InpAlertOnBreak)
            CheckBreakouts(close[rates_total - 1], time[rates_total - 1]);
        
        // Update comment with statistics
        UpdateComment();
    }
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Find pivot highs and lows                                        |
//+------------------------------------------------------------------+
void FindPivotPoints(const double &high[], const double &low[], 
                      const datetime &time[], int rates_total)
{
    ArrayResize(g_pivots, 0);
    
    for(int i = InpLookback; i < rates_total - InpLookback; i++)
    {
        // Check for pivot high
        bool isPivotHigh = true;
        for(int j = 1; j <= InpLookback; j++)
        {
            if(high[i] <= high[i - j] || high[i] <= high[i + j])
            {
                isPivotHigh = false;
                break;
            }
        }
        
        if(isPivotHigh)
        {
            SPivot pivot;
            pivot.time = time[i];
            pivot.price = high[i];
            pivot.bar = i;
            pivot.isHigh = true;
            
            int size = ArraySize(g_pivots);
            ArrayResize(g_pivots, size + 1);
            g_pivots[size] = pivot;
        }
        
        // Check for pivot low
        bool isPivotLow = true;
        for(int j = 1; j <= InpLookback; j++)
        {
            if(low[i] >= low[i - j] || low[i] >= low[i + j])
            {
                isPivotLow = false;
                break;
            }
        }
        
        if(isPivotLow)
        {
            SPivot pivot;
            pivot.time = time[i];
            pivot.price = low[i];
            pivot.bar = i;
            pivot.isHigh = false;
            
            int size = ArraySize(g_pivots);
            ArrayResize(g_pivots, size + 1);
            g_pivots[size] = pivot;
        }
    }
}

//+------------------------------------------------------------------+
//| Generate trend lines from pivot points                           |
//+------------------------------------------------------------------+
void GenerateTrendLines()
{
    ArrayResize(g_trendLines, 0);
    int pivotCount = ArraySize(g_pivots);
    
    if(pivotCount < 2)
        return;
    
    // Connect pivot highs for down trend lines
    for(int i = 0; i < pivotCount - 1; i++)
    {
        if(!g_pivots[i].isHigh)
            continue;
            
        for(int j = i + 1; j < pivotCount && j < i + 10; j++)
        {
            if(!g_pivots[j].isHigh)
                continue;
            
            // Calculate slope
            double slope = CalculateSlope(g_pivots[i], g_pivots[j]);
            
            // Create trend line structure
            STrendLine line;
            line.name = "ATL_DOWN_" + IntegerToString(g_lineCounter++);
            line.time1 = g_pivots[i].time;
            line.price1 = g_pivots[i].price;
            line.time2 = g_pivots[j].time;
            line.price2 = g_pivots[j].price;
            line.slope = slope;
            line.isUp = false;
            line.touchPoints = 2;
            line.lastTouch = g_pivots[j].time;
            line.isBroken = false;
            
            // Add to array if within limits
            if(ArraySize(g_trendLines) < InpMaxLines)
            {
                int size = ArraySize(g_trendLines);
                ArrayResize(g_trendLines, size + 1);
                g_trendLines[size] = line;
            }
        }
    }
    
    // Connect pivot lows for up trend lines
    for(int i = 0; i < pivotCount - 1; i++)
    {
        if(g_pivots[i].isHigh)
            continue;
            
        for(int j = i + 1; j < pivotCount && j < i + 10; j++)
        {
            if(g_pivots[j].isHigh)
                continue;
            
            // Calculate slope
            double slope = CalculateSlope(g_pivots[i], g_pivots[j]);
            
            // Create trend line structure
            STrendLine line;
            line.name = "ATL_UP_" + IntegerToString(g_lineCounter++);
            line.time1 = g_pivots[i].time;
            line.price1 = g_pivots[i].price;
            line.time2 = g_pivots[j].time;
            line.price2 = g_pivots[j].price;
            line.slope = slope;
            line.isUp = true;
            line.touchPoints = 2;
            line.lastTouch = g_pivots[j].time;
            line.isBroken = false;
            
            // Add to array if within limits
            if(ArraySize(g_trendLines) < InpMaxLines)
            {
                int size = ArraySize(g_trendLines);
                ArrayResize(g_trendLines, size + 1);
                g_trendLines[size] = line;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate slope between two pivots                               |
//+------------------------------------------------------------------+
double CalculateSlope(const SPivot &pivot1, const SPivot &pivot2)
{
    int barDiff = pivot2.bar - pivot1.bar;
    if(barDiff == 0)
        return 0;
    
    double priceDiff = pivot2.price - pivot1.price;
    double rawSlope = priceDiff / barDiff;
    
    // Apply slope calculation method
    switch(InpSlopeMethod)
    {
        case 0: // ATR-based
            return rawSlope * InpSlopeMultiplier * g_atrValue;
            
        case 1: // StdDev-based
            return rawSlope * InpSlopeMultiplier * CalculateStdDev();
            
        case 2: // Linear regression
            return rawSlope * InpSlopeMultiplier;
            
        default:
            return rawSlope * InpSlopeMultiplier;
    }
}

//+------------------------------------------------------------------+
//| Validate trend lines with additional touch points                |
//+------------------------------------------------------------------+
void ValidateTrendLines(const double &high[], const double &low[], 
                        const double &close[], const datetime &time[], 
                        int rates_total)
{
    int lineCount = ArraySize(g_trendLines);
    
    for(int i = 0; i < lineCount; i++)
    {
        int touchCount = 2; // Start with initial 2 pivots
        
        // Check all bars for touches
        for(int j = InpLookback; j < rates_total - 1; j++)
        {
            // Calculate expected price at this bar
            double expectedPrice = CalculateLinePrice(g_trendLines[i], time[j]);
            
            // Check if price touches the line (within tolerance)
            double tolerance = close[j] * InpTouchTolerance;
            bool isTouched = false;
            
            if(g_trendLines[i].isUp)
            {
                // For up trend line, check if low touches
                if(MathAbs(low[j] - expectedPrice) <= tolerance)
                {
                    isTouched = true;
                    touchCount++;
                }
            }
            else
            {
                // For down trend line, check if high touches
                if(MathAbs(high[j] - expectedPrice) <= tolerance)
                {
                    isTouched = true;
                    touchCount++;
                }
            }
            
            if(isTouched)
            {
                g_trendLines[i].lastTouch = time[j];
            }
        }
        
        g_trendLines[i].touchPoints = touchCount;
        
        // Check if line is broken
        double currentPrice = close[rates_total - 1];
        double linePrice = CalculateLinePrice(g_trendLines[i], time[rates_total - 1]);
        
        if(g_trendLines[i].isUp && currentPrice < linePrice)
            g_trendLines[i].isBroken = true;
        else if(!g_trendLines[i].isUp && currentPrice > linePrice)
            g_trendLines[i].isBroken = true;
    }
    
    // Remove lines with insufficient touch points
    for(int i = lineCount - 1; i >= 0; i--)
    {
        if(g_trendLines[i].touchPoints < InpMinTouchPoints)
        {
            // Delete the object if it exists
            ObjectDelete(0, g_trendLines[i].name);
            
            // Remove from array
            for(int j = i; j < lineCount - 1; j++)
            {
                g_trendLines[j] = g_trendLines[j + 1];
            }
            ArrayResize(g_trendLines, lineCount - 1);
            lineCount--;
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate price at given time for a trend line                   |
//+------------------------------------------------------------------+
double CalculateLinePrice(const STrendLine &line, datetime targetTime)
{
    if(line.time2 == line.time1)
        return line.price1;
    
    double slope = (line.price2 - line.price1) / (double)(line.time2 - line.time1);
    return line.price1 + slope * (targetTime - line.time1);
}

//+------------------------------------------------------------------+
//| Draw trend lines on chart                                        |
//+------------------------------------------------------------------+
void DrawTrendLines()
{
    int lineCount = ArraySize(g_trendLines);
    
    for(int i = 0; i < lineCount; i++)
    {
        // Create or update trend line
        if(!ObjectCreate(0, g_trendLines[i].name, OBJ_TREND, 0, 
                        g_trendLines[i].time1, g_trendLines[i].price1,
                        g_trendLines[i].time2, g_trendLines[i].price2))
        {
            // Update existing line
            ObjectSetDouble(0, g_trendLines[i].name, OBJPROP_PRICE, 0, g_trendLines[i].price1);
            ObjectSetDouble(0, g_trendLines[i].name, OBJPROP_PRICE, 1, g_trendLines[i].price2);
            ObjectSetInteger(0, g_trendLines[i].name, OBJPROP_TIME, 0, g_trendLines[i].time1);
            ObjectSetInteger(0, g_trendLines[i].name, OBJPROP_TIME, 1, g_trendLines[i].time2);
        }
        
        // Set line properties
        ObjectSetInteger(0, g_trendLines[i].name, OBJPROP_COLOR, 
                        g_trendLines[i].isUp ? InpUpTrendColor : InpDownTrendColor);
        ObjectSetInteger(0, g_trendLines[i].name, OBJPROP_WIDTH, InpLineWidth);
        ObjectSetInteger(0, g_trendLines[i].name, OBJPROP_STYLE, 
                        g_trendLines[i].isBroken ? STYLE_DOT : InpLineStyle);
        ObjectSetInteger(0, g_trendLines[i].name, OBJPROP_RAY_RIGHT, InpShowExtended);
        ObjectSetInteger(0, g_trendLines[i].name, OBJPROP_RAY_LEFT, false);
        ObjectSetInteger(0, g_trendLines[i].name, OBJPROP_SELECTABLE, true);
        ObjectSetInteger(0, g_trendLines[i].name, OBJPROP_SELECTED, false);
        
        // Add description with touch points
        string description = StringFormat("%s Trend Line - %d touches", 
                                        g_trendLines[i].isUp ? "Up" : "Down",
                                        g_trendLines[i].touchPoints);
        ObjectSetString(0, g_trendLines[i].name, OBJPROP_TEXT, description);
    }
    
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Check for trend line breakouts                                   |
//+------------------------------------------------------------------+
void CheckBreakouts(double currentPrice, datetime currentTime)
{
    int lineCount = ArraySize(g_trendLines);
    
    for(int i = 0; i < lineCount; i++)
    {
        if(g_trendLines[i].isBroken)
            continue;
            
        double linePrice = CalculateLinePrice(g_trendLines[i], currentTime);
        bool breakout = false;
        string breakType = "";
        
        if(g_trendLines[i].isUp && currentPrice < linePrice)
        {
            breakout = true;
            breakType = "Down break of UP trend line";
        }
        else if(!g_trendLines[i].isUp && currentPrice > linePrice)
        {
            breakout = true;
            breakType = "Up break of DOWN trend line";
        }
        
        if(breakout)
        {
            g_trendLines[i].isBroken = true;
            
            // Create breakout label
            if(InpShowBreaks)
            {
                string labelName = "ATL_BREAK_" + IntegerToString(g_lineCounter++);
                ObjectCreate(0, labelName, OBJ_TEXT, 0, currentTime, currentPrice);
                ObjectSetString(0, labelName, OBJPROP_TEXT, "B");
                ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
                ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
                ObjectSetInteger(0, labelName, OBJPROP_COLOR, 
                                g_trendLines[i].isUp ? InpDownTrendColor : InpUpTrendColor);
                ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
            }
            
            // Send alert
            if(InpAlertOnBreak)
            {
                Alert(breakType, " at ", DoubleToString(currentPrice, _Digits));
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Update ATR value for slope calculations                          |
//+------------------------------------------------------------------+
void UpdateATR()
{
    double atr[];
    ArraySetAsSeries(atr, true);
    
    int atrHandle = iATR(_Symbol, _Period, InpLookback);
    if(atrHandle != INVALID_HANDLE)
    {
        CopyBuffer(atrHandle, 0, 0, 1, atr);
        g_atrValue = atr[0];
        IndicatorRelease(atrHandle);
    }
}

//+------------------------------------------------------------------+
//| Calculate standard deviation                                     |
//+------------------------------------------------------------------+
double CalculateStdDev()
{
    double stdDev[];
    ArraySetAsSeries(stdDev, true);
    
    int stdHandle = iStdDev(_Symbol, _Period, InpLookback, 0, MODE_SMA, PRICE_CLOSE);
    if(stdHandle != INVALID_HANDLE)
    {
        CopyBuffer(stdHandle, 0, 0, 1, stdDev);
        double result = stdDev[0];
        IndicatorRelease(stdHandle);
        return result;
    }
    
    return 0;
}

//+------------------------------------------------------------------+
//| Update comment with statistics                                   |
//+------------------------------------------------------------------+
void UpdateComment()
{
    int lineCount = ArraySize(g_trendLines);
    int upLines = 0, downLines = 0, brokenLines = 0;
    int totalTouches = 0;
    
    for(int i = 0; i < lineCount; i++)
    {
        if(g_trendLines[i].isUp)
            upLines++;
        else
            downLines++;
            
        if(g_trendLines[i].isBroken)
            brokenLines++;
            
        totalTouches += g_trendLines[i].touchPoints;
    }
    
    string comment = StringFormat("Auto Trend Lines v1.0\n" +
                                 "Active Lines: %d (Up: %d, Down: %d)\n" +
                                 "Broken Lines: %d\n" +
                                 "Avg Touch Points: %.1f\n" +
                                 "Total Pivots: %d",
                                 lineCount, upLines, downLines,
                                 brokenLines,
                                 lineCount > 0 ? (double)totalTouches / lineCount : 0,
                                 ArraySize(g_pivots));
    
    Comment(comment);
}
//+------------------------------------------------------------------+