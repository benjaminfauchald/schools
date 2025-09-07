class AdminUser < ApplicationRecord
  # Include default devise modules
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  validates :email, presence: true, uniqueness: true
end
