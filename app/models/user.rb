class User < ApplicationRecord
  SIGNUP_OTP_TTL = 10.minutes
  SIGNUP_OTP_MAX_ATTEMPTS = 5
  # Minimum wait between signup OTP resends; RegistrationsController uses this for session-based cooldown math.
  SIGNUP_OTP_RESEND_COOLDOWN = 60.seconds
  LOGIN_OTP_TTL = 10.minutes
  LOGIN_OTP_MAX_ATTEMPTS = 5
  # Cooldown before the user can request another login OTP email (aligned with signup OTP resend).
  LOGIN_OTP_RESEND_COOLDOWN = 60.seconds
  ROLES = %w[user admin].freeze

  # Experience level system
  LEVELS = [
    { name: "Beginner", threshold: 0, icon: "🌱" },
    { name: "Elite", threshold: 100, icon: "⚡" },
    { name: "Master", threshold: 500, icon: "🏅" },
    { name: "Professional", threshold: 1000, icon: "💎" },
    { name: "God", threshold: 5000, icon: "👑" }
  ].freeze

  include Searchable

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         # Social login providers are configured in `config/initializers/devise.rb`.
         :omniauthable, omniauth_providers: %i[google_oauth2 github]

  has_many :league_memberships, dependent: :destroy
  has_many :leagues, through: :league_memberships
  has_many :portfolios, dependent: :destroy
  has_many :team_memberships, dependent: :destroy
  has_many :teams, through: :team_memberships
  has_many :user_identities, dependent: :destroy

  # Friendships
  has_many :friendships, dependent: :destroy
  has_many :friends, through: :friendships, source: :friend

  # Friend requests
  has_many :sent_friend_requests, class_name: "FriendRequest", foreign_key: :sender_id, dependent: :destroy
  has_many :received_friend_requests, class_name: "FriendRequest", foreign_key: :receiver_id, dependent: :destroy
  has_many :pending_received_friend_requests, -> { pending }, class_name: "FriendRequest", foreign_key: :receiver_id

  # Messages
  has_many :sent_messages, class_name: "Message", foreign_key: :sender_id, dependent: :destroy
  has_many :received_messages, class_name: "Message", foreign_key: :receiver_id, dependent: :destroy

  def friends_with?(other_user)
    friends.exists?(other_user.id)
  end

  # ── Level system ──

  def current_level
    xp = experience_points.to_i
    LEVELS.reverse.find { |l| xp >= l[:threshold] } || LEVELS.first
  end

  def level_name
    current_level[:name]
  end

  def level_icon
    current_level[:icon]
  end

  def level_index
    LEVELS.index(current_level)
  end

  def next_level
    idx = level_index
    idx < LEVELS.size - 1 ? LEVELS[idx + 1] : nil
  end

  def xp_progress_to_next
    nxt = next_level
    return { current: experience_points, needed: 0, percent: 100 } unless nxt

    prev_threshold = current_level[:threshold]
    range = nxt[:threshold] - prev_threshold
    progress = experience_points.to_i - prev_threshold
    percent = range.positive? ? (progress.to_f / range * 100).clamp(0, 100).round(1) : 100

    { current: experience_points.to_i, needed: nxt[:threshold], percent: percent }
  end

  def award_experience!(points)
    return if points.zero?

    new_xp = experience_points.to_i + points

    if points.negative?
      apply_xp_loss!(new_xp)
    else
      # Gaining XP clears protection since user is performing well
      update!(experience_points: new_xp, level_protected: false)
    end
  end

  def level_protected?
    level_protected
  end

  def apply_xp_loss!(new_xp)
    current_threshold = current_level[:threshold]

    if new_xp < current_threshold
      if level_protected?
        # Already protected once — apply full loss now (demotion)
        update!(experience_points: [new_xp, 0].max, level_protected: false)
      else
        # First time hitting the floor — clamp at threshold, activate shield
        update!(experience_points: current_threshold, level_protected: true)
      end
    else
      # Loss doesn't cross level boundary, apply normally
      update!(experience_points: new_xp)
    end
  end

  # Username validations
  validates :username, presence: true, uniqueness: { case_sensitive: false }
  validates :username, format: { without: /\s/, message: "cannot contain spaces" }
  validates :role, inclusion: { in: ROLES, message: "%{value} is not a valid role" }
  validate :password_complexity

  after_initialize :set_default_role, if: :new_record?

  # Class method to find user by username or email for authentication
  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    if (login = conditions.delete(:email))
      where(conditions).find_by([ "lower(username) = :value OR lower(email) = :value", { value: login.downcase } ])
    elsif conditions.has_key?(:username) || conditions.has_key?(:email)
      where(conditions).first
    end
  end

  # Build or locate a user for OAuth sign-in.
  #
  # Design constraints:
  # - Our app requires a unique `username`; OAuth users may not have one yet.
  # - OAuth identities should link to the same account when the email matches.
  # - OAuth sign-ins should not be forced through email OTP flows (skip login OTP).
  def self.from_omniauth(auth)
    provider = auth.provider.to_s
    uid = auth.uid.to_s
    email = auth.dig(:info, :email).to_s.downcase.presence
    name = auth.dig(:info, :name).to_s.presence || auth.dig(:info, :nickname).to_s.presence

    # Preferred: identity lookup by provider+uid.
    identity = UserIdentity.find_by(provider:, uid:)
    user = identity&.user

    # Otherwise: link to an existing user by email (the user's requirement).
    user ||= find_by(email:) if email.present?

    new_user = user.nil?
    user ||= new(email: email || "oauth-#{provider}-#{uid}@example.invalid")

    # Attach/refresh identity record.
    identity ||= user.user_identities.build(provider:, uid:)
    identity.email = email if email.present?
    identity.name = name if name.present?

    # Ensure required fields are present; OAuth users don't need to know a password.
    # But our app enforces password complexity, so generate one that always passes.
    user.password ||= oauth_compliant_password
    user.username ||= generate_available_username(name: name, email: email, fallback: "#{provider}_#{uid}")

    # Treat OAuth as verified/trusted for onboarding (avoid signup OTP + login OTP friction).
    user.signup_verified_at ||= Time.current
    user.skip_login_otp = true
    # New OAuth users must pick a username; redirect flow handles this.
    user.username_finalized = false if new_user && user.respond_to?(:username_finalized)

    user.save!
    user
  end

  def admin?
    role == "admin"
  end

  def user?
    role == "user"
  end

  def generate_login_otp!
    code = format("%06d", SecureRandom.random_number(1_000_000))

    update!(
      login_otp_digest: digest_login_otp(code),
      login_otp_sent_at: Time.current,
      login_otp_attempts: 0,
      login_otp_locked_until: nil
    )

    code
  end

  def verify_login_otp!(code)
    return false if code.blank? || login_otp_digest.blank?
    return false if login_otp_locked?
    return false if login_otp_expired?

    if ActiveSupport::SecurityUtils.secure_compare(digest_login_otp(code), login_otp_digest)
      clear_login_otp!
      true
    else
      consume_failed_login_otp_attempt!
      false
    end
  end

  def login_otp_expired?
    login_otp_sent_at.blank? || login_otp_sent_at < LOGIN_OTP_TTL.ago
  end

  def login_otp_locked?
    login_otp_locked_until.present? && login_otp_locked_until.future?
  end

  # Seconds until another login OTP may be requested (0 = allowed now).
  def login_otp_resend_wait_seconds
    return 0 if login_otp_resend_available?

    [ (login_otp_sent_at + LOGIN_OTP_RESEND_COOLDOWN - Time.current).ceil, 0 ].max
  end

  def clear_login_otp!
    update_columns(
      login_otp_digest: nil,
      login_otp_sent_at: nil,
      login_otp_attempts: 0,
      login_otp_locked_until: nil
    )
  end

  # Signup OTP (account activation) — persisted so admins can see pending signups.
  def signup_pending?
    signup_verified_at.blank?
  end

  def approve_signup!
    update_columns(
      signup_verified_at: Time.current,
      # Admin approval treats the user as trusted: skip login OTP for future sign-ins.
      skip_login_otp: true,
      signup_otp_digest: nil,
      signup_otp_sent_at: nil,
      signup_otp_attempts: 0,
      signup_otp_locked_until: nil
    )
  end

  def generate_signup_otp!
    code = format("%06d", SecureRandom.random_number(1_000_000))

    update!(
      signup_otp_digest: digest_signup_otp(code),
      signup_otp_sent_at: Time.current,
      signup_otp_attempts: 0,
      signup_otp_locked_until: nil
    )

    code
  end

  def verify_signup_otp!(code)
    return false if code.blank? || signup_otp_digest.blank?
    return false if signup_otp_locked?
    return false if signup_otp_expired?

    if ActiveSupport::SecurityUtils.secure_compare(digest_signup_otp(code), signup_otp_digest)
      approve_signup!
      true
    else
      consume_failed_signup_otp_attempt!
      false
    end
  end

  def signup_otp_expired?
    signup_otp_sent_at.blank? || signup_otp_sent_at < SIGNUP_OTP_TTL.ago
  end

  def signup_otp_locked?
    signup_otp_locked_until.present? && signup_otp_locked_until.future?
  end

  def signup_otp_resend_wait_seconds
    return 0 if signup_otp_resend_available?
    [ (signup_otp_sent_at + SIGNUP_OTP_RESEND_COOLDOWN - Time.current).ceil, 0 ].max
  end

  private

  # Devise tokens don't guarantee our local complexity constraints (e.g. special chars).
  # Keep this deterministic so OAuth sign-in never fails on validation.
  def self.oauth_compliant_password
    # Ensure: lowercase, uppercase, digit, special, plus random tail.
    "Aa1!#{SecureRandom.hex(16)}"
  end

  # Produce a username candidate that satisfies:
  # - no spaces (our validation)
  # - uniqueness
  def self.generate_available_username(name:, email:, fallback:)
    base =
      if name.present?
        name.downcase.gsub(/[^a-z0-9_]/, "_").gsub(/_+/, "_").gsub(/\A_+|_+\z/, "")
      elsif email.present?
        email.split("@").first.to_s.downcase.gsub(/[^a-z0-9_]/, "_").gsub(/_+/, "_").gsub(/\A_+|_+\z/, "")
      else
        fallback.to_s.downcase.gsub(/[^a-z0-9_]/, "_")
      end

    base = fallback.to_s.downcase.gsub(/[^a-z0-9_]/, "_") if base.blank?
    base = base.first(24)

    # If taken, append _2, _3, ... (bounded to keep loops safe).
    return base unless exists?(username: base)

    2.upto(200) do |n|
      candidate = "#{base}_#{n}"
      return candidate unless exists?(username: candidate)
    end

    # Extremely unlikely; fall back to a random suffix.
    "#{base}_#{SecureRandom.hex(3)}"
  end

  def set_default_role
    self.role ||= "user"
  end

  def digest_login_otp(code)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "#{id}:#{code}")
  end

  def digest_signup_otp(code)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "#{id}:#{code}")
  end

  def consume_failed_signup_otp_attempt!
    attempts = signup_otp_attempts.to_i + 1
    if attempts >= SIGNUP_OTP_MAX_ATTEMPTS
      update_columns(signup_otp_attempts: attempts, signup_otp_locked_until: 15.minutes.from_now)
    else
      update_columns(signup_otp_attempts: attempts)
    end
  end

  def signup_otp_resend_available?
    signup_otp_sent_at.blank? || signup_otp_sent_at <= SIGNUP_OTP_RESEND_COOLDOWN.ago
  end

  def consume_failed_login_otp_attempt!
    attempts = login_otp_attempts.to_i + 1

    if attempts >= LOGIN_OTP_MAX_ATTEMPTS
      update_columns(login_otp_attempts: attempts, login_otp_locked_until: 15.minutes.from_now)
    else
      update_columns(login_otp_attempts: attempts)
    end
  end

  def login_otp_resend_available?
    login_otp_sent_at.blank? || login_otp_sent_at <= LOGIN_OTP_RESEND_COOLDOWN.ago
  end

  def password_complexity
    return if password.blank?

    errors.add :password, "must include at least one lowercase letter" unless password.match?(/[a-z]/)
    errors.add :password, "must include at least one uppercase letter" unless password.match?(/[A-Z]/)
    errors.add :password, "must include at least one digit" unless password.match?(/\d/)
    errors.add :password, "must include at least one special character (!@#$%^&*)" unless password.match?(/[!@#$%^&*]/)
  end
end
