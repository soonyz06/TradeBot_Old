#include<Trade\Trade.mqh>
#include <Math\Stat\Normal.mqh>
#define SIZE 2
//#property tester_everytick_calculate
CTrade trade;

input group "===   Inputs   ===";
input ulong Magic = 106;
input ENUM_TIMEFRAMES Timeframe = PERIOD_H1;
input double _R = 1; //FixedRisk
double FixedRisk;
double VariableRisk;
double MinLot;
double Lot;
int Mode;
double initial_balance;
input string Note = "";

input group "===   Settings   ===";
double TpATR; //TP
input double tpstd = 3; //TP STD
double SlATR; //SL
int TimeExit1; //Time Exit
double TriggerATR;
input int bb_len = 40; //BB Length
//input int std = 1; //Standard Deviation
int atr_len; //ATR Length

input group "===   Time   ===";
input int A = 16; //Start Time
int B; //Stop Time
int Z; //Exit Time
int E; //Expiration Time
//16:30-23:00

//Variables
string today;
string yesterday;
string yesterday2;
string yesterday3;
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
string text;
int buyPosition;
int sellPosition;
int buyDuration;
int sellDuration;

MqlRates Price[];
double Highest;
double Lowest;
double oldHigh;
double oldLow;
double ATR[];
int ATRHandler;
double Middle[];
double Upper[];
double Upper2[];
int BBHandler;
double Prices[][SIZE];
int BBHandler2;
double Row[SIZE];
double Upper_Custom[SIZE];
double Upper2_Custom[SIZE];
double Closes[];
int num_rows;
double _mean;
double _std;
//AAPL NVDA 90
//Rest 40
//NVDA 4
//AAPL, SPY, TSLA, META, NFLX, IBM, AMZN, JPM 3  
//COST, ETN, WMT, LLY, AXP, MS 2



//---------------------------------------------------------------------------------------------------------

