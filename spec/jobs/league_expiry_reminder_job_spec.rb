require "rails_helper"

RSpec.describe LeagueExpiryReminderJob, type: :job do
  # Job dedupes via Rails.cache.write(..., unless_exist: true); test env uses :null_store by default.
  around do |example|
    previous = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
    Rails.cache = previous
  end

  describe "end-of-league checkpoints" do
    let(:now) { Time.zone.parse("2026-06-15 12:00:00") }

    it "notifies members once in the 1-hour-before window" do
      league = create(:league, start_date: now - 2.weeks, end_date: now + 3590.seconds)
      user = create(:user)
      create(:league_membership, user: user, league: league)

      expect { described_class.perform_now(now: now) }.to change {
        Rails.cache.read("league_expiry_notice/#{league.id}/#{user.id}/#{1.hour.to_i}")
      }.from(nil).to(true)

      expect { described_class.perform_now(now: now) }.not_to(change {
        Rails.cache.read("league_expiry_notice/#{league.id}/#{user.id}/#{1.hour.to_i}")
      })
    end

    it "notifies members in the 15-minute window" do
      league = create(:league, start_date: now - 2.weeks, end_date: now + 890.seconds)
      user = create(:user)
      create(:league_membership, user: user, league: league)

      described_class.perform_now(now: now)
      expect(Rails.cache.read("league_expiry_notice/#{league.id}/#{user.id}/#{15.minutes.to_i}")).to eq(true)
    end
  end

  describe "league started" do
    let(:now) { Time.zone.parse("2026-06-20 09:00:00") }

    it "notifies joined users once when start_date has just passed" do
      league = create(:league, start_date: now - 30.seconds, end_date: now + 2.weeks)
      user = create(:user)
      create(:league_membership, user: user, league: league)

      expect { described_class.perform_now(now: now) }.to change {
        Rails.cache.read("league_started_notice/#{league.id}/#{user.id}")
      }.from(nil).to(true)

      expect { described_class.perform_now(now: now) }.not_to(change {
        Rails.cache.read("league_started_notice/#{league.id}/#{user.id}")
      })
    end

    it "emails each member once when the league opens" do
      league = create(:league, start_date: now - 30.seconds, end_date: now + 2.weeks)
      user = create(:user)
      create(:league_membership, user: user, league: league)

      expect { described_class.perform_now(now: now) }.to change(ActionMailer::Base.deliveries, :size).by(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to include(league.name)

      expect { described_class.perform_now(now: now) }.not_to(change(ActionMailer::Base.deliveries, :size))
    end
  end

  describe "league ended emails" do
    let(:now) { Time.zone.parse("2026-07-01 18:00:00") }

    it "emails each member once after end_date passes" do
      league = create(:league, start_date: now - 2.weeks, end_date: now - 20.seconds)
      user = create(:user)
      membership = create(:league_membership, user: user, league: league)

      expect { described_class.perform_now(now: now) }.to change(ActionMailer::Base.deliveries, :size).by(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([ user.email ])
      expect(mail.subject).to include("has closed")

      expect { described_class.perform_now(now: now) }.not_to(change(ActionMailer::Base.deliveries, :size))

      expect(membership.reload.league_closed_email_sent_at).to be_present
    end
  end

  describe "#due_end_checkpoint (window math)" do
    it "returns the innermost matching checkpoint" do
      job = described_class.new
      expect(job.send(:due_end_checkpoint, 86350)).to eq(1.day.to_i)
      expect(job.send(:due_end_checkpoint, 3590)).to eq(1.hour.to_i)
      expect(job.send(:due_end_checkpoint, 1790)).to eq(30.minutes.to_i)
      expect(job.send(:due_end_checkpoint, 890)).to eq(15.minutes.to_i)
      expect(job.send(:due_end_checkpoint, 2000)).to be_nil
    end
  end
end
