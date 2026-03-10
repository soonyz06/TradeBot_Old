#include<Trade\Trade.mqh>
CTrade trade;
//#property tester_everytick_calculate

input group "===   Inputs   ===";
input ulong Magic = 130;
ENUM_TIMEFRAMES Timeframe = PERIOD_D1;
input double _R = 1; //FixedRisk
double FixedRisk;
double VariableRisk;
input double MinLot = 0.1;
double Lot;
int Mode;
double initial_balance;
input bool hold = false; //Hold
string Note = "";

input group "===   Settings   ===";
double TpATR1; //TP
input double SlATR = 0; //SL
input double RangeATR = 0; //Range
int TimeExit1; //Time Exit
input int Confirmation = 15; 
int ma_len; //MA Length
int atr_len;

input group "===   Time   ===";
int A; //Start Time
int B; //Stop Time
input int Z = 22; //Trade Time
int E; //Expiration Time
//16:30-23:00

//Variables
string today;
string yesterday;
string yesterday2;
datetime Start;
datetime Stop;
datetime Exit;
datetime Expiration;
datetime Filter;
string Trade_Start; //Start Time
string Trade_Stop; //Stop Time
string Trade_Exit; //Exit Time
string Trade_Expiration; //Expiration Time
int bar1;
int bar2;
int bar3;
int newbar;
int newbar2;
string text;
int buyPosition;
int sellPosition;
int buyDuration;
int sellDuration;
double TriggerATR;

MqlRates Price[];
double Close[];
double Open[];
double Highest;
double Lowest;
double oldHigh;
double oldLow;
double ATR[];
int ATRHandler;
bool flag;
double MA[];
int MAHandler;
double Upper[];
int BBHandler;



//expiration or sl or flag
//trail or ma or range
//---------------------------------------------------------------------------------------------------------