void OnInit(){
   FixedRisk = _R/100;
   VariableRisk = 0;
   MinLot = 0.1;
   Highest = 0;
   Lowest = DBL_MAX;
   ArrayResize(Closes, bb_len);
   
   TpATR = -1;
   SlATR = 1;
   TimeExit1 = 10;
   TriggerATR = TpATR;
   atr_len = 15;
   Z = 17; //Exit Time
   B = 22; //Stop Time
   E = 18; //Expiration Time
   Trade_Start= string(A)+":55:00"; //Start Time
   Trade_Stop = string(B)+":55:00"; //Stop Time
   Trade_Exit = string(Z)+":00:00"; //Exit Time
   Trade_Expiration = string(E)+":00:00"; //Expiration Time
   buyDuration =-1;
   sellDuration =-1;
   Mode = 0;
   
   trade.SetExpertMagicNumber(Magic);
   text = string(Magic);
   bar1=0;
   bar2=0;
   bar3=0;
   yesterday="";
   yesterday2="";
   yesterday3="";
   initial_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   ArraySetAsSeries(Price, true);
   ArraySetAsSeries(ATR, true);
   ArraySetAsSeries(Middle, true);
   ArraySetAsSeries(Upper, true);
   ArraySetAsSeries(Upper2, true);
   ObjectCreate(0, "High", OBJ_HLINE, 0, 0, 0);
   ObjectCreate(0, "Low", OBJ_HLINE, 0, 0, 0);
   ObjectSetInteger(0, "High", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Low", OBJPROP_COLOR, clrWhite);
   ATRHandler = iATR(_Symbol, PERIOD_D1, atr_len); 
   BBHandler = iBands(_Symbol, Timeframe, bb_len, 0, 1, PRICE_CLOSE);
   BBHandler2 = iBands(_Symbol, Timeframe, bb_len, 0, tpstd, PRICE_CLOSE);
   Comment("ID: ", Magic);
   CheckPositions();
   Stop = StringToTime(TimeToString(TimeCurrent(), TIME_DATE)+" "+Trade_Stop);
}

void OnTick(){
   CopyBuffer(ATRHandler, 0, 0, 3, ATR);
   today = TimeToString(TimeCurrent(), TIME_DATE);
   if(today!=yesterday)
   {      
      Start = StringToTime(today+" "+Trade_Start);
      Exit = StringToTime(today+" "+Trade_Exit);
      Expiration = StringToTime(today+" "+Trade_Expiration);
      Filter = StringToTime(today+" "+"16:00:00");
      CopyBuffer(ATRHandler, 0, 0, 3, ATR);
      CheckPositions();
      yesterday=today;
   }


   newbar= iBars(_Symbol, Timeframe);
   if(bar2!=newbar){ //not precise
      if(buyPosition>0 && TimeCurrent()>=Exit){
         TimeExit();
         CheckPositions();
      }
      
      if(TimeCurrent()>=Filter){
         if(today!=yesterday3){
            CopyRates(_Symbol, Timeframe, Stop, 3, Price);
            Row[0] = Price[0].close;
            Row[1] = Price[0].open;
            AppendToArray(Row, Prices);  
            Stop = StringToTime(today+" "+Trade_Stop);
            yesterday3 = today;
         }
      }
      
      CopyRates(_Symbol, Timeframe, 0, 3, Price);
      CopyBuffer(BBHandler, 1, 0, 3, Upper);
      CopyBuffer(BBHandler2, 1, 0, 3, Upper2);
      
      if(TimeCurrent()>Start && TimeCurrent()<Stop){ //17-22
         Row[0] = Price[1].close;
         Row[1] = Price[1].open;
         AppendToArray(Row, Prices);
      }
      bar2=newbar;
   }
   
   if(bar1!=newbar){ //precise
      if(TimeCurrent()>=Start && TimeCurrent()<Stop){
         CheckPositions();
         if(ArraySize(Prices)/SIZE==bb_len && Prices[bb_len-2][0]>Upper2_Custom[1] && Prices[bb_len-1][0]<Upper2_Custom[0]){
         //if(Price[2].close>Upper2[2] && Price[1].close<Upper2[1]){
            if(buyPosition>0)
            ClosePosition(POSITION_TYPE_BUY);
         }
         
         if(ArraySize(Prices)/SIZE==bb_len && Prices[bb_len-1][0]>Upper_Custom[0] && Prices[bb_len-2][0]<Upper_Custom[1] && Prices[bb_len-1][0]<Upper2_Custom[0] && (ATR[1]!=0 && ATR[1]<1000)){ //Prices[bb_len-1][0]>Prices[bb_len-1][1]
         //if(Price[1].close>Upper[1] && Price[2].close<Upper[2] && Price[1].close<Upper2[1] && (ATR[1]!=0 && ATR[1]<1000)){
           if(buyPosition==0){
               ExecuteBuy(); //bi?
            }
         }
         bar1=newbar;
      }
   }
}



//---------------------------------------------------------------------------------------------------------



void PositionSize(){
   if(VariableRisk<=0 && FixedRisk<=0){
      Lot = MinLot;
   }
   else if(MinLot<0.1)
   {
      double slpoints = (ATR[1]*SlATR)/_Point;
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
      if(FixedRisk>0){
         Lot = MathRound((initial_balance*FixedRisk)/(ATR[1]*SlATR)/MinLot)*MinLot;
      }
      else{
         int _rounded_balance = int(AccountInfoDouble(ACCOUNT_BALANCE)/10)*10;
         Lot = MathRound((_rounded_balance*VariableRisk)/(ATR[1]*SlATR)/MinLot)*MinLot;
      }
   }
   if(Lot<MinLot) Lot=MinLot;
   if(Lot>1000) Lot=1000;
}

void ExecuteBuy(double slpoints=NULL, double tppoints=NULL){
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(tppoints==NULL && Mode==0 && TpATR>0) tppoints = Ask+TpATR*ATR[1];
   if(slpoints==NULL && SlATR>0) slpoints = Ask-SlATR*ATR[1];
   
   PositionSize();
   trade.Buy(Lot, _Symbol, Ask, slpoints, tppoints, text);
}

void ExecuteSell(double slpoints=NULL, double tppoints=NULL){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   if(tppoints==NULL && Mode==0 && TpATR>0) tppoints = Bid-TpATR*ATR[1];
   if(slpoints==NULL && SlATR>0) slpoints = Bid+SlATR*ATR[1];
   
   PositionSize();
   trade.Sell(Lot, _Symbol, Bid, slpoints, tppoints, text);
}

void ExecuteBuyStop(double entry, double sl=NULL, double tp=NULL){
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   if(Ask>entry) return;
   double _sl = sl;
   double _tp = tp;
   
   if(sl==NULL && SlATR>0) _sl=entry-SlATR*ATR[1];
   if(tp==NULL && TpATR>0 && Mode==0) _tp=entry+TpATR*ATR[1];
   PositionSize();
   trade.BuyStop(Lot, entry, _Symbol, _sl, _tp, NULL, NULL, text);
   
}

void ExecuteSellStop(double entry, double sl=NULL, double tp=NULL){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   if(Bid<entry) return;
   double _sl = sl;
   double _tp = tp;
   
   if(sl==NULL && SlATR>0) _sl=entry+SlATR*ATR[1];
   if(tp==NULL && TpATR>0 && Mode==0) _tp=entry-TpATR*ATR[1];
   PositionSize();
   trade.SellStop(Lot, entry, _Symbol, _sl, _tp, NULL, NULL, text);
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
   if(ArraySize(ATR)>1) Comment("ID: ", Magic, "\nBuy Duration: ", buyDuration, "\nSell Duration: ", sellDuration, "\nATR: ", NormalizeDouble(ATR[1], 3), " \nBB Length: ", bb_len," \n", Note);
   else Comment("ID: ", Magic, "\nBuy Duration: ", buyDuration, "\nSell Duration: ", sellDuration, " \nBB Length: ", bb_len," \n", Note);
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

bool InProfit(ENUM_POSITION_TYPE type){
   ulong _ticket;
   double _profitMargin;
   
   for(int i=0; i<PositionsTotal(); i++){
      _ticket = PositionGetTicket(i);
      
      if (PositionSelectByTicket(_ticket))
      {
         if (PositionGetInteger(POSITION_MAGIC)==Magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY){
               _profitMargin = PositionGetDouble(POSITION_PRICE_CURRENT)-PositionGetDouble(POSITION_PRICE_OPEN);
               TriggerATR=TpATR;
            }
            else{
               _profitMargin = PositionGetDouble(POSITION_PRICE_OPEN)-PositionGetDouble(POSITION_PRICE_CURRENT);
               TriggerATR=TpATR;
            }
            
            if(type == PositionGetInteger(POSITION_TYPE) && _profitMargin>TriggerATR*ATR[1]){
               return true;
            }
         }
      }
   }
   return false;
}

void ProcessPosition(){ 
   if(TriggerATR<0 || Mode==0) return;
   //if(buyDuration<3) return; 
   if(InProfit(POSITION_TYPE_BUY)){
      ClosePosition(POSITION_TYPE_BUY);
   }
   if(InProfit(POSITION_TYPE_SELL)){
      ClosePosition(POSITION_TYPE_SELL);
   }
}

void Range(int bars){
   if(bars<=0) return; 
   
   Highest = iHigh(_Symbol, Timeframe, iHighest(_Symbol, Timeframe, MODE_HIGH, bars, 2));
   Lowest = iLow(_Symbol, Timeframe, iLowest(_Symbol, Timeframe, MODE_LOW, bars, 2));
   
   if(Highest!=oldHigh){
      ObjectMove(0, "High", 0, 0, Highest);
      oldHigh = Highest;
   }
   if(Lowest!=oldLow){
      ObjectMove(0, "Low", 0, 0, Lowest);
      oldLow = Lowest; 
   }
}

void AppendToArray(double &row[], double &prices[][SIZE]){
   num_rows = ArraySize(prices)/SIZE;
   ArrayResize(prices,  num_rows+ 1);
   num_rows = ArraySize(prices)/SIZE;
         
   for (int col = 0; col < SIZE; col++){
      prices[num_rows - 1][col] = row[col];
   }
        
   if(num_rows>bb_len){
      for (int i = 0; i < num_rows-1; i++){
         Closes[i] = prices[i][0];
      }
      _std = MathStandardDeviation(Closes);
      _mean = MathMean(Closes);
      Upper_Custom[1] = _mean+_std; 
      Upper2_Custom[1] = _mean+tpstd*_std; 
      
      for (int i = 0; i < num_rows-1; i++){
         Closes[i] = prices[i+1][0];
      }
      _std = MathStandardDeviation(Closes);
      _mean = MathMean(Closes);
      Upper_Custom[0] = _mean+_std; 
      Upper2_Custom[0] = _mean+tpstd*_std; 
      
      for (int i = 1; i < num_rows; i++) {
         for (int col = 0; col < SIZE; col++){
            prices[i-1][col] = prices[i][col];
         }
      }
      ArrayResize(prices, num_rows-1);
      num_rows = ArraySize(prices)/SIZE;
    }
    
    //Print(TimeCurrent());
    //Print("Upper_Custom[0]", Upper_Custom[0]);
    //Print("Upper_Custom[1]", Upper_Custom[1]);
    //Print("Upper2_Custom[0]", Upper2_Custom[0]);
    //Print("Upper2_Custom[1]", Upper2_Custom[1]);
    //if(num_rows>2){
    //  for (int i = num_rows-2; i < num_rows; i++) {
    //     Print("Prices[", i, "][", 0, "]: ", MathRound(prices[i][0]*100)/100);
    //  }
    //}
}