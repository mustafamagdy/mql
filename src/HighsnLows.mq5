//+------------------------------------------------------------------+
//|                                                        Highs.mq5 |
//+------------------------------------------------------------------+
#property version   "1.19"
#property indicator_chart_window
#property indicator_plots   0
#property indicator_buffers 0

// --- Which levels
input bool InpShowDay   = true;
input bool InpShowWeek  = true;
input bool InpShowMonth = true;

// --- Mode: previous (PDH/PDL/…) vs current period so far
enum HLMode { HL_Previous=0, HL_Current=1 };
input group "Mode per timeframe"
input HLMode InpDayMode   = HL_Previous;  // set HL_Current to make today's high/low update live
input HLMode InpWeekMode  = HL_Previous;
input HLMode InpMonthMode = HL_Previous;

// --- Line style
input group "Line style"
input ENUM_LINE_STYLE InpStyleDay    = STYLE_SOLID;
input ENUM_LINE_STYLE InpStyleWeek   = STYLE_DASH;
input ENUM_LINE_STYLE InpStyleMonth  = STYLE_DOT;
input int             InpWidthDay    = 2;
input int             InpWidthWeek   = 2;
input int             InpWidthMonth  = 2;
input color           InpColDayHigh   = clrDodgerBlue;
input color           InpColDayLow    = clrDeepPink;
input color           InpColWeekHigh  = clrOrangeRed;
input color           InpColWeekLow   = clrTomato;
input color           InpColMonthHigh = clrMediumOrchid;
input color           InpColMonthLow  = clrHotPink;

// --- Labels
input group "Labels"
input bool   InpShowLabels        = true;
input bool   InpLabelsOnScreen    = true;     // glue to right margin
input string InpLabelFont         = "Arial";
input int    InpLabelSize         = 10;
input double InpLabelOffsetPips   = 3.0;      // vertical offset in pips
input int    InpLabelPadRightPx   = 56;       // padding from right edge (bigger = more to the left)

// --- Chart behavior
input group "Chart behavior"
input bool   InpObjectsOnTop      = true;

// --- Names
#define PFX "HL_"
string N_PDH=PFX"PDH", N_PDL=PFX"PDL";
string N_PWH=PFX"PWH", N_PWL=PFX"PWL";
string N_PMH=PFX"PMH", N_PML=PFX"PML";

// --- State
double Pt, Pip; int DigitsSym;
bool   gUpdating=false;

// ---------- Helpers
bool IsDescending(const datetime &time[]){ int n=ArraySize(time); return (n<2) ? true : (time[0] >= time[n-1]); }
int  SeriesToArrayIndex(long sidx, int bars, bool desc)
{ if(desc) return (int)MathMax(0, MathMin(sidx,(long)(bars-1))); long inv=(long)bars-1-sidx; if(inv<0) inv=0; if(inv>bars-1) inv=bars-1; return (int)inv; }

bool RightEdgeTime(const datetime &time[], datetime &tRight)
{
  int bars=ArraySize(time); if(bars<=0) return false;
  long first_series=(long)ChartGetInteger(0,CHART_FIRST_VISIBLE_BAR,0);
  long vis_cnt=(long)ChartGetInteger(0,CHART_VISIBLE_BARS,0);
  if(first_series<0||vis_cnt<=0) return false;
  long right_series=first_series-(vis_cnt-1); if(right_series<0) right_series=0;
  bool desc=IsDescending(time);
  int idx=SeriesToArrayIndex(right_series,bars,desc);
  tRight=time[idx];
  return true;
}

// Get period window & hi/lo for previous or current bar (uses correct CopyRates overloads)
bool PeriodWindow(ENUM_TIMEFRAMES tf, HLMode mode, datetime &tStart, datetime &tEnd, double &hi, double &lo)
{
  if(mode==HL_Previous)
  {
    MqlRates prev[1], curr[1];
    if(CopyRates(_Symbol, tf, 1, 1, prev)!=1) return false; // previous closed
    if(CopyRates(_Symbol, tf, 0, 1, curr)!=1) return false; // current (right boundary)
    tStart = prev[0].time;  // prev open
    tEnd   = curr[0].time;  // current open
    hi     = prev[0].high;
    lo     = prev[0].low;
  }
  else // HL_Current
  {
    MqlRates nowbar[1];
    if(CopyRates(_Symbol, tf, 0, 1, nowbar)!=1) return false; // current bar (open/hi/lo)
    tStart = nowbar[0].time; // start of the period
    tEnd   = TimeCurrent();  // now
    hi     = nowbar[0].high; // high/low so far in this period
    lo     = nowbar[0].low;
  }
  return true;
}

// Find wick times inside [tStart, tEnd)
void FindHiLoTimes(const datetime &time[], const double &high[], const double &low[],
                   datetime tStart, datetime tEnd,
                   datetime &tHi, datetime &tLo, bool &gotHi, bool &gotLo)
{
  int n=ArraySize(time);
  double maxHi=-DBL_MAX, minLo=DBL_MAX; gotHi=false; gotLo=false; tHi=tStart; tLo=tStart;
  for(int i=0;i<n;i++)
  {
    datetime t=time[i];
    if(t < tStart || t >= tEnd) continue;
    if(high[i] > maxHi){ maxHi=high[i]; tHi=t; gotHi=true; }
    if(low[i]  < minLo){ minLo=low[i];  tLo=t; gotLo=true; }
  }
}