void OnInit(){
   FixedRisk = _R/100;
   VariableRisk = 0;
   Highest = 0;
   Lowest = DBL_MAX;
   
   TpATR1 = -1;
   //SlATR = 1;
   TimeExit1 = -1;
   TriggerATR = 0;
   atr_len = Confirmation;
   ma_len = 10;
   A = 16;
   //Z = 22; //Exit Time
   B = 20; //Stop Time
   E = B; //Expiration Time
   Trade_Start= string(A)+":55:00"; 
   Trade_Stop = string(B)+":55:00"; 
   Trade_Exit = string(Z)+":35:00"; 
   Trade_Expiration = string(E)+":00:00"; 
   buyDuration =-1;
   sellDuration =-1;
   Mode = 0;
   flag=true;
   
   trade.SetExpertMagicNumber(Magic);
   text = string(Magic);
   bar1=0;
   bar2=0;
   bar3=0;
   yesterday="";
   yesterday2="";
   initial_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   ArraySetAsSeries(Price, true);
   ArraySetAsSeries(Close, true);
   ArraySetAsSeries(Open, true);
   ArraySetAsSeries(ATR, true);
   ArraySetAsSeries(Upper, true);
   ArraySetAsSeries(MA, true);
   ObjectCreate(0, "High", OBJ_HLINE, 0, 0, 0);
   ObjectCreate(0, "Low", OBJ_HLINE, 0, 0, 0);
   ObjectSetInteger(0, "High", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Low", OBJPROP_COLOR, clrWhite);
   ObjectCreate(0, "Trend", OBJ_HLINE, 0, 0, 0);
   ObjectSetInteger(0, "Trend", OBJPROP_COLOR, clrWheat);
   ATRHandler = iATR(_Symbol, PERIOD_D1, atr_len);
   //MAHandler = iMA(_Symbol, Timeframe, ma_len, 0, MODE_SMA, PRICE_CLOSE);
   //BBHandler = iBands(_Symbol, Timeframe, 10, 0, 1, PRICE_CLOSE);
   Comment("ID: ", Magic);
   CheckPositions();
   VisualiseRange(Confirmation);
}

void OnTick(){
   today = TimeToString(TimeCurrent(), TIME_DATE);
   if(today!=yesterday)
   {      
      Start = StringToTime(today+" "+Trade_Start);
      Stop = StringToTime(today+" "+Trade_Stop);
      Exit = StringToTime(today+" "+Trade_Exit);
      Expiration = StringToTime(today+" "+Trade_Expiration);
      CopyBuffer(ATRHandler, 0, 0, 2, ATR);
      yesterday=today;
   }
   
   if(hold){
      Hold();
      return;
   }
   
   newbar = iBars(_Symbol, Timeframe);   
   if(bar1!=newbar){ 
      if(TimeCurrent()>=Start && TimeCurrent()<Stop){
         //Here if(Price[0].close>=Highest) ExecuteBuy();
         bar1=newbar;
      }
   }
   
   if(bar2!=newbar){ 
      if(TimeCurrent()>=Exit){
         CopyRates(_Symbol, Timeframe, 0, 2, Price);
         CheckPositions();
        
         Range(Confirmation);
         flag = Highest-Lowest>ATR[0]*RangeATR;
         TrailPosition(POSITION_TYPE_BUY); //
         CheckPositions();
         
         if(buyPosition==0 && flag && (ATR[0]!=0 && ATR[0]<1000)){
            ExecuteBuyStop(Highest, Lowest);
         }
         bar2=newbar;
      }
   }
}



//---------------------------------------------------------------------------------------------------------



void PositionSize(double SL){
   double _Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(VariableRisk<=0 && FixedRisk<=0){
      Lot = MinLot;
   }
   else if(MinLot<0.1)
   {
      double slpoints;
      if(SlATR<0) slpoints = _Ask; else slpoints = SL/_Point;
      string Curr1 = StringSubstr(_Symbol, 0, 3);
      string Curr2 = StringSubstr(_Symbol, 3, 3);
      if(FixedRisk>0){
         Lot = initial_balance*FixedRisk/slpoints;
      }
      else{
         int _rounded_balance = int(AccountInfoDouble(ACCOUNT_BALANCE)/10)*10;
         Lot = _rounded_balance*VariableRisk/slpoints;
      }
      if (Curr2 == "USD"){
         
      }
      else if(Curr2=="JPY"){
         double Ask2 = NormalizeDouble(SymbolInfoDouble("USD"+Curr2, SYMBOL_ASK), _Digits);
         Lot = Lot*Ask2/100;
      }
      else{
         double Ask2 = NormalizeDouble(SymbolInfoDouble("USD"+Curr2, SYMBOL_ASK), _Digits);
         double Bid2 = NormalizeDouble(SymbolInfoDouble(Curr2+"USD", SYMBOL_BID), _Digits);
         Lot = Lot*Ask2;
         if(Lot==0)
            Lot = Lot/Bid2;
      }
      Lot = MathRound(Lot/MinLot)*MinLot;
   }
   else{
      if(SlATR<0) SL = _Ask; 
      if(FixedRisk>0){
         Lot = MathRound((initial_balance*FixedRisk)/(SL)/MinLot)*MinLot;
      }
      else{
         int _rounded_balance = int(AccountInfoDouble(ACCOUNT_BALANCE)/10)*10;
         Lot = MathRound((_rounded_balance*VariableRisk)/(SL)/MinLot)*MinLot;
      }
   }
   if(Lot<MinLot) Lot=MinLot;
   if(Lot>1000) Lot=1000;
}

void ExecuteBuyStop(double entry, double sl=NULL, double tp=NULL){
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(Ask>entry) return;
   double _sl = sl;
   double _tp = tp;
   
   if(sl==NULL && SlATR>0) _sl=entry-SlATR*ATR[0];
   if(sl==NULL && SlATR==0) _sl = Lowest;
   if(tp==NULL && TpATR1>0 && Mode==0) _tp=entry+TpATR1*ATR[0];
   PositionSize(entry-_sl);
   trade.BuyStop(Lot, entry, _Symbol, _sl, _tp, NULL, NULL, text);
}

void CheckPositions(){     
   buyPosition=0;
   sellPosition=0;
   buyDuration = -1;
   sellDuration = -1;
   
   ulong _ticket;
   
   for(int i=0; i<OrdersTotal(); i++){
      _ticket = OrderGetTicket(i);
         
      if(OrderSelect(_ticket)){
         if(OrderGetInteger(ORDER_MAGIC) == Magic && OrderGetString(ORDER_SYMBOL) == _Symbol){
            if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP || OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT){
               buyPosition+=1;
            }
            else if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP ||OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT){
               sellPosition+=1;
            }
         }
      }
   }
   
   for(int i=0; i<PositionsTotal(); i++){
      _ticket = PositionGetTicket(i);
      
      if(PositionSelectByTicket(_ticket)){
         if(PositionGetInteger(POSITION_MAGIC) == Magic && PositionGetString(POSITION_SYMBOL) == _Symbol){
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
               buyPosition+=1;
               buyDuration = iBarShift(_Symbol, PERIOD_D1, PositionGetInteger(POSITION_TIME), false);
            }
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
               sellPosition+=1;
               sellDuration = iBarShift(_Symbol, PERIOD_D1, PositionGetInteger(POSITION_TIME), false);
            }
         }
      }
   }
   
   //if(ArraySize(ATR)>1) Comment("ID: ", Magic, "\nBuy Duration: ", buyDuration, "\nSell Duration: ", sellDuration, "\nATR: ", NormalizeDouble(ATR[0], 3), "\n", Note);
   //else Comment("ID: ", Magic, "\nBuy Duration: ", buyDuration, "\nSell Duration: ", sellDuration, "\n", Note);
}

void TimeExit(){
   if(buyDuration>=TimeExit1 && TimeExit1>=0) ClosePosition(POSITION_TYPE_BUY);
   if(sellDuration>=TimeExit1 && TimeExit1>=0) ClosePosition(POSITION_TYPE_SELL);
}

