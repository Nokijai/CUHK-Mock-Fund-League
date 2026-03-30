class LeaderboardsController < ApplicationController
  before_action :set_league

  def show
    @leagues = League.order(:name)
    @rankings = stub_rankings
    @current_user_id = stub_current_user_id
    @update_interval_minutes = @league.rules&.dig("leaderboard_update_minutes") || 15
    @last_updated_at = Time.current
    @prizes = stub_prizes
    @end_timestamp = (@league.end_date&.to_time || 30.days.from_now).to_i * 1000
  end

  private

  def set_league
    @league = League.find(params[:league_id])
  end

  def stub_current_user_id
    7
  end

  def stub_prizes
    [
      { rank: "1st Place", prize: "HK$ 10,000 + Trophy" },
      { rank: "2nd Place", prize: "HK$ 5,000" },
      { rank: "3rd Place", prize: "HK$ 2,500" },
      { rank: "Top 10", prize: "Certificate of Achievement" }
    ]
  end

  def stub_rankings
    names = [
      "Alice Chen", "Bob Wang", "Carol Liu", "David Zhang", "Eve Lin",
      "Frank Huang", "Grace Wu", "Henry Cheng", "Ivy Tsai", "Jack Yang",
      "Karen Ho", "Leo Chou", "Mia Sun", "Nathan Lai", "Olivia Hsu"
    ]

    names.each_with_index.map do |name, i|
      starting = @league.starting_capital.to_f.nonzero? || 100_000.0
      value = starting * (1 + (0.25 - i * 0.035) + rand(-0.005..0.005))
      return_pct = ((value - starting) / starting * 100.0).round(2)
      daily_chg = (rand(-3.0..4.0)).round(2)
      drawdown = -(rand(1.0..18.0)).round(2)
      win_rate = (40 + rand(0..35)).round(1)
      trades = rand(8..120)

      trend = 30.times.map { |j| (starting * (0.92 + (j / 30.0) * 0.15 + rand(-0.02..0.02))).round(0) }
      trend[-1] = value.round(0)

      {
        user_id: i + 1,
        rank: i + 1,
        name: name,
        portfolio_value: value.round(2),
        total_return_pct: return_pct,
        daily_change_pct: daily_chg,
        max_drawdown_pct: drawdown,
        win_rate: win_rate,
        trade_count: trades,
        trend: trend,
        starting_balance: starting,
        current_cash: (value * rand(0.1..0.4)).round(2),
        current_equity: (value * rand(0.6..0.9)).round(2),
        highest_rank: [1, i + 1 - rand(0..3)].max
      }
    end
  end
end
