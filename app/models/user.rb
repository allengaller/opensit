require 'textacular/searchable'

class User < ActiveRecord::Base
  include Streak

  attr_accessible :city, :country, :website, :default_sit_length, :dob,
                  :password, :email, :first_name, :gender, :last_name,
                  :practice, :style, :user_type, :username,
                  :who, :why, :password_confirmation, :remember_me, :avatar,
                  :privacy_setting, :receive_email, :selected_users

  has_many :sits, :dependent => :destroy
  has_many :messages_received, -> { where receiver_deleted: false }, class_name: 'Message', foreign_key: 'to_user_id'
  has_many :messages_sent, -> { where sender_deleted: false }, class_name: 'Message', foreign_key: 'from_user_id'
  has_many :comments, :dependent => :destroy
  has_many :relationships, foreign_key: "follower_id", dependent: :destroy
  has_many :followed_users, through: :relationships, source: :followed
  has_many :reverse_relationships, foreign_key: "followed_id",
                                   class_name:  "Relationship",
                                   dependent:   :destroy
  has_many :followers, through: :reverse_relationships, source: :follower
  has_many :likes, dependent: :destroy
  has_many :notifications, :dependent => :destroy
  has_many :favourites, dependent: :destroy
  has_many :favourite_sits, through: :favourites,
                            source: :favourable,
                            source_type: "Sit"
  has_many :goals, :dependent => :destroy
  has_many :reports, :dependent => :destroy
  has_many :authorised_users, :dependent => :destroy

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  # Devise :validatable (above) covers validation of email and password
  validates :username, length: { minimum: 3, maximum: 20 }
  validates_uniqueness_of :username
  validates :username, no_empty_spaces: true

  # Textacular: search these columns only
  extend Searchable(:username, :first_name, :last_name, :city, :country)

  # Pagination: sits per page
  self.per_page = 10

  # Paperclip
  has_attached_file :avatar, styles: {
    small_thumb: '50x50#',
    thumb: '250x250#',
  }
  validates_attachment :avatar, content_type: { content_type: ["image/jpg", "image/jpeg", "image/png", "image/gif"] }

  # Scopes
  scope :newest_first, -> { order("created_at DESC") }

  # Privacy
  scope :privacy_selected_users, ->(user) { select('users.id')
      .joins('LEFT JOIN authorised_users ON authorised_users.user_id = users.id')
      .where('(authorised_users.authorised_user_id = ?)', user.id) }
  scope :privacy_following_users, ->(user) { select('users.id')
      .where("users.id IN (?) AND users.privacy_setting = 'following'", user.follower_ids) }

  # Used by url_helper to determine user path, eg; /buddha and /user/buddha
  def to_param
    username
  end

  def city?
    !city.blank?
  end

  def country?
    !country.blank?
  end

  ##
  # VIRTUAL ATTRIBUTES
  ##

  # Location based on whether/if city and country have been entered
  def location
    return "#{city}, #{country}" if city? && country?
    return city if city?
    return country if country?
  end

  def display_name
    return username if first_name.blank?
    return first_name if last_name.blank?
    "#{first_name} #{last_name}"
  end

  def journal(current_user = nil)
    @journal ||= Journal.new(self, current_user)
  end

  def feed
    Sit.where("user_id IN (?)", viewable_and_following_users).with_body.newest_first
  end

  ##
  # PRIVACY
  ##

  def private_journal?
    return true if privacy_setting == 'private'
    return false
  end

  def public_journal?
    return true if privacy_setting == 'public'
    return false
  end

  def privacy_setting=(value)
    if value.in? ['public', 'following', 'selected_users', 'private']
      # If we're moving away from a private journal, need to remove
      # the private marker all sits
      if self.privacy_setting == 'private' && value != 'private'
        sits.unscoped.update_all(private: false)
      # Make my journal private - mark all sits as private
      elsif value == 'private'
        sits.update_all(private: true)
      end
      write_attribute(:privacy_setting, value)
    else
      raise ArgumentError
    end
  end

  def viewable_users
    User.select('users.id').where.any_of(
      User.privacy_selected_users(self),
      User.privacy_following_users(self),
      User.public_users
    )
  end

  def viewable_and_following_users
    # Sneaky & operator returns only IDs that feature in both arrays
    viewable_users & followed_users
  end

  def can_view_content_of(other_user)
    return true if self == other_user
    return true if other_user.privacy_setting == 'following' && other_user.following?(self)
    return true if other_user.privacy_setting == 'selected_users' && AuthorisedUser.where(user_id: other_user.id, authorised_user_id: self.id).present?
    return true if other_user.privacy_setting == 'public'
    return false
  end

  # All users with public journals
  def self.public_users
    select('users.id').where("users.privacy_setting = 'public'")
  end

  # Used to set selected_users on Account Settings form
  def selected_users=(users)
    users.reject! { |c| c.empty? }

    # Clear out old users
    authorised_users.delete_all

    # Add new records
    users.each do |authorised_user|
      AuthorisedUser.create!(user_id: id, authorised_user_id: authorised_user)
    end
  end

  # Used to get selected_users on Account Settings form
  def selected_users
    authorised_users.collect { |u| u.authorised_user_id }
  end

  ##
  # RELATIONSHIPS
  ##

  def following?(other_user)
    relationships.find_by_followed_id(other_user.id) ? true : false
  end

  def follow!(other_user)
    follow = relationships.create!(followed_id: other_user.id)
    Notification.send_new_follower_notification(other_user.id, follow)
  end

  def unfollow!(other_user)
    relationships.find_by_followed_id(other_user.id).destroy
  end

  # Is the user following anyone, besides OpenSit?
  def following_anyone?
    follows = followed_user_ids
    follows.delete(97)
    return false if follows.empty?
    return true
  end

  def users_to_follow
    User.joins(:reverse_relationships)
      .where(relationships: { follower_id: followed_user_ids })
      .where.not(relationships: { followed_id: followed_user_ids })
      .where.not(id: self.id)
      .group("users.id")
      .having("COUNT(followed_id) >= ?", 2)
  end

  # Returns ids of users I follow who also follow me
  def mutual_following_ids
    followed_user_ids & follower_ids
  end

  ##
  # NOTIFICATIONS
  ##

  def unread_count
    messages_received.unread.count unless messages_received.unread.count.zero?
  end

  def new_notifications
    notifications.unread.count unless notifications.unread.count.zero?
  end

  ##
  # LIKES
  ##

  def like!(obj)
    Like.create!(likeable_id: obj.id, likeable_type: obj.class.name, user_id: self.id)
  end

  def likes?(obj)
    Like.where(likeable_id: obj.id, likeable_type: obj.class.name, user_id: self.id).present?
  end

  def unlike!(obj)
    like = Like.where(likeable_id: obj.id, likeable_type: obj.class.name, user_id: self.id).first
    like.destroy
  end

  # Overwrite Devise function to allow profile update with password requirement
  # http://stackoverflow.com/questions/4101220/rails-3-devise-how-to-skip-the-current-password-when-editing-a-registratio?rq=1
  def update_with_password(params={})
    if params[:password].blank?
      params.delete(:password)
      params.delete(:password_confirmation) if params[:password_confirmation].blank?
    end
    update_attributes(params)
  end

  def favourited?(sit_id)
    favourites.where(favourable_type: "Sit", favourable_id: sit_id).exists?
  end

  ##
  # CLASS METHODS
  ##

  def self.newest_users(count = 5)
    self.limit(count).newest_first
  end

  def self.active_users
    User.all.where.not(privacy_setting: 'private').order('sits_count DESC')
  end

  ##
  # CALLBACKS
  ##

  after_create :welcome_email, :follow_opensit

  private

    def welcome_email
      UserMailer.welcome_email(self).deliver_now
    end

    def follow_opensit
      relationships.create!(followed_id: 97)
    end

end