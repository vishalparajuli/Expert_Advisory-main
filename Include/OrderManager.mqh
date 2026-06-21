#pragma once

#include "Logger.mqh"

class COrderManager
{
private:
   int m_maxSlippagePoints;
   int m_maxRetries;
   int m_retryDelayMs;
   ENUM_ORDER_TYPE_FILLING m_fillingMode;

   bool CheckSpread()
   {
      double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      double spreadPips = spread * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
      double maxSpread = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10 * 3.0;
      
      if(spreadPips > 3.0)
      {
         LOG_WARN("OrderManager", "Spread too high: " + DoubleToString(spreadPips, 1) + " pips", _Symbol);
         return false;
      }
      return true;
   }

   bool SelectFillingMode()
   {
      ENUM_ORDER_TYPE_FILLING modes[] = {ORDER_FILLING_FOK, ORDER_FILLING_IOC, ORDER_FILLING_RETURN};
      
      for(int i = 0; i < ArraySize(modes); i++)
      {
         MqlTradeRequest request = {0};
         request.action = TRADE_ACTION_DEAL;
         request.symbol = _Symbol;
         request.type_filling = modes[i];
         
         MqlTradeResult result = {0};
         if(OrderCheck(request, result))
         {
            m_fillingMode = modes[i];
            LOG_INFO("OrderManager", "Filling mode: " + EnumToString(m_fillingMode), _Symbol);
            return true;
         }
      }
      m_fillingMode = ORDER_FILLING_FOK;
      return false;
   }

public:
   COrderManager()
   {
      m_maxSlippagePoints = 30;
      m_maxRetries = 3;
      m_retryDelayMs = 100;
      m_fillingMode = ORDER_FILLING_FOK;
      SelectFillingMode();
   }

   void SetParameters(int maxSlippage, int maxRetries, int retryDelay)
   {
      m_maxSlippagePoints = maxSlippage;
      m_maxRetries = maxRetries;
      m_retryDelayMs = retryDelay;
   }

   bool SendOrder(ENUM_ORDER_TYPE orderType, double volume, double price, double sl, double tp, 
                  string comment, long &ticket, long &latencyMs)
   {
      if(!CheckSpread()) return false;
      
      datetime startTime = GetMicrosecondCount();
      
      for(int attempt = 1; attempt <= m_maxRetries; attempt++)
      {
         MqlTradeRequest request = {0};
         MqlTradeResult result = {0};
         
         request.action = TRADE_ACTION_DEAL;
         request.symbol = _Symbol;
         request.type = orderType;
         request.volume = volume;
         request.price = price;
         request.sl = sl;
         request.tp = tp;
         request.deviation = m_maxSlippagePoints;
         request.type_filling = m_fillingMode;
         request.type_time = ORDER_TIME_GTC;
         request.comment = comment;
         request.magic = 123456;
         
         bool sent = OrderSend(request, result);
         latencyMs = (GetMicrosecondCount() - startTime) / 1000;
         
         if(sent && result.retcode == TRADE_RETCODE_DONE)
         {
            ticket = result.order;
            LOG_TRADE("OrderManager", "Order sent: " + EnumToString(orderType) + " " + DoubleToString(volume, 2) + " lots", 
                      _Symbol, ticket, 0, AccountInfoDouble(ACCOUNT_EQUITY), latencyMs);
            return true;
         }
         
         LOG_WARN("OrderManager", "Attempt " + IntegerToString(attempt) + " failed: " + 
                  EnumToString((ENUM_TRADE_RETCODE)result.retcode) + " (" + IntegerToString(result.retcode) + ")", 
                  _Symbol, result.order);
         
         if(attempt < m_maxRetries) Sleep(m_retryDelayMs);
      }
      
      LOG_ERROR("OrderManager", "All retries exhausted for " + EnumToString(orderType), _Symbol);
      return false;
   }

   bool ClosePosition(long ticket, long &latencyMs)
   {
      datetime startTime = GetMicrosecondCount();
      
      if(!PositionSelectByTicket(ticket)) return false;
      
      ENUM_ORDER_TYPE closeType = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      double volume = PositionGetDouble(POSITION_VOLUME);
      double price = (closeType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      MqlTradeRequest request = {0};
      MqlTradeResult result = {0};
      
      request.action = TRADE_ACTION_DEAL;
      request.symbol = _Symbol;
      request.type = closeType;
      request.volume = volume;
      request.price = price;
      request.position = ticket;
      request.deviation = m_maxSlippagePoints;
      request.type_filling = m_fillingMode;
      request.comment = "Close by EA";
      request.magic = 123456;
      
      bool sent = OrderSend(request, result);
      latencyMs = (GetMicrosecondCount() - startTime) / 1000;
      
      if(sent && result.retcode == TRADE_RETCODE_DONE)
      {
         LOG_TRADE("OrderManager", "Position closed: " + DoubleToString(volume, 2) + " lots", 
                   _Symbol, ticket, PositionGetDouble(POSITION_PROFIT), AccountInfoDouble(ACCOUNT_EQUITY), latencyMs);
         return true;
      }
      
      LOG_ERROR("OrderManager", "Close failed: " + EnumToString((ENUM_TRADE_RETCODE)result.retcode), _Symbol, ticket);
      return false;
   }

   bool ModifyPosition(long ticket, double sl, double tp, long &latencyMs)
   {
      datetime startTime = GetMicrosecondCount();
      
      if(!PositionSelectByTicket(ticket)) return false;
      
      MqlTradeRequest request = {0};
      MqlTradeResult result = {0};
      
      request.action = TRADE_ACTION_SLTP;
      request.symbol = _Symbol;
      request.position = ticket;
      request.sl = sl;
      request.tp = tp;
      
      bool sent = OrderSend(request, result);
      latencyMs = (GetMicrosecondCount() - startTime) / 1000;
      
      if(sent && result.retcode == TRADE_RETCODE_DONE)
      {
         LOG_INFO("OrderManager", "Position modified: SL=" + DoubleToString(sl, _Digits) + " TP=" + DoubleToString(tp, _Digits), _Symbol, ticket);
         return true;
      }
      
      LOG_WARN("OrderManager", "Modify failed: " + EnumToString((ENUM_TRADE_RETCODE)result.retcode), _Symbol, ticket);
      return false;
   }
};
