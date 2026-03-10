#include<Trade\Trade.mqh>
#include <Math\Stat\Normal.mqh>
#define SIZE 2
//#property tester_everytick_calculate
CTrade trade;

input group "===   Inputs   ===";
input ulong Magic = 109;
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
double TpATR1; //TP
double TpATR2; 
input double SlATR = 1; //SL
input int TimeExit1 = 5; //Time Exit
int TimeExit2;
double TriggerATR;
input int bb_len = 50; //BB Length
double std; //Standard Deviation
int atr_len; //ATR Length
int Confirmation;
//AVGO MU 60 10
//INTU 40 5
//PGR 2.5 50 5


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
string Trade_Start;
string Trade_Stop;
string Trade_Exit;
string Trade_Expiration;
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
double High[];
double Low[];
double Highest;
double Lowest;
double oldHigh;
double oldLow;
double ATR[];
int ATRHandler;
double Upper[];
double Lower[];
double Middle[];
int BBHandler;
double Row[SIZE];
double Prices[][SIZE];
double Upper_Custom[SIZE];
double Lower_Custom[SIZE];
double Closes[];



//---------------------------------------------------------------------------------------------------------



void OnInit(){
   FixedRisk = _R/100;
   VariableRisk = 0;
   MinLot = 0.1;
   TimeExit2 = TimeExit1;
   Highest = 0;
   Lowest = DBL_MAX;
   ArrayResize(Closes, bb_len);
   
   TpATR1 = -1;
   TpATR2 = TpATR1;
   TriggerATR = 0;
   Confirmation = -10;
   std = 1;
   atr_len = 50; 
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
   bar1=-1;
   bar2=-1;
   bar3=-1;
   yesterday="";
   yesterday2="";
   yesterday3="";
   initial_balance = AccountInfoDouble(ACCOUNT_BALANCE); //*0.74 currency exchange
   ArraySetAsSeries(Price, true);
   ArraySetAsSeries(High, true);
   ArraySetAsSeries(Low, true);
   ArraySetAsSeries(ATR, true);
   ArraySetAsSeries(Upper, true);
   ArraySetAsSeries(Middle, true);
   ArraySetAsSeries(Lower, true);
   ObjectCreate(0, "High", OBJ_HLINE, 0, 0, 0);
   ObjectCreate(0, "Low", OBJ_HLINE, 0, 0, 0);
   ObjectSetInteger(0, "High", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "Low", OBJPROP_COLOR, clrWhite);
   
   ATRHandler = iATR(_Symbol, PERIOD_D1, atr_len);
   BBHandler = iBands(_Symbol, Timeframe, bb_len, 0, std, PRICE_CLOSE); 
   Stop = StringToTime(TimeToString(TimeCurrent(), TIME_DATE)+" "+Trade_Stop);
   Comment("ID: ", Magic);
   CheckPositions();
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
      CopyBuffer(BBHandler, 2, 0, 3, Lower);
      
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
         
         if(ArraySize(Prices)/SIZE==bb_len && Prices[bb_len-1][0]>Lower_Custom[0] && Prices[bb_len-2][0]<Lower_Custom[1]){
            if(Prices[bb_len-1][0]>Prices[bb_len-1][1] && Prices[bb_len-1][0]<Upper_Custom[0] && (ATR[1]!=0 && ATR[1]<1000)){ //<Middle?Price[2].close<Lowest 
               if(buyPosition==0)
               ExecuteBuy();
            }
         }
         
         if(ArraySize(Prices)/SIZE==bb_len && Prices[bb_len-1][0]<Upper_Custom[0] && Prices[bb_len-2][0]>Upper_Custom[1]){
            if(buyPosition>0)
            ClosePosition(POSITION_TYPE_BUY);
         }
         
//         if(Price[1].close>Lower[1] && Price[2].close<Lower[2]){
//            if(buyPosition==0 && Price[1].close>Price[1].open && Price[1].close<Upper[1] && (ATR[1]!=0 && ATR[1]<1000)){
//               ExecuteBuy();
//            }
//         }     
//         
//         if(Price[1].close<Upper[1] && Price[2].close>Upper[2]){
//            if(buyPosition>0)
//            ClosePosition(POSITION_TYPE_BUY);
//         }
         
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
   if(tppoints==NULL && Mode==0 && TpATR1>0) tppoints = Ask+TpATR1*ATR[1];
   if(slpoints==NULL && SlATR>0) slpoints = Ask-SlATR*ATR[1];
   PositionSize();
   trade.Buy(Lot, _Symbol, Ask, slpoints, tppoints, text);
}

