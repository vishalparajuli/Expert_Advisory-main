#ifndef LOGGER_MQH
#define LOGGER_MQH

#include <File.mqh>

class CLogger
{
private:
   string m_logFile;
   int m_fileHandle;
   bool m_enabled;
   datetime m_sessionStart;

public:
   CLogger(const string prefix = "ScalpingEA")
   {
      m_enabled = true;
      m_sessionStart = TimeCurrent();
      string dateStr = TimeToString(m_sessionStart, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
      StringReplace(dateStr, ".", "-");
      StringReplace(dateStr, ":", "-");
      m_logFile = "Logs\\" + prefix + "_" + dateStr + ".csv";
      
      if(!FileIsExist(m_logFile, FILE_COMMON))
      {
         m_fileHandle = FileOpen(m_logFile, FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
         if(m_fileHandle != INVALID_HANDLE)
         {
            FileWrite(m_fileHandle, "Time", "Level", "Module", "Message", "Symbol", "Ticket", "PnL", "Equity", "LatencyMs");
            FileClose(m_fileHandle);
         }
      }
   }

   ~CLogger()
   {
   }

   void Enable(bool state) { m_enabled = state; }

   void Log(const string level, const string module, const string message, 
            const string symbol = "", const long ticket = 0, const double pnl = 0, 
            const double equity = 0, const long latencyMs = 0)
   {
      if(!m_enabled) return;
      
      m_fileHandle = FileOpen(m_logFile, FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON | FILE_READ, ',');
      if(m_fileHandle == INVALID_HANDLE) return;
      
      FileSeek(m_fileHandle, 0, SEEK_END);
      FileWrite(m_fileHandle, TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS | TIME_MILLISECONDS),
                level, module, message, symbol, ticket, DoubleToString(pnl, 2), DoubleToString(equity, 2), latencyMs);
      FileClose(m_fileHandle);
   }

   void Info(const string module, const string message, const string symbol = "", const long ticket = 0) 
   { Log("INFO", module, message, symbol, ticket); }
   
   void Warn(const string module, const string message, const string symbol = "", const long ticket = 0) 
   { Log("WARN", module, message, symbol, ticket); }
   
   void Error(const string module, const string message, const string symbol = "", const long ticket = 0) 
   { Log("ERROR", module, message, symbol, ticket); }
   
   void Trade(const string module, const string message, const string symbol = "", const long ticket = 0, 
              const double pnl = 0, const double equity = 0, const long latencyMs = 0)
   { Log("TRADE", module, message, symbol, ticket, pnl, equity, latencyMs); }

   void Debug(const string module, const string message, const string symbol = "") 
   { Log("DEBUG", module, message, symbol); }
};

CLogger g_logger("ScalpingEA");

#define LOG_INFO(module, msg, symbol) g_logger.Info(module, msg, symbol)
#define LOG_WARN(module, msg, symbol) g_logger.Warn(module, msg, symbol)
#define LOG_ERROR(module, msg, symbol) g_logger.Error(module, msg, symbol)
#define LOG_TRADE(module, msg, symbol, ticket, pnl, equity, latency) g_logger.Trade(module, msg, symbol, ticket, pnl, equity, latency)
#define LOG_DEBUG(module, msg, symbol) g_logger.Debug(module, msg, symbol)

#endif // LOGGER_MQH