#ifndef SIGNAL_ENGINE_MQH
#define SIGNAL_ENGINE_MQH

#include "Logger.mqh"

struct SignalResult
{
   int signal;
   double sl;
   double tp;
   double atrValue;
   int trend;
};

class CSignalEngine
{
private:
   int m_fastEMA, m_mediumEMA, m_slowEMA;
   int m_trendEMA1, m_trendEMA2;
   int m_rsiPeriod;
   int m_atrPeriod;
   double m_atrMultSL, m_atrMultTP;
   ENUM_TIMEFRAMES m_timeframeSignal, m_timeframeTrend;
   double m_minATRPips;
   
   int m_handleEMAFast, m_handleEMAMed, m_handleEMASlow;
   int m_handleEMATrend1, m_handleEMATrend2;
   int m_handleRSI, m_handleATR;
   
   double m_emaFast[], m_emaMed[], m_emaSlow[];
   double m_emaTrend1[], m_emaTrend2[];
   double m_rsi[], m_atr[];

   bool InitIndicators()
   {
      m_handleEMAFast = iMA(_Symbol, m_timeframeSignal, m_fastEMA, 0, MODE_EMA, PRICE_CLOSE);
      m_handleEMAMed = iMA(_Symbol, m_timeframeSignal, m_mediumEMA, 0, MODE_EMA, PRICE_CLOSE);
      m_handleEMASlow = iMA(_Symbol, m_timeframeSignal, m_slowEMA, 0, MODE_EMA, PRICE_CLOSE);
      
      m_handleEMATrend1 = iMA(_Symbol, m_timeframeTrend, m_trendEMA1, 0, MODE_EMA, PRICE_CLOSE);
      m_handleEMATrend2 = iMA(_Symbol, m_timeframeTrend, m_trendEMA2, 0, MODE_EMA, PRICE_CLOSE);
      
      m_handleRSI = iRSI(_Symbol, m_timeframeSignal, m_rsiPeriod, PRICE_CLOSE);
      m_handleATR = iATR(_Symbol, m_timeframeSignal, m_atrPeriod);
      
      return (m_handleEMAFast != INVALID_HANDLE && m_handleEMAMed != INVALID_HANDLE && 
              m_handleEMASlow != INVALID_HANDLE && m_handleEMATrend1 != INVALID_HANDLE &&
              m_handleEMATrend2 != INVALID_HANDLE && m_handleRSI != INVALID_HANDLE &&
              m_handleATR != INVALID_HANDLE);
   }

   void UpdateBuffers()
   {
      ArraySetAsSeries(m_emaFast, true);
      ArraySetAsSeries(m_emaMed, true);
      ArraySetAsSeries(m_emaSlow, true);
      ArraySetAsSeries(m_emaTrend1, true);
      ArraySetAsSeries(m_emaTrend2, true);
      ArraySetAsSeries(m_rsi, true);
      ArraySetAsSeries(m_atr, true);
      
      CopyBuffer(m_handleEMAFast, 0, 0, 3, m_emaFast);
      CopyBuffer(m_handleEMAMed, 0, 0, 3, m_emaMed);
      CopyBuffer(m_handleEMASlow, 0, 0, 3, m_emaSlow);
      CopyBuffer(m_handleEMATrend1, 0, 0, 3, m_emaTrend1);
      CopyBuffer(m_handleEMATrend2, 0, 0, 3, m_emaTrend2);
      CopyBuffer(m_handleRSI, 0, 0, 3, m_rsi);
      CopyBuffer(m_handleATR, 0, 0, 3, m_atr);
   }

   int GetTrendDirection()
   {
      if(m_emaTrend1[0] > m_emaTrend2[0] && m_emaTrend1[1] > m_emaTrend2[1]) return 1;
      if(m_emaTrend1[0] < m_emaTrend2[0] && m_emaTrend1[1] < m_emaTrend2[1]) return -1;
      return 0;
   }

