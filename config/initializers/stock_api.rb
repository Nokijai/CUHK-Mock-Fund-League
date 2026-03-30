# Stock API configuration
Rails.application.config.x.stock_api.provider = ENV.fetch("STOCK_API_PROVIDER", "yahoo_finance")
Rails.application.config.x.stock_api.yahoo_base_url = ENV.fetch(
	"YAHOO_FINANCE_BASE_URL",
	"https://query1.finance.yahoo.com"
)
