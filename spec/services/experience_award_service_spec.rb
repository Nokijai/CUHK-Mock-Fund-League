require "rails_helper"

RSpec.describe ExperienceAwardService do
  describe "#award!" do
    it "awards individual league participants using the leaderboard results" do
      league = create(:league, handling_fee_proportion: 0.1)
      user = create(:user, experience_points: 0)

      leaderboard = instance_double(LeaderboardService, compute: [ { user_id: user.id, rank: 1, total_return_pct: 12.4 } ])
      allow(LeaderboardService).to receive(:new).with(league).and_return(leaderboard)

      described_class.new(league).award!

      expect(user.reload.experience_points).to eq(54)
    end

    it "expands team rankings to each user in the winning team" do
      league = create(:league, team_mode: true, handling_fee_proportion: 0)
      team = Team.create!(league:, name: "Winners", password: "Secret123!", password_confirmation: "Secret123!")
      first_user = create(:user, experience_points: 0)
      second_user = create(:user, experience_points: 0)
      TeamMembership.create!(team:, user: first_user, league:)
      TeamMembership.create!(team:, user: second_user, league:)

      leaderboard = instance_double(TeamLeaderboardService, compute: [ { team_id: team.id, rank: 2, avg_return_pct: 7.8 } ])
      allow(TeamLeaderboardService).to receive(:new).with(league).and_return(leaderboard)

      described_class.new(league).award!

      expect(first_user.reload.experience_points).to eq(28)
      expect(second_user.reload.experience_points).to eq(28)
    end

    it "skips empty rankings without raising" do
      league = create(:league)
      leaderboard = instance_double(LeaderboardService, compute: [])
      allow(LeaderboardService).to receive(:new).with(league).and_return(leaderboard)

      expect { described_class.new(league).award! }.not_to raise_error
    end
  end
end
