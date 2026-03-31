module TradesHelper
  STOCK_NAMES = {
    "AAPL" => "Apple Inc",
    "MSFT" => "Microsoft Corp",
    "GOOGL" => "Alphabet Inc",
    "NVDA" => "NVIDIA Corp",
    "0700" => "Tencent Holdings",
    "META" => "Meta Platforms"
  }.freeze

  def stock_name_for(symbol)
    STOCK_NAMES[symbol.to_s] || symbol.to_s
  end
end
