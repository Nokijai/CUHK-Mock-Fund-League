class League < ApplicationRecord
  include Searchable

  MAX_PARTICIPANTS_RULE_KEY = "max_participants".freeze
  HANDLING_FEE_RULE_KEY = "handling_fee_proportion".freeze
  MINIMUM_FINAL_BALANCE_RULE_KEY = "minimum_final_balance".freeze

  has_many :league_memberships, dependent: :destroy
  has_many :users, through: :league_memberships
  has_many :portfolios, dependent: :destroy
  # Real-time fan-out: every newly created league pushes a UI notification to all subscribers.
  after_create_commit :broadcast_created_notification

  # Keep league names unique and enforce valid competition windows/capital.
  validates :name, presence: true, uniqueness: { case_sensitive: true, message: "already exists" }
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :starting_capital, presence: true, numericality: { greater_than: 0 }
  # Admin may open/backfill leagues at any time; only enforce start/end ordering.
  validate :end_date_after_start_date
  validate :max_participants_rule_must_be_positive_integer
  validate :handling_fee_rule_must_be_valid_proportion
  validate :minimum_final_balance_rule_must_be_non_negative

  # Virtual accessors backed by rules JSON so admin form can bind clean fields.
  def max_participants
    raw = rules_hash[MAX_PARTICIPANTS_RULE_KEY]
    raw.present? ? raw.to_i : nil
  end

  def max_participants=(value)
    write_rule_value(MAX_PARTICIPANTS_RULE_KEY, value, integer: true)
  end

  def handling_fee_proportion
    raw = rules_hash[HANDLING_FEE_RULE_KEY]
    raw.present? ? raw.to_d : 0.to_d
  end

  def handling_fee_proportion=(value)
    write_rule_value(HANDLING_FEE_RULE_KEY, value, decimal: true)
  end

  def minimum_final_balance
    raw = rules_hash[MINIMUM_FINAL_BALANCE_RULE_KEY]
    raw.present? ? raw.to_d : nil
  end

  def minimum_final_balance=(value)
    write_rule_value(MINIMUM_FINAL_BALANCE_RULE_KEY, value, decimal: true)
  end

  # Capacity guard used by both web and API join endpoints.
  def full_for_new_members?
    return false if max_participants.blank?

    league_memberships.count >= max_participants
  end

  # Joining is allowed only while the league window is active.
  def join_open_now?(at: Time.current)
    return false if start_date.blank? || end_date.blank?

    at >= start_date && at <= end_date
  end

  # Provides consistent reason messaging for web/API join rejections.
  def join_block_reason(at: Time.current)
    return :not_opened if start_date.present? && at < start_date
    return :expired if end_date.present? && at > end_date

    nil
  end

  private

  def rules_hash
    self.rules = {} unless rules.is_a?(Hash)
    rules
  end

  def write_rule_value(key, raw_value, integer: false, decimal: false)
    sanitized = raw_value.to_s.strip
    if sanitized.blank?
      rules_hash.delete(key)
      return
    end

    rules_hash[key] =
      if integer
        sanitized.match?(/\A[1-9]\d*\z/) ? sanitized.to_i : sanitized
      elsif decimal
        begin
          BigDecimal(sanitized).to_s("F")
        rescue ArgumentError
          sanitized
        end
      else
        sanitized
      end
  end

  def end_date_after_start_date
    if start_date.present? && end_date.present? && end_date <= start_date
      errors.add(:end_date, "must be after start date")
    end
  end

  def max_participants_rule_must_be_positive_integer
    raw = rules_hash[MAX_PARTICIPANTS_RULE_KEY]
    return if raw.blank?

    unless raw.to_s.match?(/\A[1-9]\d*\z/)
      errors.add(:max_participants, "must be a positive whole number")
    end
  end

  def handling_fee_rule_must_be_valid_proportion
    raw = rules_hash[HANDLING_FEE_RULE_KEY]
    return if raw.blank?

    fee = BigDecimal(raw.to_s)
    if fee.negative? || fee > 1
      errors.add(:handling_fee_proportion, "must be between 0 and 1")
    end
  rescue ArgumentError
    errors.add(:handling_fee_proportion, "must be a number")
  end

  def minimum_final_balance_rule_must_be_non_negative
    raw = rules_hash[MINIMUM_FINAL_BALANCE_RULE_KEY]
    return if raw.blank?

    minimum = BigDecimal(raw.to_s)
    errors.add(:minimum_final_balance, "must be greater than or equal to 0") if minimum.negative?
  rescue ArgumentError
    errors.add(:minimum_final_balance, "must be a number")
  end

  def broadcast_created_notification
    # Broadcast into a shared stream that logged-in clients subscribe to from the layout.
    broadcast_prepend_to(
      "league_notifications",
      target: "realtime-notifications",
      partial: "leagues/realtime_notification",
      locals: {
        title: "New league created",
        body: name,
        league: self
      }
    )
  end
end
