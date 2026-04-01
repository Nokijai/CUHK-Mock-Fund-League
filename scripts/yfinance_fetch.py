#!/usr/bin/env python3

"""
Fetch OHLCV candles and latest price using yfinance.

This script is intentionally used by a background job so the web request path
never calls external APIs.

Install dependency (one-time):
  pip3 install yfinance pandas
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone

import yfinance as yf


PERIOD_BY_INTERVAL = {
  # Keep these modest so jobs are fast; we only need enough recent bars for UI.
  # 15m: yfinance allows intraday history up to ~60d for this interval.
  "15m": "60d",
  "1h": "30d",
  "4h": "90d",
  "1d": "2y",
}


def _to_iso_utc(dt) -> str:
  if dt.tzinfo is None:
    dt = dt.replace(tzinfo=timezone.utc)
  return dt.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def fetch(symbol: str, intervals: list[str]) -> dict:
  ticker = yf.Ticker(symbol)
  candles = {}
  latest_close = None

  for interval in intervals:
    period = PERIOD_BY_INTERVAL.get(interval, "30d")
    df = ticker.history(period=period, interval=interval)
    rows = []
    if df is not None and len(df.index) > 0:
      # df.index can be tz-aware depending on interval and exchange.
      for idx, r in df.iterrows():
        ts = idx.to_pydatetime()
        rows.append(
          {
            "t": _to_iso_utc(ts),
            "o": None if r.get("Open") is None else float(r["Open"]),
            "h": None if r.get("High") is None else float(r["High"]),
            "l": None if r.get("Low") is None else float(r["Low"]),
            "c": None if r.get("Close") is None else float(r["Close"]),
            "v": None if r.get("Volume") is None else float(r["Volume"]),
          }
        )
      # Use the most recent close we have as "latest price".
      if rows:
        latest_close = rows[-1]["c"]
    candles[interval] = rows

  return {
    "symbol": symbol.upper(),
    "fetched_at": _to_iso_utc(datetime.now(tz=timezone.utc)),
    "price": latest_close,
    "candles": candles,
  }


def main() -> int:
  parser = argparse.ArgumentParser()
  parser.add_argument("--symbol", required=True)
  parser.add_argument("--intervals", default="15m,1h,4h,1d")
  args = parser.parse_args()

  intervals = [x.strip() for x in args.intervals.split(",") if x.strip()]
  payload = fetch(args.symbol, intervals)
  print(json.dumps(payload))
  return 0


if __name__ == "__main__":
  raise SystemExit(main())

