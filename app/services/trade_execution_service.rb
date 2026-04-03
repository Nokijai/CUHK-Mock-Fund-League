require "ostruct"

class TradeExecutionService
  attr_reader :trade, :errors

  def execute(params)
    @trade = Trade.new(params)
    saved = @trade.save
    # Surface model validation errors to API callers on failed creates.
    @errors = saved ? [] : @trade.errors.full_messages

    OpenStruct.new(success?: saved, trade: @trade, errors: @errors)
  end
end
