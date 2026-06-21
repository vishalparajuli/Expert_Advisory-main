#ifndef SESSION_FILTER_MQH
#define SESSION_FILTER_MQH

#include "Logger.mqh"

class CSessionFilter
{
private:
   bool m_useSessionFilter;
   int m_londonStartHour, m_londonEndHour;
   int m_nyStartHour, m_nyEndHour;
   int m_tokyoStartHour, m_tokyoEndHour;
   bool m_avoidNews;
   int m_newsBufferMinutes;
   
   struct NewsEvent
   {
      datetime time;
      string currency;
      string impact;
      string name;
   };
   
   NewsEvent m_newsEvents[];

   int GetHour(datetime dt)
   {
      MqlDateTime dtm;
      TimeToStruct(dt, dtm);
      return dtm.hour;
   }

   int GetDayOfWeek(datetime dt)
   {
      MqlDateTime dtm;
      TimeToStruct(dt, dtm);
      return dtm.day_of_week;
   }

   bool IsNewsTime(datetime checkTime, string symbol)
   {
      if(!m_avoidNews) return false;
      
      string baseCurr = StringSubstr(symbol, 0, 3);
      string quoteCurr = StringSubstr(symbol, 3, 3);
      
      for(int i = 0; i < ArraySize(m_newsEvents); i++)
      {
         if(m_newsEvents[i].currency == baseCurr || m_newsEvents[i].currency == quoteCurr)
         {
            double diff = MathAbs((double)(checkTime - m_newsEvents[i].time)) / 60.0;
            if(diff <= m_newsBufferMinutes)
            {
               return true;
            }
         }
      }
      return false;
   }

   void LoadNewsCalendar()
   {
      ArrayResize(m_newsEvents, 0);
   }

public:
   CSessionFilter()
   {
      m_useSessionFilter = true;
      m_londonStartHour = 8; m_londonEndHour = 17;
      m_nyStartHour = 13; m_nyEndHour = 22;
      m_tokyoStartHour = 0; m_tokyoEndHour = 9;
      m_avoidNews = true;
      m_newsBufferMinutes = 30;
      LoadNewsCalendar();
   }

   void SetParameters(bool useFilter, int lonStart, int lonEnd, int nyStart, int nyEnd, 
                      int tkStart, int tkEnd, bool avoidNews, int newsBuffer)
   {
      m_useSessionFilter = useFilter;
      m_londonStartHour = lonStart; m_londonEndHour = lonEnd;
      m_nyStartHour = nyStart; m_nyEndHour = nyEnd;
      m_tokyoStartHour = tkStart; m_tokyoEndHour = tkEnd;
      m_avoidNews = avoidNews;
      m_newsBufferMinutes = newsBuffer;
   }

   bool IsTradeAllowed(string symbol = "")
   {
      if(!m_useSessionFilter) return true;
      
      datetime now = TimeCurrent();
      int hour = GetHour(now);
      int dayOfWeek = GetDayOfWeek(now);
      
      if(dayOfWeek == 0 || dayOfWeek == 6) return false;
      
      bool inSession = false;
      
      if(hour >= m_londonStartHour && hour < m_londonEndHour) inSession = true;
      if(hour >= m_nyStartHour && hour < m_nyEndHour) inSession = true;
      if(hour >= m_tokyoStartHour && hour < m_tokyoEndHour) inSession = true;
      
      if(!inSession)
      {
         LOG_DEBUG("SessionFilter", "Outside trading sessions: " + IntegerToString(hour) + ":00 UTC", symbol);
         return false;
      }
      
      if(m_avoidNews && symbol != "")
      {
         if(IsNewsTime(now, symbol))
         {
            LOG_WARN("SessionFilter", "News blackout period", symbol);
            return false;
         }
      }
      
      return true;
   }

   bool IsOverlapSession()
   {
      datetime now = TimeCurrent();
      int hour = GetHour(now);
      return (hour >= 13 && hour < 17);
   }

   string GetCurrentSession()
   {
      datetime now = TimeCurrent();
      int hour = GetHour(now);
      
      if(hour >= 13 && hour < 17) return "London/NY Overlap";
      if(hour >= 8 && hour < 17) return "London";
      if(hour >= 13 && hour < 22) return "New York";
      if(hour >= 0 && hour < 9) return "Tokyo";
      return "Closed";
   }
};

#endif
