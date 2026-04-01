class User < ApplicationRecord
  include Searchable
  
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :league_memberships, dependent: :destroy
  has_many :leagues, through: :league_memberships
  has_many :portfolios, dependent: :destroy

  ROLES = %w[user admin].freeze

  validates :role, inclusion: { in: ROLES, message: "%{value} is not a valid role" }
  validate :password_complexity

  after_initialize :set_default_role, if: :new_record?

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
