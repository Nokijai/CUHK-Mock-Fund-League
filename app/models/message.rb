class Message < ApplicationRecord
  CHANNEL_TYPES = %w[world team individual].freeze

  belongs_to :sender, class_name: "User"
  belongs_to :receiver, class_name: "User", optional: true
  belongs_to :team, optional: true
  belongs_to :league, optional: true

  validates :body, presence: true, length: { maximum: 2000 }
  validates :channel_type, inclusion: { in: CHANNEL_TYPES }

  # Channel-specific validations
  validate :individual_requires_receiver_and_friendship, if: -> { channel_type == "individual" }
  validate :team_channel_requires_team, if: -> { channel_type == "team" }
  validate :team_channel_sender_must_be_member, if: -> { channel_type == "team" }
  validate :team_channel_league_must_be_active, if: -> { channel_type == "team" }

  # Scopes
  scope :world_messages, -> { where(channel_type: "world").order(:created_at) }

  scope :team_messages, ->(team) {
    where(channel_type: "team", team_id: team.id).order(:created_at)
  }

  scope :conversation_between, ->(user_a, user_b) {
    where(channel_type: "individual")
      .where(sender_id: user_a.id, receiver_id: user_b.id)
      .or(where(channel_type: "individual").where(sender_id: user_b.id, receiver_id: user_a.id))
      .order(:created_at)
  }

  # Stream keys for Turbo Streams
  def self.world_stream_key
    "chat_world"
  end

  def self.team_stream_key(team_id)
    "chat_team_#{team_id}"
  end

  def self.chat_stream_key(user_a_id, user_b_id)
    ids = [user_a_id, user_b_id].sort
    "chat_#{ids[0]}_#{ids[1]}"
  end

  private

  def individual_requires_receiver_and_friendship
    if receiver_id.blank?
      errors.add(:receiver, "is required for individual messages")
      return
    end
    return if sender_id == receiver_id
    unless Friendship.exists?(user_id: sender_id, friend_id: receiver_id)
      errors.add(:base, "You can only message friends")
    end
  end

  def team_channel_requires_team
    errors.add(:team, "is required for team messages") if team_id.blank?
  end

  def team_channel_sender_must_be_member
    return if team_id.blank? || sender_id.blank?
    unless TeamMembership.exists?(team_id: team_id, user_id: sender_id)
      errors.add(:base, "You are not a member of this team")
    end
  end

  def team_channel_league_must_be_active
    return if team.blank?
    league = team.league
    return if league.blank?
    if league.end_date.present? && league.end_date < Time.current
      errors.add(:base, "This league has ended. Team chat is closed.")
    end
  end
end
