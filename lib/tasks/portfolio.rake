namespace :portfolio do
  desc "Update portfolio valuations"
  task update_valuations: :environment do
    Portfolio.find_each do |portfolio|
      PortfolioValuationJob.perform_later(portfolio.id)
    end
  end
end
