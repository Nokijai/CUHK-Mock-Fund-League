class League < ApplicationRecord
  include Searchable

  # Rule keys live only in DB column `leagues.rules` (jsonb). There are no separate columns.
  # Virtual accessors below read/write these keys; `save` persists the whole `rules` hash.
  MAX_PARTICIPANTS_RULE_KEY = "max_participants".freeze
  HANDLING_FEE_RULE_KEY = "handling_fee_proportion".freeze
  MINIMUM_FINAL_BALANCE_RULE_KEY = "minimum_final_balance".freeze
  TEAM_MODE_RULE_KEY = "team_mode".freeze
  TEAM_MAX_PARTICIPANTS_RULE_KEY = "team_max_participants".freeze
  TEAM_MIN_PARTICIPANTS_RULE_KEY = "team_min_participants".freeze

  has_many :league_memberships, dependent: :destroy
  has_many :users, through: :league_memberships
  has_many :portfolios, dependent: :destroy
  has_many :teams, dependent: :destroy
  # League "leader" is the creator (used for team moderation privileges).
  belongs_to :creator, class_name: "User", optional: true
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
  validate :team_rule_values_must_be_valid
  # Once persisted, economic/rule fields are frozen (fairness); only set on create.
  validate :rules_immutable_after_create, on: :update
  validate :starting_capital_immutable_after_create, on: :update

  # Virtual accessors backed by `rules` JSON (same storage as API `league.rules` and leagues#index per-card RULES block).
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

  # Team-mode leagues require users to join a team (with password) and be eligible by team size.
  def team_mode?
    ActiveModel::Type::Boolean.new.cast(rules_hash[TEAM_MODE_RULE_KEY])
  end

  def team_mode=(value)
    base = rules.is_a?(Hash) ? rules.deep_dup : {}
    base[TEAM_MODE_RULE_KEY] = ActiveModel::Type::Boolean.new.cast(value)
    self.rules = base
  end

  def team_max_participants
    raw = rules_hash[TEAM_MAX_PARTICIPANTS_RULE_KEY]
    raw.present? ? raw.to_i : nil
  end

  def team_max_participants=(value)
    write_rule_value(TEAM_MAX_PARTICIPANTS_RULE_KEY, value, integer: true)
  end

  def team_min_participants
    raw = rules_hash[TEAM_MIN_PARTICIPANTS_RULE_KEY]
    raw.present? ? raw.to_i : nil
  end

  def team_min_participants=(value)
    write_rule_value(TEAM_MIN_PARTICIPANTS_RULE_KEY, value, integer: true)
  end

  def team_eligible?(team)
    # Minimum requirement defaults to 1 when team-mode is enabled (so a solo team can still play unless admin raises it).
    min = team_min_participants.presence || 1
    team.team_memberships_count.to_i >= min.to_i
  end

  # True when admins stored a handling fee in rules (including 0%); used so UI can show "0%" vs omitting the line.
  def handling_fee_rule_configured?
    rules.is_a?(Hash) && rules.key?(HANDLING_FEE_RULE_KEY)
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

  # Assign full hash so ActiveRecord marks `rules` dirty (in-place jsonb mutation does not).
  def write_rule_value(key, raw_value, integer: false, decimal: false)
    base = rules.is_a?(Hash) ? rules.deep_dup : {}
    sanitized = raw_value.to_s.strip
    if sanitized.blank?
      base.delete(key)
      self.rules = base
      return
    end

    base[key] =
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
    self.rules = base
  end

  def rules_immutable_after_create
    # Prefer Rails dirty-tracking that works consistently for jsonb assignments.
    return unless will_save_change_to_rules?

    errors.add(:rules, "cannot be changed after the league is created")
  end

  # Portfolios are seeded from starting_capital; changing it post-create would desync balances.
  def starting_capital_immutable_after_create
    return unless will_save_change_to_starting_capital?

    errors.add(:starting_capital, "cannot be changed after the league is created")
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

  def team_rule_values_must_be_valid
    return unless team_mode?

    max_raw = rules_hash[TEAM_MAX_PARTICIPANTS_RULE_KEY]
    min_raw = rules_hash[TEAM_MIN_PARTICIPANTS_RULE_KEY]

    if max_raw.present? && !max_raw.to_s.match?(/\A[1-9]\d*\z/)
      errors.add(:team_max_participants, "must be a positive whole number")
    end

    if min_raw.present? && !min_raw.to_s.match?(/\A[1-9]\d*\z/)
      errors.add(:team_min_participants, "must be a positive whole number")
    end

    if max_raw.present? && min_raw.present? && min_raw.to_i > max_raw.to_i
      errors.add(:team_min_participants, "must be less than or equal to team max participants")
    end
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
