//+------------------------------------------------------------------+
//|                                            BarCounterEnhanced.mq5|
//|                                 Enhanced Bar Counting Indicator   |
//|                                               Version 3.0         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "3.00"
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

// Timezone enumeration
enum ENUM_TIMEZONE
{
   TZ_BROKER = 0,      // Broker Time (Server)
   TZ_LOCAL = 1,       // Local Computer Time
   TZ_UTC = 2,         // UTC/GMT
   TZ_NEWYORK = 3,     // New York (EST/EDT)
   TZ_LONDON = 4,      // London (GMT/BST)
   TZ_TOKYO = 5,       // Tokyo (JST)
   TZ_SYDNEY = 6,      // Sydney (AEST/AEDT)
   TZ_CUSTOM = 7       // Custom UTC Offset
};

// Session preset enumeration
enum ENUM_SESSION_PRESET
{
   SESSION_CUSTOM = 0,     // Custom Times
   SESSION_FOREX = 1,      // Forex Sessions
   SESSION_STOCKS_US = 2,  // US Stock Market
   SESSION_STOCKS_EU = 3,  // European Stocks
   SESSION_STOCKS_ASIA = 4,// Asian Stocks
   SESSION_CRYPTO = 5      // Crypto (24/7)
};

// Input parameters - Display Settings
input group "=== Display Settings ==="
input int DisplayInterval = 5;                // Display count every X bars (1 = every bar)
input bool DisplayAboveBar = false;           // Display above high (true) or below low (false)
input color TextColor = clrLightBlue;         // Text color for bar count
input ENUM_FONT_SIZE FontSizeOption = FONT_MEDIUM; // Font size option
input int CustomFontSize = 10;                // Custom font size (used when Custom is selected)
input string FontName = "Arial";              // Font name
input int TextOffset = 0;                     // Vertical offset (in ticks, 0=auto)
input bool VerticalText = true;               // Display text vertically (90 degrees rotation)
input int MaxBarsToProcess = 500;             // Maximum bars to process (0 = all bars)

// Input parameters - Enhanced Features
input group "=== Enhanced Features ==="
input bool ShowCurrentBarTimer = true;        // Show timer on right side of current candle
input color CurrentBarTimerColor = clrDarkOrange;   // Color for current bar timer
input int TimerFontSize = 10;                 // Timer font size

// Input parameters - Milestone Markers
input group "=== Milestone Settings ==="
input bool EnableMilestones = true;           // Enable milestone markers
input int MilestoneInterval = 10;             // Highlight every X bars (e.g., 10 = every 10th bar)
input color MilestoneColor = clrRed;          // Milestone color

// Input parameters - Weekend Handling
input group "=== Weekend Settings ==="
input bool SkipWeekends = true;               // Skip weekend bars in counting
input bool HighlightWeekends = false;         // Highlight weekend bars
input color WeekendColor = clrGray;           // Weekend highlight color

// Input parameters - Timezone Settings
input group "=== Timezone Configuration ==="
input ENUM_TIMEZONE SessionTimezone = TZ_BROKER; // Session Times Timezone
input int CustomUTCOffset = 0;                // Custom UTC Offset (hours, if Custom selected)
input bool AutoDetectDST = true;              // Auto-detect Daylight Saving Time
input bool ShowTimezoneLabel = true;          // Show current timezone in corner

// Input parameters - Session Presets
input group "=== Session Presets ==="
input ENUM_SESSION_PRESET SessionPreset = SESSION_FOREX; // Use Preset Session Times

// Input parameters - Session 1 (Primary)
input group "=== Session 1 Settings ==="
input bool ShowSession1 = true;               // Show Session 1
input string Session1Time = "08:00-17:00";    // Session 1 Time (in selected timezone)
input color Session1Color = clrDodgerBlue;    // Session 1 Color  
input uchar Session1Alpha = 50;               // Session 1 Transparency (0-255, lower=more transparent)
input string Session1Name = "London";         // Session 1 Name

// Input parameters - Session 2
input group "=== Session 2 Settings ==="
input bool ShowSession2 = true;               // Show Session 2
input string Session2Time = "13:00-22:00";    // Session 2 Time (in selected timezone)
input color Session2Color = clrOrange;        // Session 2 Color
input uchar Session2Alpha = 50;               // Session 2 Transparency (0-255, lower=more transparent)
input string Session2Name = "New York";       // Session 2 Name