   int CheckEntrySignal(int trend)
   {
      if(trend == 1)
      {
         if(m_emaFast[1] <= m_emaMed[1] && m_emaFast[0] > m_emaMed[0])
         {
            if(m_rsi[0] < 70 && m_atr[0] > m_minATRPips * _Point * 10)
               return 1;
         }
      }
      else if(trend == -1)
      {
         if(m_emaFast[1] >= m_emaMed[1] && m_emaFast[0] < m_emaMed[0])
         {
            if(m_rsi[0] > 30 && m_atr[0] > m_minATRPips * _Point * 10)
               return -1;
         }
      }
      return 0;
   }

public:
   CSignalEngine()
   {
      m_fastEMA = 9; m_mediumEMA = 21; m_slowEMA = 50;
      m_trendEMA1 = 50; m_trendEMA2 = 200;
      m_rsiPeriod = 14;
      m_atrPeriod = 14;
      m_atrMultSL = 1.0;
      m_atrMultTP = 1.5;
      m_timeframeSignal = PERIOD_M5;
      m_timeframeTrend = PERIOD_M15;
      m_minATRPips = 5.0;
      
      m_handleEMAFast = m_handleEMAMed = m_handleEMASlow = INVALID_HANDLE;
      m_handleEMATrend1 = m_handleEMATrend2 = INVALID_HANDLE;
      m_handleRSI = m_handleATR = INVALID_HANDLE;
      
      ArrayResize(m_emaFast, 3);
      ArrayResize(m_emaMed, 3);
      ArrayResize(m_emaSlow, 3);
      ArrayResize(m_emaTrend1, 3);
      ArrayResize(m_emaTrend2, 3);
      ArrayResize(m_rsi, 3);
      ArrayResize(m_atr, 3);
   }

   ~CSignalEngine()
   {
      IndicatorRelease(m_handleEMAFast);
      IndicatorRelease(m_handleEMAMed);
      IndicatorRelease(m_handleEMASlow);
      IndicatorRelease(m_handleEMATrend1);
      IndicatorRelease(m_handleEMATrend2);
      IndicatorRelease(m_handleRSI);
      IndicatorRelease(m_handleATR);
   }

   bool Initialize()
   {
      return InitIndicators();
   }

   void SetParameters(int fastEMA, int medEMA, int slowEMA, int trendEMA1, int trendEMA2,
                      int rsiPeriod, int atrPeriod, double atrMultSL, double atrMultTP,
                      ENUM_TIMEFRAMES tfSignal, ENUM_TIMEFRAMES tfTrend, double minATRPips)
   {
      m_fastEMA = fastEMA; m_mediumEMA = medEMA; m_slowEMA = slowEMA;
      m_trendEMA1 = trendEMA1; m_trendEMA2 = trendEMA2;
      m_rsiPeriod = rsiPeriod; m_atrPeriod = atrPeriod;
      m_atrMultSL = atrMultSL; m_atrMultTP = atrMultTP;
      m_timeframeSignal = tfSignal; m_timeframeTrend = tfTrend;
      m_minATRPips = minATRPips;
      
      IndicatorRelease(m_handleEMAFast); IndicatorRelease(m_handleEMAMed); IndicatorRelease(m_handleEMASlow);
      IndicatorRelease(m_handleEMATrend1); IndicatorRelease(m_handleEMATrend2);
      IndicatorRelease(m_handleRSI); IndicatorRelease(m_handleATR);
      
      InitIndicators();
   }

   SignalResult GetSignal()
   {
      SignalResult result = {0, 0, 0, 0, 0};
      
      UpdateBuffers();
      
      if(m_emaFast[0] == 0 || m_emaTrend1[0] == 0 || m_atr[0] == 0) return result;
      
      result.trend = GetTrendDirection();
      result.atrValue = m_atr[0];
      result.signal = CheckEntrySignal(result.trend);
      
      if(result.signal != 0)
      {
         double point = _Point;
         double atrPips = result.atrValue / point / 10;
         
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         
         if(result.signal == 1)
         {
            result.sl = ask - m_atrMultSL * result.atrValue;
            result.tp = ask + m_atrMultTP * result.atrValue;
         }
         else
         {
            result.sl = bid + m_atrMultSL * result.atrValue;
            result.tp = bid - m_atrMultTP * result.atrValue;
         }
         
         LOG_INFO("SignalEngine", "Signal: " + IntegerToString(result.signal) + " Trend: " + IntegerToString(result.trend) + 
                  " ATR: " + DoubleToString(atrPips, 1) + "p RSI: " + DoubleToString(m_rsi[0], 1), _Symbol);
      }
      
      return result;
   }

   bool CheckExitSignal(long ticket, double currentPrice)
   {
      if(!PositionSelectByTicket(ticket)) return false;
      
      int type = (int)PositionGetInteger(POSITION_TYPE);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      
      if(type == POSITION_TYPE_BUY)
      {
         if(currentPrice <= sl || currentPrice >= tp) return true;
      }
      else
      {
         if(currentPrice >= sl || currentPrice <= tp) return true;
      }
      return false;
   }
};

#endif // SIGNAL_ENGINE_MQH