class TradeExecutionService
  attr_reader :trade, :errors

  def execute(params)
    @errors = []
    @trade = Trade.new(params)
    OpenStruct.new(success?: @trade.save, trade: @trade, errors: @errors)
  end
end