// Input parameters - Session 3
input group "=== Session 3 Settings ==="
input bool ShowSession3 = false;              // Show Session 3
input string Session3Time = "00:00-09:00";    // Session 3 Time (in selected timezone)
input color Session3Color = clrMediumPurple;  // Session 3 Color
input uchar Session3Alpha = 50;               // Session 3 Transparency (0-255, lower=more transparent)
input string Session3Name = "Tokyo";          // Session 3 Name

// Input parameters - Session 4
input group "=== Session 4 Settings ==="
input bool ShowSession4 = false;              // Show Session 4
input string Session4Time = "22:00-07:00";    // Session 4 Time (in selected timezone)
input color Session4Color = clrHotPink;       // Session 4 Color
input uchar Session4Alpha = 50;               // Session 4 Transparency (0-255, lower=more transparent)
input string Session4Name = "Sydney";         // Session 4 Name

// Input parameters - Session Display Options
input group "=== Session Display Options ==="
input bool ShowSessionLabels = true;          // Show session labels
input int SessionLabelFontSize = 8;           // Session label font size
input bool ShowSessionBorders = true;         // Show session borders
input ENUM_LINE_STYLE SessionBorderStyle = STYLE_DASH; // Session border style
input bool ShowSessionOverlaps = true;        // Highlight session overlaps differently
input color SessionOverlapColor = clrYellow;  // Session overlap color
input uchar SessionOverlapAlpha = 30;         // Session overlap transparency

// Global variables
string objPrefix = "BarCountEnhanced_";
int barCounter = 0;
datetime lastCountedBar = 0;
int currentTimezoneOffset = 0;
bool isDST = false;

// Session structure
struct SessionInfo
{
   bool show;
   string time;
   color clr;
   uchar alpha;
   string name;
   datetime startTime;
   datetime endTime;
   bool inSession;
   datetime sessionStartBar;
   double sessionHigh;
   double sessionLow;
};

SessionInfo sessions[4];

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
   IndicatorSetString(INDICATOR_SHORTNAME, "Bar Counter Enhanced v3.0");
   DeleteAllObjects();
   
   // Initialize timezone settings
   InitializeTimezone();
   
   // Initialize sessions based on preset or custom
   InitializeSessions();
   
   // Set timer for 1-second updates if timer is enabled
   if(ShowCurrentBarTimer)
   {
      EventSetTimer(1); // Update every second
   }
   
   // Show timezone label if enabled
   if(ShowTimezoneLabel)
   {
      CreateTimezoneLabel();
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
      if(ShowTimezoneLabel) CreateTimezoneLabel();
   }
   
   // Show timer on right side of current candle
   if(ShowCurrentBarTimer)
   {
      DisplayCurrentBarTimer(time, close);
   }
   
   // Determine bars to process
   int limit = MaxBarsToProcess > 0 ? MathMin(MaxBarsToProcess, rates_total) : rates_total;
   
   // Process bars from oldest to newest for correct counting
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
   
   // Display the bars
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
   
   // Process session highlights using the working technique
   ProcessSessions(time, high, low, limit);
   
   ChartRedraw();
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Process session highlights (using working technique)             |
//+------------------------------------------------------------------+
void ProcessSessions(const datetime &time[], const double &high[], const double &low[], int limit)
{
   // Clean up old session objects
   static datetime lastCleanup = 0;
   if(TimeCurrent() - lastCleanup > 3600) // Clean every hour
   {
      CleanOldSessionObjects();
      lastCleanup = TimeCurrent();
   }
   
   // Process each session
   for(int s = 0; s < 4; s++)
   {
      if(!sessions[s].show) continue;
      
      // Process each day's session
      datetime currentDate = 0;
      datetime sessionStart = 0;
      double sessionHigh = 0;
      double sessionLow = DBL_MAX;
      bool inSession = false;
      
      for(int i = MathMin(500, limit) - 1; i >= 0; i--)
      {
         if(IsInSession(sessions[s].time, time[i]))
         {
            if(!inSession)
            {
               sessionStart = time[i];
               sessionHigh = high[i];
               sessionLow = low[i];
               inSession = true;
            }
            else
            {
               sessionHigh = MathMax(sessionHigh, high[i]);
               sessionLow = MathMin(sessionLow, low[i]);
            }
         }
         else if(inSession)
         {
            // Draw session rectangle
            DrawSessionRectangle(s, sessionStart, time[i+1], sessionHigh, sessionLow);
            inSession = false;
         }
      }
      
      // Draw current session if still active
      if(inSession && sessionStart > 0)
      {
         DrawSessionRectangle(s, sessionStart, time[0] + PeriodSeconds(PERIOD_CURRENT), sessionHigh, sessionLow);
      }
   }
}