// ---------- Objects
void BringToFront(const string name)
{ ObjectSetInteger(0,name,OBJPROP_BACK,false); ObjectSetInteger(0,name,OBJPROP_HIDDEN,false); }

void EnsureType(const string name, ENUM_OBJECT expect)
{
  if(ObjectFind(0,name)>=0)
  {
    ENUM_OBJECT t=(ENUM_OBJECT)ObjectGetInteger(0,name,OBJPROP_TYPE);
    if(t!=expect) ObjectDelete(0,name);
  }
}

void UpsertLongSegmentRight(const string name, datetime tLeft, double price,
                            color col, ENUM_LINE_STYLE style, int width)
{
  price=NormalizeDouble(price,DigitsSym);
  datetime tRight = tLeft + (datetime)(10*365*24*60*60); // ~10 years
  EnsureType(name,OBJ_TREND);
  if(ObjectFind(0,name)<0)
  {
    if(!ObjectCreate(0,name,OBJ_TREND,0,tLeft,price,tRight,price)) return;
    ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
    ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false);
    ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
    BringToFront(name);
  }
  ObjectMove(0,name,0,tLeft,price);
  ObjectMove(0,name,1,tRight,price);
  ObjectSetInteger(0,name,OBJPROP_COLOR,col);
  ObjectSetInteger(0,name,OBJPROP_STYLE,style);
  ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
}

// Screen-anchored label at right margin
void UpsertLabel_SCREEN(const string name, const string text, datetime tRef, double price,
                        color col, bool above)
{
  double off = (DigitsSym>=3 ? 10.0*Pt : Pt) * InpLabelOffsetPips;
  double yPrice = price + (above? +off : -off);

  int xpx, ypx;
  if(!ChartTimePriceToXY(0,0,tRef,yPrice,xpx,ypx)) return;

  EnsureType(name,OBJ_LABEL);
  if(ObjectFind(0,name)<0)
  {
    if(!ObjectCreate(0,name,OBJ_LABEL,0,0,0)) return;
    ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
    ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
    BringToFront(name);
  }
  ObjectSetString (0,name,OBJPROP_TEXT,text);
  ObjectSetInteger(0,name,OBJPROP_COLOR,col);
  ObjectSetInteger(0,name,OBJPROP_FONTSIZE,InpLabelSize);
  ObjectSetString (0,name,OBJPROP_FONT,InpLabelFont);

  // move a bit **left** from the right edge (padding)
  ObjectSetInteger(0,name,OBJPROP_XDISTANCE, InpLabelPadRightPx);
  ObjectSetInteger(0,name,OBJPROP_YDISTANCE, ypx);
}

// Draw one timeframe block
void DrawTF(const string nHigh, const string nLow,
            ENUM_TIMEFRAMES tf, HLMode mode,
            color colHigh, color colLow,
            ENUM_LINE_STYLE style, int width,
            const string lblHigh, const string lblLow,
            const datetime &time[], const double &high[], const double &low[])
{
  datetime tStart,tEnd; double hi,lo;
  if(!PeriodWindow(tf,mode,tStart,tEnd,hi,lo)) return;

  datetime tHi,tLo; bool gotHi,gotLo;
  FindHiLoTimes(time,high,low,tStart,tEnd,tHi,tLo,gotHi,gotLo);
  if(!gotHi) tHi=tStart;
  if(!gotLo) tLo=tStart;

  UpsertLongSegmentRight(nHigh,tHi,hi,colHigh,style,width);
  UpsertLongSegmentRight(nLow ,tLo,lo,colLow ,style,width);

  if(!InpShowLabels) return;
  datetime tRight; if(!RightEdgeTime(time,tRight)) tRight=time[0];
  UpsertLabel_SCREEN(nHigh+"_LBL",lblHigh,tRight,hi,colHigh,true);
  UpsertLabel_SCREEN(nLow +"_LBL",lblLow ,tRight,lo,colLow ,false);
}

// ---------- Events
int OnInit()
{
  Pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
  DigitsSym=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
  Pip=(DigitsSym>=3 ? 10.0*Pt : Pt);
  if(InpObjectsOnTop) ChartSetInteger(0,CHART_FOREGROUND,false);
  EventSetTimer(5); // refresh labels even without ticks
  return INIT_SUCCEEDED;
}

void OnDeinit(const int reason){ EventKillTimer(); }

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
  if(rates_total<1 || gUpdating) return rates_total;
  gUpdating=true;

  if(InpShowDay)
    DrawTF(N_PDH,N_PDL,PERIOD_D1,InpDayMode,  InpColDayHigh,InpColDayLow,InpStyleDay,InpWidthDay,"PDH","PDL",
           time,high,low);
  if(InpShowWeek)
    DrawTF(N_PWH,N_PWL,PERIOD_W1,InpWeekMode, InpColWeekHigh,InpColWeekLow,InpStyleWeek,InpWidthWeek,"PWH","PWL",
           time,high,low);
  if(InpShowMonth)
    DrawTF(N_PMH,N_PML,PERIOD_MN1,InpMonthMode,InpColMonthHigh,InpColMonthLow,InpStyleMonth,InpWidthMonth,"PMH","PML",
           time,high,low);

  gUpdating=false;
  return rates_total;
}

void OnTimer(){ ChartRedraw(); }
//+------------------------------------------------------------------+