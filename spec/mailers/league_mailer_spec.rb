require "rails_helper"

RSpec.describe LeagueMailer, type: :mailer do
  let(:user) { create(:user) }
  let(:league) do
    create(
      :league,
      name: "Spring Cup",
      description: "<p>Weekly mock fund challenge.</p>",
      start_date: Time.zone.parse("2026-05-01 09:00"),
      end_date: Time.zone.parse("2026-05-31 17:00"),
      starting_capital: 250_000,
      max_participants: 50,
      handling_fee_proportion: 0.0025,
      minimum_final_balance: 10_000
    )
  end

  describe "#league_opened" do
    let(:mail) { described_class.league_opened(user, league) }

    it "renders headers and league links" do
      expect(mail.subject).to include("Spring Cup")
      expect(mail.subject).to include("now open")
      expect(mail.to).to eq([ user.email ])
      expect(mail.body.encoded).to include("Spring Cup")
      expect(mail.body.encoded).to include("leaderboard")
    end

    it "strips HTML from the description for the plain body" do
      expect(mail.text_part.body.decoded).not_to include("<p>")
      expect(mail.text_part.body.decoded).to include("Weekly mock fund challenge.")
    end
  end

  describe "#league_closed" do
    let!(:portfolio) { create(:portfolio, user: user, league: league, cash_balance: 123_456, total_value: 123_456) }
    let(:mail) { described_class.league_closed(user, league) }

    it "renders closed copy" do
      expect(mail.subject).to include("has closed")
      expect(mail.body.encoded).to include("closed")
    end

    it "includes final balance and attaches a PDF certificate" do
      expect(mail.body.encoded).to include("123,456")
      expect(mail.attachments.map(&:filename)).to include("league-certificate-#{league.id}.pdf")
      expect(mail.attachments.first.mime_type).to start_with("application/pdf")
    end
  end
end
