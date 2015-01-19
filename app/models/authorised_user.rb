class AuthorisedUser < ActiveRecord::Base
  attr_accessible :user_id, :authorised_user_id
  validates_presence_of :user_id, :authorised_user_id
end