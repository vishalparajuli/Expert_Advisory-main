#property copyright "Vishal Parajuly"
#property link "https://github.com/vishalparajuli/Expert_Advisory-main"
#property version "1.00"

#include "Include\Logger.mqh"
#include "Include\RiskManager.mqh"
#include "Include\OrderManager.mqh"
#include "Include\SessionFilter.mqh"
#include "Include\SignalEngine.mqh"

#define SIGNAL_NONE 0
#define SIGNAL_BUY 1
#define SIGNAL_SELL -1

input group "=== Risk Management ==="
input double InpRiskPercent = 1.5;
input double InpMaxDailyLossPct = 5.0;
input double InpMaxDrawdownPct = 15.0;
input int InpMaxConcurrentTrades = 3;

input group "=== Signal Parameters ==="
input int InpFastEMA = 9;
input int InpMediumEMA = 21;
input int InpSlowEMA = 50;
input int InpTrendEMA1 = 50;
input int InpTrendEMA2 = 200;
input int InpRSIPeriod = 14;
input int InpATRPeriod = 14;
input double InpATRMultSL = 1.0;
input double InpATRMultTP = 1.5;
input ENUM_TIMEFRAMES InpSignalTF = PERIOD_M5;
input ENUM_TIMEFRAMES InpTrendTF = PERIOD_M15;
input double InpMinATRPips = 5.0;

input group "=== Execution Parameters ==="
input int InpMaxSlippagePoints = 30;
input int InpMaxRetries = 3;
input int InpRetryDelayMs = 100;

input group "=== Session Filter ==="
input bool InpUseSessionFilter = true;
input int InpLondonStart = 8;
input int InpLondonEnd = 17;
input int InpNYStart = 13;
input int InpNYEnd = 22;
input int InpTokyoStart = 0;
input int InpTokyoEnd = 9;
input bool InpAvoidNews = true;
input int InpNewsBufferMin = 30;

input group "=== General ==="
input bool InpEnableLogging = true;
input int InpMagicNumber = 123456;
input string InpComment = "ScalpingEA";

CRiskManager g_riskManager;
COrderManager g_orderManager;
CSessionFilter g_sessionFilter;
CSignalEngine g_signalEngine;

datetime g_lastBarTime = 0;
bool g_initialized = false;

int OnInit()
{
   LOG_INFO("OnInit", "Starting ScalpingEA v1.00", _Symbol);
   
   g_logger.Enable(InpEnableLogging);
   
   g_riskManager.SetParameters(InpRiskPercent, InpMaxDailyLossPct, InpMaxDrawdownPct, InpMaxConcurrentTrades);
   
   g_orderManager.SetParameters(InpMaxSlippagePoints, InpMaxRetries, InpRetryDelayMs);
   
   g_sessionFilter.SetParameters(InpUseSessionFilter, InpLondonStart, InpLondonEnd, 
                                  InpNYStart, InpNYEnd, InpTokyoStart, InpTokyoEnd,
                                  InpAvoidNews, InpNewsBufferMin);
   
   g_signalEngine.SetParameters(InpFastEMA, InpMediumEMA, InpSlowEMA, InpTrendEMA1, InpTrendEMA2,
                                 InpRSIPeriod, InpATRPeriod, InpATRMultSL, InpATRMultTP,
                                 InpSignalTF, InpTrendTF, InpMinATRPips);
   
   if(!g_signalEngine.Initialize())
   {
      LOG_ERROR("OnInit", "Failed to initialize indicators", _Symbol);
      return INIT_FAILED;
   }
   
   g_riskManager.ResetDaily();
   g_initialized = true;
   
   LOG_INFO("OnInit", "EA initialized successfully", _Symbol);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   LOG_INFO("OnDeinit", "EA stopped: " + IntegerToString(reason), _Symbol);
   g_initialized = false;
}

void OnTick()
{
   if(!g_initialized) return;
   
   datetime currentBar = iTime(_Symbol, InpSignalTF, 0);
   if(currentBar == g_lastBarTime) return;
   g_lastBarTime = currentBar;
   
   g_riskManager.OnTick();
   
   ManageOpenPositions();
   
   if(!g_sessionFilter.IsTradeAllowed(_Symbol)) return;
   
   string reason;
   if(!g_riskManager.CanTrade(reason))
   {
      LOG_WARN("OnTick", "Cannot trade: " + reason, _Symbol);
      return;
   }
   
   CheckNewSignal();
}

void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                           SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      if(g_signalEngine.CheckExitSignal(ticket, currentPrice))
      {
         long latency;
         if(g_orderManager.ClosePosition(ticket, latency))
         {
            double pnl = PositionGetDouble(POSITION_PROFIT);
            g_riskManager.OnTradeClosed(pnl);
            LOG_TRADE("ManagePositions", "Position closed by SL/TP", _Symbol, ticket, pnl, AccountInfoDouble(ACCOUNT_EQUITY), latency);
         }
      }
   }
}

void CheckNewSignal()
{
   SignalResult signal = g_signalEngine.GetSignal();
   
   if(signal.signal == SIGNAL_NONE) return;
   
   double volume = g_riskManager.GetLotSize(
      MathAbs(signal.signal == SIGNAL_BUY ? 
             (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - signal.sl) : 
             (signal.sl - SymbolInfoDouble(_Symbol, SYMBOL_BID))) / _Point / 10
   );
   
   if(volume <= 0)
   {
      LOG_ERROR("CheckNewSignal", "Invalid lot size calculated", _Symbol);
      return;
   }
   
   double price = (signal.signal == SIGNAL_BUY) ? 
                  SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   ENUM_ORDER_TYPE orderType = (signal.signal == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   
   long ticket = 0;
   long latency = 0;
   
   if(g_orderManager.SendOrder(orderType, volume, price, signal.sl, signal.tp, InpComment, ticket, latency))
   {
      LOG_TRADE("CheckNewSignal", "New position opened: " + EnumToString(orderType) + " " + DoubleToString(volume, 2) + " lots", 
                _Symbol, ticket, 0, AccountInfoDouble(ACCOUNT_EQUITY), latency);
   }
}

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(request.magic != InpMagicNumber) return;
   
   if(trans.type == TRADE_TRANSACTION_ORDER_ADD || trans.type == TRADE_TRANSACTION_ORDER_UPDATE)
   {
      LOG_DEBUG("OnTradeTransaction", "Order: " + EnumToString((ENUM_TRADE_TRANSACTION_TYPE)trans.type), _Symbol);
   }
}

void OnTimer()
{
}
