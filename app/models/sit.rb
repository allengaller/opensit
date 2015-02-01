require 'textacular/searchable'

class Sit < ActiveRecord::Base
  attr_accessible :private, :disable_comments, :tag_list, :duration, :s_type,
                  :body, :title, :created_at, :user_id, :views

  belongs_to :user, counter_cache: true
  has_many :comments, :dependent => :destroy
  has_many :taggings
  has_many :tags, through: :taggings
  has_many :favourites, :as => :favourable
  has_many :likes, :as => :likeable
  has_many :reports, :as => :reportable

  validates :s_type, :presence => true
  validates :title, :presence => true, :if => "s_type != 0"
  validates :duration, :presence => true, :if => "s_type == 0"
  validates_numericality_of :duration, greater_than: 0, only_integer: true

  # Scopes
  default_scope -> { where.not(private: true) }
  scope :newest_first, -> { order("created_at DESC") }
  scope :today, -> { where("DATE(created_at) = ?", Date.today) }
  scope :yesterday, -> { where("DATE(created_at) = ?", Date.yesterday) }
  scope :with_body, -> { where.not(body: '') }
  scope :content_i_can_view, ->(user) { where('user_id IN (?)', user.viewable_users) }
  scope :public_sits, -> { where('user_id IN (?)', User.public_users) }

  # Pagination: sits per page
  self.per_page = 20

  # Textacular: search these columns only
  extend Searchable(:title, :body)

  ##
  # VIRTUAL ATTRIBUTES
  ##

  # Nice date: 11 July 2012
  def date
    created_at.strftime("%d %B %Y")
  end

  # For use on show sit pages
  def full_title
    if s_type == 0
      "#{self.duration} minute meditation journal"
    elsif s_type == 1
      self.title # Diary
    else
      "Article: #{self.title}" # Article
    end
  end

  ##
  # METHODS
  ##

  def is_sit?
    s_type == 0
  end

  def stub?
    body.empty?
  end

  # Remove <br>'s and &nbsp's
  def custom_strip
    no_brs = self.body.gsub(/<br>/, ' ')
    no_brs.gsub('&nbsp;', ' ')
  end

  def mine?(current)
    return true if self.user_id == current.id
  end

  def next(current_user)
    if current_user && (self.user_id == current_user.id)
      Sit.unscoped do
        return user.sits.with_body.where("created_at > ?", self.created_at).order('created_at ASC').first
      end
    else
      return user.sits.with_body.where("created_at > ?", self.created_at).order('created_at ASC').first
    end
  end

  def prev(current_user)
    if current_user && (self.user_id == current_user.id)
      Sit.unscoped do
        return user.sits.with_body.where("created_at < ?", self.created_at).order('created_at ASC').last
      end
    else
      return user.sits.with_body.where("created_at < ?", self.created_at).order('created_at ASC').last
    end
  end

  def self.explore(user)
    return content_i_can_view(user) if user
    return public_sits
  end

  ##
  # COMMENTS
  ##

  def commenters
    ids = self.comments.map {|c| c.user.id}.uniq # uniq removes dupe ids if someone's posted multiple times
    ids.delete(self.user.id) # remove owners id
    return ids
  end

  ##
  # TAGS
  ##

  def self.tagged_with(name)
    Tag.find_by_name!(name).sits
  end

  def self.tag_counts
    Tag.select("tags.*, count(taggings.tag_id) as count").
      joins(:taggings).group("taggings.tag_id, tags.id, tags.name, tags.created_at")
  end

  def tag_list
    tags.map(&:name).join(', ')
  end

  def tag_list=(names)
    elements = names.split(",")
    elements.reject! { |c| c.blank? } # Prevent blank tags being added
    self.tags = elements.map do |t|
      Tag.where(name: t.strip).first_or_create!
    end
  end

  ##
  # LIKES
  ##

  def likers
    Like.likers_for(self)
  end

  def liked?
    !self.likes.empty?
  end

  ##
  # PRIVACY
  ##

  def viewable?(current_user)
    # User can always view their own content, regardless of settings
    return true if current_user && mine?(current_user)

    # Private sit - everyone buzz off
    return false if private

    # Check account wide privacy settings
    if user.private_journal?
      return false

    # Only display to my followers
    elsif user.privacy_setting == 'following'
      return true if current_user && (user.followed_user_ids.include? current_user.id)
      return false

    # Only display to selected users
    elsif user.privacy_setting == 'selected_users'
      return true if current_user && AuthorisedUser.where(user_id: self.user.id, authorised_user_id: current_user.id).present?
      return false

    # Public
    elsif user.privacy_setting == 'public'
      return true
    end
  end
end