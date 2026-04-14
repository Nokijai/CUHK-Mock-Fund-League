require "rails_helper"

RSpec.describe Message, type: :model do
  describe "stream keys" do
    it "builds stable chat stream keys" do
      team = double(id: 42)

      expect(described_class.world_stream_key).to eq("chat_world")
      expect(described_class.team_stream_key(team.id)).to eq("chat_team_42")
      expect(described_class.chat_stream_key(9, 3)).to eq("chat_3_9")
    end
  end

  describe "individual messages" do
    it "requires the receiver to be a friend" do
      sender = create(:user, username: "sender_one")
      receiver = create(:user, username: "receiver_one")

      message = described_class.new(
        sender:,
        receiver:,
        body: "Hello",
        channel_type: "individual"
      )

      expect(message).not_to be_valid
      expect(message.errors[:base]).to include("You can only message friends")
    end

    it "allows messages between friends" do
      sender = create(:user, username: "sender_two")
      receiver = create(:user, username: "receiver_two")
      Friendship.create!(user: sender, friend: receiver)

      message = described_class.new(
        sender:,
        receiver:,
        body: "Hello",
        channel_type: "individual"
      )

      expect(message).to be_valid
    end
  end

  describe "team messages" do
    it "requires an active team membership" do
      league = create(:league, start_date: 2.days.ago, end_date: 2.days.from_now, team_mode: true)
      team = Team.create!(league:, name: "Chat Team", password: "Secret123!", password_confirmation: "Secret123!")
      sender = create(:user, username: "team_member")
      receiver = create(:user, username: "team_receiver")

      message = described_class.new(
        sender:,
        receiver:,
        team:,
        league:,
        body: "Team hello",
        channel_type: "team"
      )

      expect(message).not_to be_valid
      expect(message.errors[:base]).to include("You are not a member of this team")

      TeamMembership.create!(team:, user: sender, league:)
      message.team = team

      expect(message).to be_valid
    end

    it "rejects team messages for leagues that have ended" do
      league = create(:league, start_date: 2.weeks.ago, end_date: 1.day.ago, team_mode: true)
      team = Team.create!(league:, name: "Closed Team", password: "Secret123!", password_confirmation: "Secret123!")
      sender = create(:user, username: "late_member")
      TeamMembership.create!(team:, user: sender, league:)

      message = described_class.new(
        sender:,
        team:,
        league:,
        body: "Too late",
        channel_type: "team"
      )

      expect(message).not_to be_valid
      expect(message.errors[:base]).to include("This league has ended. Team chat is closed.")
    end
  end

  describe "scopes" do
    it "orders world messages by creation time" do
      sender = create(:user, username: "world_sender")
      first = described_class.create!(sender:, body: "first", channel_type: "world")
      second = described_class.create!(sender:, body: "second", channel_type: "world")
      first.update_column(:created_at, 2.minutes.ago)
      second.update_column(:created_at, 1.minute.ago)

      expect(described_class.world_messages).to eq([ first, second ])
    end

    it "returns both directions in a conversation" do
      sender = create(:user, username: "conversation_sender")
      receiver = create(:user, username: "conversation_receiver")
      Friendship.create!(user: sender, friend: receiver)
      Friendship.create!(user: receiver, friend: sender)

      first = described_class.create!(sender:, receiver:, body: "one", channel_type: "individual")
      second = described_class.create!(sender: receiver, receiver: sender, body: "two", channel_type: "individual")
      first.update_column(:created_at, 2.minutes.ago)
      second.update_column(:created_at, 1.minute.ago)

      expect(described_class.conversation_between(sender, receiver)).to eq([ first, second ])
    end
  end
end
