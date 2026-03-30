# frozen_string_literal: true

module MarketData
  # Top 30 momentum / volume leaders (Nestak watchlist, March 2026).
  # Background jobs refresh these via yfinance; user requests read from DB only.
  module NestakTop30
    SYMBOLS = %w[
      TLYS BW SNDK KOS SOC CURV AMR TPL TER ARM
      NVDA MSFT AMZN GOOGL META TSLA PLTR JAZZ MRNA GLW
      CVX XOM JPM E SCHL WDC FSLR BLBD GRDN GLEN
    ].freeze

    # Optional tickers traded in the app but outside the Nestak 30 (e.g. HK listings).
    REFRESH_EXTRAS = %w[0700].freeze

    # Full set enqueued by periodic refresh tasks (Nestak 30 + extras).
    ALL_REFRESH_SYMBOLS = (SYMBOLS + REFRESH_EXTRAS).freeze

    # Human-readable names for trading UI and dashboard market movers.
    DISPLAY_NAMES = {
      "TLYS" => "Tilly's, Inc.",
      "BW" => "Babcock & Wilcox",
      "SNDK" => "Sandisk Corp",
      "KOS" => "Kosmos Energy",
      "SOC" => "SOC",
      "CURV" => "CURV",
      "AMR" => "Alpha Metallurgical Resources",
      "TPL" => "Texas Pacific Land",
      "TER" => "Teradyne",
      "ARM" => "ARM Holdings",
      "NVDA" => "NVIDIA Corp",
      "MSFT" => "Microsoft Corp",
      "AMZN" => "Amazon",
      "GOOGL" => "Alphabet",
      "META" => "Meta Platforms",
      "TSLA" => "Tesla",
      "PLTR" => "Palantir",
      "JAZZ" => "Jazz Pharmaceuticals",
      "MRNA" => "Moderna",
      "GLW" => "Corning",
      "CVX" => "Chevron",
      "XOM" => "ExxonMobil",
      "JPM" => "JPMorgan Chase",
      "E" => "Eni",
      "SCHL" => "Scholastic",
      "WDC" => "Western Digital",
      "FSLR" => "First Solar",
      "BLBD" => "Blue Bird Corp",
      "GRDN" => "Guardian Pharmacy",
      "GLEN" => "Glencore",
      "0700" => "Tencent Holdings"
    }.freeze
  end
end
