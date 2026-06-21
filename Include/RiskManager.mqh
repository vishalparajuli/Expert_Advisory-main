#ifndef RISK_MANAGER_MQH
#define RISK_MANAGER_MQH

#include "Logger.mqh"

class CRiskManager
{
private:
   double m_riskPercent;
   double m_maxDailyLossPercent;
   double m_maxDrawdownPercent;
   int m_maxConcurrentTrades;
   double m_dailyStartEquity;
   double m_peakEquity;
   datetime m_dailyResetTime;
   int m_tradesToday;
   double m_pnlToday;
   
   double CalculateLotSize(const double slPoints, const double equity)
   {
      if(slPoints <= 0) return 0.01;
      
      double riskAmount = equity * (m_riskPercent / 100.0);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      if(tickValue <= 0 || pointValue <= 0) return 0.01;
      
      double slPrice = slPoints * pointValue;
      double lotSize = riskAmount / (slPrice * tickValue / pointValue);
      
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      
      lotSize = NormalizeDouble(MathMax(minLot, MathMin(maxLot, lotSize)), 2);
      lotSize = MathFloor(lotSize / stepLot) * stepLot;
      
      return MathMax(minLot, lotSize);
   }

public:
   CRiskManager()
   {
      m_riskPercent = 1.5;
      m_maxDailyLossPercent = 5.0;
      m_maxDrawdownPercent = 15.0;
      m_maxConcurrentTrades = 3;
      ResetDaily();
   }

   void SetParameters(double riskPct, double maxDailyLossPct, double maxDDPct, int maxTrades)
   {
      m_riskPercent = riskPct;
      m_maxDailyLossPercent = maxDailyLossPct;
      m_maxDrawdownPercent = maxDDPct;
      m_maxConcurrentTrades = maxTrades;
   }

   void ResetDaily()
   {
      m_dailyStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      m_peakEquity = m_dailyStartEquity;
      m_dailyResetTime = TimeCurrent();
      m_tradesToday = 0;
      m_pnlToday = 0;
   }

   void OnTick()
   {
      MqlDateTime dtNow, dtReset;
      TimeToStruct(TimeCurrent(), dtNow);
      TimeToStruct(m_dailyResetTime, dtReset);
      if(dtNow.day != dtReset.day || dtNow.mon != dtReset.mon || dtNow.year != dtReset.year)
      {
         ResetDaily();
      }
      
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(equity > m_peakEquity) m_peakEquity = equity;
      
      m_pnlToday = equity - m_dailyStartEquity;
   }

   double GetLotSize(double slPoints)
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      return CalculateLotSize(slPoints, equity);
   }

   bool CanTrade(string &reason)
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      
      if(m_tradesToday >= 50)
      {
         reason = "Max trades per day reached";
         return false;
      }
      
      if(m_pnlToday <= -m_dailyStartEquity * (m_maxDailyLossPercent / 100.0))
      {
         reason = "Daily loss limit reached";
         return false;
      }
      
      double dd = (m_peakEquity - equity) / m_peakEquity * 100.0;
      if(dd >= m_maxDrawdownPercent)
      {
         reason = "Max drawdown reached: " + DoubleToString(dd, 1) + "%";
         return false;
      }
      
      int openPositions = 0;
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong posTicket = PositionGetTicket(i);
         if(posTicket > 0 && PositionSelectByTicket(posTicket) && PositionGetString(POSITION_SYMBOL) == _Symbol)
            openPositions++;
      }
      
      if(openPositions >= m_maxConcurrentTrades)
      {
         reason = "Max concurrent trades reached";
         return false;
      }
      
      if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) < 5.0)
      {
         reason = "Insufficient free margin";
         return false;
      }
      
      return true;
   }

   void OnTradeClosed(double pnl)
   {
      m_tradesToday++;
      m_pnlToday += pnl;
   }

   double GetDailyPnL() { return m_pnlToday; }
   int GetTradesToday() { return m_tradesToday; }
   double GetDrawdownPercent() 
   { 
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      return (m_peakEquity - equity) / m_peakEquity * 100.0; 
   }
};

#endif // RISK_MANAGER_MQH