//+------------------------------------------------------------------+
//| Draw session rectangle with transparency workaround              |
//+------------------------------------------------------------------+
void DrawSessionRectangle(int sessionIndex, datetime t1, datetime t2, double price1, double price2)
{
   string name = objPrefix + "Session" + IntegerToString(sessionIndex) + "_" + TimeToString(t1, TIME_DATE|TIME_MINUTES);
   StringReplace(name, ":", "");
   StringReplace(name, " ", "_");
   
   // Delete old object if exists
   ObjectDelete(0, name);
   
   // Create rectangle with lighter color for transparency effect
   if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, price1, t2, price2))
   {
      // Create lighter color to simulate transparency
      color lightColor = GetLighterColor(sessions[sessionIndex].clr, sessions[sessionIndex].alpha);
      
      ObjectSetInteger(0, name, OBJPROP_COLOR, lightColor);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 0);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);  // Draw in background
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   }
   
   // Add border if enabled
   if(ShowSessionBorders)
   {
      string borderName = name + "_Border";
      ObjectDelete(0, borderName);
      
      if(ObjectCreate(0, borderName, OBJ_RECTANGLE, 0, t1, price1, t2, price2))
      {
         ObjectSetInteger(0, borderName, OBJPROP_COLOR, sessions[sessionIndex].clr);
         ObjectSetInteger(0, borderName, OBJPROP_STYLE, SessionBorderStyle);
         ObjectSetInteger(0, borderName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, borderName, OBJPROP_FILL, false);  // No fill for border
         ObjectSetInteger(0, borderName, OBJPROP_BACK, false);
         ObjectSetInteger(0, borderName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, borderName, OBJPROP_SELECTED, false);
      }
   }
   
   // Add session label
   if(ShowSessionLabels)
   {
      string labelName = name + "_Label";
      ObjectDelete(0, labelName);
      
      // Position label at top-left of session box
      if(ObjectCreate(0, labelName, OBJ_TEXT, 0, t1, price1))
      {
         ObjectSetString(0, labelName, OBJPROP_TEXT, sessions[sessionIndex].name);
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, sessions[sessionIndex].clr);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, SessionLabelFontSize);
         ObjectSetString(0, labelName, OBJPROP_FONT, FontName);
         ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
         ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
      }
   }
}

//+------------------------------------------------------------------+
//| Get lighter color to simulate transparency                       |
//+------------------------------------------------------------------+
color GetLighterColor(color baseColor, uchar alpha)
{
   // Extract RGB components
   int r = baseColor & 0xFF;
   int g = (baseColor >> 8) & 0xFF;
   int b = (baseColor >> 16) & 0xFF;
   
   // Blend with white based on alpha (0-255)
   // Lower alpha = more transparent = lighter color
   double blend = 1.0 - (alpha / 255.0);
   
   r = (int)(r + (255 - r) * blend);
   g = (int)(g + (255 - g) * blend);
   b = (int)(b + (255 - b) * blend);
   
   // Ensure values are in range
   r = MathMin(255, MathMax(0, r));
   g = MathMin(255, MathMax(0, g));
   b = MathMin(255, MathMax(0, b));
   
   return (color)((b << 16) | (g << 8) | r);
}

//+------------------------------------------------------------------+
//| Initialize timezone settings                                     |
//+------------------------------------------------------------------+
void InitializeTimezone()
{
   // Detect current timezone offset based on selection
   switch(SessionTimezone)
   {
      case TZ_BROKER:
         currentTimezoneOffset = 0; // Use broker time as-is
         break;
      case TZ_LOCAL:
         currentTimezoneOffset = (int)((TimeLocal() - TimeCurrent()) / 3600);
         break;
      case TZ_UTC:
         currentTimezoneOffset = (int)(TimeGMTOffset() / 3600);
         break;
      case TZ_NEWYORK:
         currentTimezoneOffset = GetNewYorkOffset();
         break;
      case TZ_LONDON:
         currentTimezoneOffset = GetLondonOffset();
         break;
      case TZ_TOKYO:
         currentTimezoneOffset = GetTokyoOffset();
         break;
      case TZ_SYDNEY:
         currentTimezoneOffset = GetSydneyOffset();
         break;
      case TZ_CUSTOM:
         currentTimezoneOffset = CustomUTCOffset;
         break;
   }
   
   // Auto-detect DST if enabled
   if(AutoDetectDST)
   {
      isDST = IsDaylightSavingTime();
   }
}