void ClosePosition(ENUM_POSITION_TYPE _type){
   int _closed = 0;
   int i;
   ulong _ticket;
   int total = PositionsTotal();
   for(int j =0; j<total; j++)
   {
      i = j-_closed;      
      _ticket = PositionGetTicket(i);
      
      if (PositionSelectByTicket(_ticket))
      {
         if (PositionGetInteger(POSITION_MAGIC)==Magic && PositionGetString(POSITION_SYMBOL)== _Symbol)
         {
            if(PositionGetInteger(POSITION_TYPE) == _type)
            {
               trade.PositionClose(_ticket);
               _closed +=1;
            }
         }
      }
   }
}

void CloseOrder(ENUM_ORDER_TYPE _type){
   int _closed = 0;
   int i;
   ulong _ticket;
   int total = OrdersTotal();
   for(int j =0; j<total; j++)
   {
      i = j-_closed;      
      _ticket = OrderGetTicket(i);
      
      if (OrderSelect(_ticket))
      {
         if (OrderGetInteger(ORDER_MAGIC)==Magic && OrderGetString(ORDER_SYMBOL)== _Symbol)
         {
            if(OrderGetInteger(ORDER_TYPE) == _type)
            {
               trade.OrderDelete(_ticket);
               _closed +=1;
            }
         }
      }
   }
}

void VisualiseRange(int bars){
   if(bars<=0) return; 
   CopyClose(_Symbol, Timeframe, 0, bars, Close); ///
   CopyOpen(_Symbol, Timeframe, 0, bars, Open); ///
   Highest = NormalizeDouble(Close[ArrayMaximum(Close, 0, WHOLE_ARRAY)], _Digits);
   Lowest = NormalizeDouble(Close[ArrayMinimum(Close, 0, WHOLE_ARRAY)], _Digits);
   ObjectMove(0, "High", 0, 0, Highest);
   ObjectMove(0, "Low", 0, 0, Lowest);
}

void Range(int bars){
   if(bars<=0) return; 
   CopyClose(_Symbol, Timeframe, 0, bars, Close); ///
   CopyOpen(_Symbol, Timeframe, 0, bars, Open); ///
   ///Highest = MathMax(NormalizeDouble(Close[ArrayMaximum(Close, 0, WHOLE_ARRAY)], _Digits), NormalizeDouble(Open[ArrayMaximum(Open, 0, WHOLE_ARRAY)], _Digits));
   //Lowest = MathMin(NormalizeDouble(Close[ArrayMinimum(Close, 0, WHOLE_ARRAY)], _Digits), NormalizeDouble(Open[ArrayMinimum(Open, 0, WHOLE_ARRAY)], _Digits));
   Highest = NormalizeDouble(Close[ArrayMaximum(Close, 0, WHOLE_ARRAY)], _Digits);
   Lowest = NormalizeDouble(Close[ArrayMinimum(Close, 0, WHOLE_ARRAY)], _Digits);
   
   if(Highest!=oldHigh){
      ObjectMove(0, "High", 0, 0, Highest);
      CloseOrder(ORDER_TYPE_BUY_STOP); 
      oldHigh = Highest;
   }
   if(Lowest!=oldLow){
      ObjectMove(0, "Low", 0, 0, Lowest);
      //CloseOrder(ORDER_TYPE_BUY_STOP);
      oldLow = Lowest; 
   }
   
   //CopyClose(_Symbol, Timeframe, 150, 1, MA);
   //ObjectMove(0, "Trend", 0, 0, MA[0]);
   //if(Highest>=MA[0]) ObjectSetInteger(0, "Trend", OBJPROP_COLOR, clrLime); else ObjectSetInteger(0, "Trend", OBJPROP_COLOR, clrTomato);
}

void Hold(){
   newbar = -1;
   if(bar1!=newbar){
      if(TimeCurrent()>=Start){
         double _Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
         Lot = MathMax(MathRound((initial_balance*FixedRisk)/(_Ask)/MinLot)*MinLot, MinLot);
         trade.Buy(Lot, _Symbol, _Ask, NULL, NULL, text);
         bar1=newbar;
      }
   }
}

void TrailPosition(ENUM_POSITION_TYPE _type){
   ulong _ticket;
   double _sl = -1;
   for(int i=0; i<PositionsTotal(); i++){
      _ticket = PositionGetTicket(i);
      
      if(PositionSelectByTicket(_ticket)){
         if(PositionGetInteger(POSITION_MAGIC) == Magic && PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_TYPE)== _type){
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
               if(SlATR==0){
                  if(flag) _sl = Lowest; 
               }            
               else{
                  _sl = Price[0].close-ATR[0]*SlATR;
               }
               if(SlATR>=0 && _sl>PositionGetDouble(POSITION_SL)) trade.PositionModify(_ticket, _sl, NULL);
            }    
         }
      }
   }
}