void ExecuteSell(double slpoints=NULL, double tppoints=NULL){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   if(tppoints==NULL && Mode==0 && TpATR2>0) tppoints = Bid-TpATR2*ATR[1];
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
   if(tp==NULL && TpATR1>0 && Mode==0) _tp=entry+TpATR1*ATR[1];
   PositionSize();
   trade.BuyStop(Lot, entry, _Symbol, _sl, _tp, NULL, NULL, text);
   
}

void ExecuteSellStop(double entry, double sl=NULL, double tp=NULL){
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);
   if(Bid<entry) return;
   double _sl = sl;
   double _tp = tp;
   
   if(sl==NULL && SlATR>0) _sl=entry+SlATR*ATR[1];
   if(tp==NULL && TpATR2>0 && Mode==0) _tp=entry-TpATR2*ATR[1];
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
   
   if(ArraySize(ATR)>1) Comment("ID: ", Magic, "\nBuy Duration: ", buyDuration, "\nStop-loss ATR: ", SlATR, "\nATR: ", NormalizeDouble(ATR[1], 3), " \nBB Length: ", bb_len, "\n", Note);
   else Comment("ID: ", Magic, "\nBuy Duration: ", buyDuration, "\nStop-loss ATR: ", SlATR," \nBB Length: ", bb_len, " \n", Note);
}

void TimeExit(){
   if(buyDuration>=TimeExit1 && TimeExit1>=0) ClosePosition(POSITION_TYPE_BUY);
   //if(sellDuration>=TimeExit2 && TimeExit2>=0) ClosePosition(POSITION_TYPE_SELL);
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
               TriggerATR=TpATR1;
            }
            else{
               _profitMargin = PositionGetDouble(POSITION_PRICE_OPEN)-PositionGetDouble(POSITION_PRICE_CURRENT);
               TriggerATR=TpATR2;
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
   
   if(InProfit(POSITION_TYPE_BUY)){
      ClosePosition(POSITION_TYPE_BUY);
   }
   if(InProfit(POSITION_TYPE_SELL)){
      ClosePosition(POSITION_TYPE_SELL);
   }
}

void Range(int bars){
   if(bars<=0) return; 
   
   Highest = iHigh(_Symbol, Timeframe, iHighest(_Symbol, Timeframe, MODE_HIGH, bars, 3));
   Lowest = iLow(_Symbol, Timeframe, iLowest(_Symbol, Timeframe, MODE_LOW, bars, 3));
   
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
   int num_rows = ArraySize(prices)/SIZE;
   ArrayResize(prices,  num_rows+ 1);
   num_rows = ArraySize(prices)/SIZE;
         
   for (int col = 0; col < SIZE; col++){
      prices[num_rows - 1][col] = row[col];
   }
        
   if(num_rows>bb_len){
      double _std;
      double _mean;
      
      for (int i = 0; i < num_rows-1; i++){
         Closes[i] = prices[i][0];
      }
      _std = MathStandardDeviation(Closes);
      _mean = MathMean(Closes);
      Upper_Custom[1] = _mean+std*_std; 
      Lower_Custom[1] = _mean-std*_std; 
      
      for (int i = 0; i < num_rows-1; i++){
         Closes[i] = prices[i+1][0];
      }
      _std = MathStandardDeviation(Closes);
      _mean = MathMean(Closes);
      Upper_Custom[0] = _mean+std*_std; 
      Lower_Custom[0] = _mean-std*_std; 
      
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
    //Print("Lower_Custom[0]", Lower_Custom[0]);
    //Print("Lower_Custom[1]", Lower_Custom[1]);
    //Print("Price[0]", prices[num_rows-1][0]);
    //Print("Price[-1]", Closes[0]);
    //if(num_rows>2){
    //  for (int i = num_rows-2; i < num_rows; i++) {
    //     Print("Prices[", i, "][", 0, "]: ", MathRound(prices[i][0]*100)/100);
    //  }
    //}
}