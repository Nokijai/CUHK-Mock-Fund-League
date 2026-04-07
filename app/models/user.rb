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

  include Searchable

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :league_memberships, dependent: :destroy
  has_many :leagues, through: :league_memberships
  has_many :portfolios, dependent: :destroy

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

  private

  def set_default_role
    self.role ||= "user"
  end

  def digest_login_otp(code)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "#{id}:#{code}")
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
