class User < ApplicationRecord
  SIGNUP_OTP_TTL = 10.minutes
  SIGNUP_OTP_MAX_ATTEMPTS = 5
  SIGNUP_OTP_RESEND_COOLDOWN = 30.seconds
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

  private

  def set_default_role
    self.role ||= "user"
  end

  def password_complexity
    return if password.blank?

    errors.add :password, "must include at least one lowercase letter" unless password.match?(/[a-z]/)
    errors.add :password, "must include at least one uppercase letter" unless password.match?(/[A-Z]/)
    errors.add :password, "must include at least one digit" unless password.match?(/\d/)
    errors.add :password, "must include at least one special character (!@#$%^&*)" unless password.match?(/[!@#$%^&*]/)
  end
end