//+------------------------------------------------------------------+
//| Initialize sessions based on preset or custom                    |
//+------------------------------------------------------------------+
void InitializeSessions()
{
   // Apply preset if not custom
   if(SessionPreset != SESSION_CUSTOM)
   {
      ApplySessionPreset();
   }
   
   // Initialize session structures
   sessions[0].show = ShowSession1;
   sessions[0].time = Session1Time;
   sessions[0].clr = Session1Color;
   sessions[0].alpha = Session1Alpha;
   sessions[0].name = Session1Name;
   sessions[0].inSession = false;
   
   sessions[1].show = ShowSession2;
   sessions[1].time = Session2Time;
   sessions[1].clr = Session2Color;
   sessions[1].alpha = Session2Alpha;
   sessions[1].name = Session2Name;
   sessions[1].inSession = false;
   
   sessions[2].show = ShowSession3;
   sessions[2].time = Session3Time;
   sessions[2].clr = Session3Color;
   sessions[2].alpha = Session3Alpha;
   sessions[2].name = Session3Name;
   sessions[2].inSession = false;
   
   sessions[3].show = ShowSession4;
   sessions[3].time = Session4Time;
   sessions[3].clr = Session4Color;
   sessions[3].alpha = Session4Alpha;
   sessions[3].name = Session4Name;
   sessions[3].inSession = false;
}

//+------------------------------------------------------------------+
//| Apply session preset times                                       |
//+------------------------------------------------------------------+
void ApplySessionPreset()
{
   switch(SessionPreset)
   {
      case SESSION_FOREX:
         // Standard Forex sessions in UTC
         // These will be converted based on selected timezone
         // Note: These are example times, adjust as needed
         break;
      case SESSION_STOCKS_US:
         // US Stock Market hours (9:30 AM - 4:00 PM ET)
         break;
      case SESSION_STOCKS_EU:
         // European stock hours
         break;
      case SESSION_STOCKS_ASIA:
         // Asian stock hours
         break;
      case SESSION_CRYPTO:
         // 24/7 - no specific sessions
         break;
   }
}

//+------------------------------------------------------------------+
//| Check if current time is within session                          |
//+------------------------------------------------------------------+
bool IsInSession(string sessionTime, datetime barTime)
{
   // Parse session time (format: "HH:MM-HH:MM")
   string parts[];
   StringSplit(sessionTime, '-', parts);
   if(ArraySize(parts) != 2) return false;
   
   string startParts[], endParts[];
   StringSplit(parts[0], ':', startParts);
   StringSplit(parts[1], ':', endParts);
   
   if(ArraySize(startParts) != 2 || ArraySize(endParts) != 2) return false;
   
   int startHour = (int)StringToInteger(startParts[0]);
   int startMin = (int)StringToInteger(startParts[1]);
   int endHour = (int)StringToInteger(endParts[0]);
   int endMin = (int)StringToInteger(endParts[1]);
   
   // Apply timezone offset if needed
   datetime adjustedTime = barTime;
   if(currentTimezoneOffset != 0)
   {
      adjustedTime = barTime + (currentTimezoneOffset * 3600);
   }
   
   MqlDateTime dt;
   TimeToStruct(adjustedTime, dt);
   int barMinutes = dt.hour * 60 + dt.min;
   int startMinutes = startHour * 60 + startMin;
   int endMinutes = endHour * 60 + endMin;
   
   // Handle sessions that cross midnight
   if(endMinutes < startMinutes)
   {
      return (barMinutes >= startMinutes || barMinutes < endMinutes);
   }
   else
   {
      return (barMinutes >= startMinutes && barMinutes < endMinutes);
   }
}

//+------------------------------------------------------------------+
//| Get New York timezone offset                                     |
//+------------------------------------------------------------------+
int GetNewYorkOffset()
{
   // This is simplified - in production, use proper timezone library
   datetime gmt = TimeGMT();
   MqlDateTime dt;
   TimeToStruct(gmt, dt);
   
   // Check if DST is active (roughly March to November)
   bool isNYDST = (dt.mon >= 3 && dt.mon <= 11);
   
   return isNYDST ? -4 : -5; // EDT or EST
}

//+------------------------------------------------------------------+
//| Get London timezone offset                                       |
//+------------------------------------------------------------------+
int GetLondonOffset()
{
   datetime gmt = TimeGMT();
   MqlDateTime dt;
   TimeToStruct(gmt, dt);
   
   // Check if BST is active (roughly March to October)
   bool isLondonDST = (dt.mon >= 3 && dt.mon <= 10);
   
   return isLondonDST ? 1 : 0; // BST or GMT
}

