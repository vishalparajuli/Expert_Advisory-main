# ScalpingEA - MQL5 High-Frequency Scalping Expert Advisor

## Overview
A modular, production-ready scalping EA for MetaTrader 5 designed for Deriv broker (Forex Majors & Synthetic Indices).

## Features
- **Modular Architecture**: Separate classes for Risk, Orders, Signals, Sessions, Logging
- **Risk Management**: 1-2% equity risk, daily loss limit, max drawdown protection
- **Smart Execution**: Slippage control, retry logic, auto filling mode detection
- **Session Filtering**: London/NY overlap focus, news avoidance
- **Comprehensive Logging**: CSV trade logs for analysis
- **VPS-Ready**: Configurable latency-sensitive parameters

## Strategy
**Trend-following scalping on M5 with M15 trend filter:**
- Trend: EMA 50 vs EMA 200 on M15
- Entry: EMA 9 crosses EMA 21 on M5 in trend direction
- Filter: RSI(14) not extreme + ATR > minimum threshold
- Exit: ATR-based SL/TP (1.0x / 1.5x ATR) + time exit

## Files Structure
```
Expert Advisory/
├── ScalpingEA.mq5              # Main EA (compile this)
├── Include/
│   ├── Logger.mqh              # Trade/             # CSV logging
│   ├── RiskManager.mqh         # Position sizing & protection
│   ├── OrderManager.mqh        # Order execution
│   ├── SessionFilter.mqh       # Time & news filters
│   └── SignalEngine.mqh        # Trading signals
├── Config/
│   ├── ScalpingEA_Deriv_Majors.set      # Forex majors config
│   └── ScalpingEA_Deriv_Synthetic.set   # Synthetic indices config
└── Test/
    └── backtest_results.md     # Document results here
```

## Installation
1. Copy `ScalpingEA.mq5` to `MQL5/Experts/`
2. Copy `Include/` folder to `MQL5/Include/ScalpingEA/`
3. Open in MetaEditor, compile (F7)
4. Load `.set` file in Strategy Tester or live chart

## Configuration

### For Deriv Forex Majors (EURUSD, GBPUSD, USDJPY, AUDUSD, USDCHF)
- Load `Config/ScalpingEA_Deriv_Majors.set`
- Trade sessions: London/NY overlap (13-17 UTC)
- Timeframe: M5
- Min account: $100 (micro lots 0.01)

### For Deriv Synthetic Indices (Volatility 25/50/75/100)
- Load `Config/ScalpingEA_Deriv_Synthetic.set`
- Trade 24/7 (no session filter)
- Timeframe: M5
- Better for small accounts - tighter spreads, 24/7

## Key Parameters

| Parameter | Majors | Synthetic | Description |
|-----------|--------|-----------|-------------|
| Risk % | 1.5% | 2.0% | Equity risk per trade |
| Max Daily Loss | 5% | 5% | Stop trading for day |
| Max Drawdown | 15% | 15% | Reduce size/pause |
| Max Trades | 3 | 2 | Concurrent positions |
| ATR SL Mult | 1.0x | 1.2x | Stop loss multiplier |
| ATR TP Mult | 1.5x | 1.8x | Take profit multiplier |
| Min ATR Pips | 5 | 8 | Volatility filter |
| Session Filter | Yes | No | Time restrictions |
| News Filter | Yes | No | Avoid high impact |

## Testing Workflow
1. **Strategy Tester**: 2023-2024 data, M5, every tick
2. **Optimize**: Walk-forward, separate train/test periods
3. **Demo**: 2-4 weeks on Deriv demo
4. **Micro Live**: $50-100 real for 2-4 weeks
5. **VPS**: Migrate if profitable

## VPS Migration
- Update `InpMaxSlippagePoints` to 10-20
- Reduce `InpMaxRetries` to 1-2
- Enable `InpEnableLogging` for latency monitoring
- Recommended: NY4/LD4/TY3 VPS near Deriv servers

## Risk Warnings
- **Not true HFT** - home PC latency limits frequency
- **Deriv spreads** vary - test thoroughly on demo first
- **Synthetic indices** have different behavior than forex
- **Small accounts** ($100-200) have limited margin buffer
- **No martingale/grid/averaging** - pure risk-defined scalping

## Logging
Logs saved to `MQL5/Files/Logs/ScalpingEA_YYYY-MM-DD-HH-MM-SS.csv`
Columns: Time, Level, Module, Message, Symbol, Ticket, PnL, Equity, LatencyMs

## License
MIT - Use at your own risk. Test thoroughly before live trading.