class FriendRequest < ApplicationRecord
  belongs_to :sender, class_name: "User"
  belongs_to :receiver, class_name: "User"

  validates :sender_id, uniqueness: { scope: :receiver_id, message: "already sent a request to this user" }
  validates :status, inclusion: { in: %w[pending accepted declined] }
  validate :not_self_request
  validate :not_already_friends, on: :create

  scope :pending, -> { where(status: "pending") }

  def accept!
    transaction do
      update!(status: "accepted")
      Friendship.create!(user: sender, friend: receiver)
      Friendship.create!(user: receiver, friend: sender)
    end
  end

  def decline!
    update!(status: "declined")
  end

  private

  def not_self_request
    errors.add(:receiver_id, "can't send a friend request to yourself") if sender_id == receiver_id
  end

  def not_already_friends
    if Friendship.exists?(user_id: sender_id, friend_id: receiver_id)
      errors.add(:base, "You are already friends with this user")
    end
  end
end