//+------------------------------------------------------------------+
//| Get Tokyo timezone offset                                        |
//+------------------------------------------------------------------+
int GetTokyoOffset()
{
   return 9; // JST doesn't observe DST
}

//+------------------------------------------------------------------+
//| Get Sydney timezone offset                                       |
//+------------------------------------------------------------------+
int GetSydneyOffset()
{
   datetime gmt = TimeGMT();
   MqlDateTime dt;
   TimeToStruct(gmt, dt);
   
   // Australian DST is opposite (October to April)
   bool isSydneyDST = (dt.mon >= 10 || dt.mon <= 4);
   
   return isSydneyDST ? 11 : 10; // AEDT or AEST
}

//+------------------------------------------------------------------+
//| Check if daylight saving time is active                         |
//+------------------------------------------------------------------+
bool IsDaylightSavingTime()
{
   // Simplified DST detection - enhance based on specific requirements
   datetime gmt = TimeGMT();
   MqlDateTime dt;
   TimeToStruct(gmt, dt);
   
   // Northern hemisphere DST roughly March to November
   if(currentTimezoneOffset < 0) // Western hemisphere
   {
      return (dt.mon >= 3 && dt.mon <= 11);
   }
   else if(currentTimezoneOffset > 0 && currentTimezoneOffset < 8) // Europe
   {
      return (dt.mon >= 3 && dt.mon <= 10);
   }
   else if(currentTimezoneOffset >= 8) // Asia/Pacific
   {
      // Most Asian countries don't observe DST
      // Australia/NZ have opposite DST
      if(SessionTimezone == TZ_SYDNEY)
      {
         return (dt.mon >= 10 || dt.mon <= 4);
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Create timezone label in corner                                  |
//+------------------------------------------------------------------+
void CreateTimezoneLabel()
{
   string labelName = objPrefix + "TimezoneLabel";
   string tzText = GetTimezoneString();
   
   if(ObjectFind(0, labelName) < 0)
   {
      ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
   }
   
   ObjectSetString(0, labelName, OBJPROP_TEXT, tzText);
   ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, 30);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrGray);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
}

//+------------------------------------------------------------------+
//| Get timezone string for display                                  |
//+------------------------------------------------------------------+
string GetTimezoneString()
{
   string tz = "";
   
   switch(SessionTimezone)
   {
      case TZ_BROKER: tz = "Broker Time"; break;
      case TZ_LOCAL: tz = "Local Time"; break;
      case TZ_UTC: tz = "UTC/GMT"; break;
      case TZ_NEWYORK: tz = isDST ? "New York (EDT)" : "New York (EST)"; break;
      case TZ_LONDON: tz = isDST ? "London (BST)" : "London (GMT)"; break;
      case TZ_TOKYO: tz = "Tokyo (JST)"; break;
      case TZ_SYDNEY: tz = isDST ? "Sydney (AEDT)" : "Sydney (AEST)"; break;
      case TZ_CUSTOM: tz = "UTC" + (currentTimezoneOffset >= 0 ? "+" : "") + IntegerToString(currentTimezoneOffset); break;
   }
   
   return "TZ: " + tz;
}

//+------------------------------------------------------------------+
//| Reset bar counter static variables                               |
//+------------------------------------------------------------------+
void ResetBarCounter()
{
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
      color lightWeekendColor = GetLighterColor(WeekendColor, 30);
      ObjectSetInteger(0, weekendName, OBJPROP_COLOR, lightWeekendColor);
      ObjectSetInteger(0, weekendName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, weekendName, OBJPROP_WIDTH, 0);
      ObjectSetInteger(0, weekendName, OBJPROP_FILL, true);
      ObjectSetInteger(0, weekendName, OBJPROP_BACK, true);
   }
}

//+------------------------------------------------------------------+
//| Timer event - updates countdown display every second             |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Update timer display
   if(ShowCurrentBarTimer)
   {
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
//| Delete all objects created by this indicator                     |
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
//| Clean old session objects                                        |
//+------------------------------------------------------------------+
void CleanOldSessionObjects()
{
   // Keep objects for the last N days
   int daysToKeep = 10;
   datetime cutoffTime = TimeCurrent() - (daysToKeep * 86400);
   
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, objPrefix + "Session") == 0)
      {
         datetime objTime = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME);
         if(objTime < cutoffTime)
         {
            ObjectDelete(0, name);
         }
      }
   }
}

//+------------------------------------------------------------------+