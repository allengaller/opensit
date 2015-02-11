class UsersController < ApplicationController
  before_filter :authenticate_user!, only: [:welcome, :me, :export]
  before_filter :check_date, only: :show

  # GET /welcome
  def welcome
    @user = current_user

    # Prevent /welcome being revisited as GA records each /welcome as a new sign up
    if @user.sign_in_count > 1 || (Time.now - @user.created_at > 10)
      redirect_to me_path
      return false
    end

    @users_to_follow = User.active_users.limit(3)
  end

  # GET /me page
  def me
    @feed_items = current_user.feed.paginate(:page => params[:page])
    @user = current_user
    @journal = @user.journal(current_user)
    @latest = @journal.latest_sit
    @goals = @user.goals

    @goals.each do |g|
      if g.completed?
        @has_completed = true
      else
        @has_current = true
      end
    end

    @title = 'Home'
    @page_class = 'me'
  end

  # GET /u/buddha
  def show
    @user = User.where("lower(username) = lower(?)", params[:username]).first!

    # If viewable (by this registered user), or public journal
    if (current_user && current_user.can_view_content_of(@user)) || @user.privacy_setting == 'public'
      @month = params[:month] ? params[:month] : Date.today.month
      @year = params[:year] ? params[:year] : Date.today.year
      @journal = Journal.new(@user, current_user)

      # Viewing your own profile
      if current_user == @user
        Sit.unscoped do
          @sits = @journal.sits_by_month(@month, @year).newest_first
        end
        # @stats = @journal.get_monthly_stats(month, year)

      # Viewing someone elses profile
      else
        if !@user.private_journal?
          @sits = @journal.sits_by_month(@month, @year).newest_first
          # @stats = @user.get_monthly_stats(month, year)
        end
      end
    else
      @unviewable = true
    end

    @title = "#{@user.display_name}\'s meditation practice journal"
    @desc = "#{@user.display_name} has logged #{@user.sits_count} meditation reports on OpenSit, a free community for meditators."
    @page_class = 'view-user'
  end

  # GET /u/buddha/following
  def following
    @user = User.where("lower(username) = lower(?)", params[:username]).first!
    @users = @user.followed_users
    @latest = @user.latest_sit(current_user)

    if @user == current_user
      @title = "People I follow"
    else
      @title = "People who #{@user.display_name} follows"
    end

    @page_class = 'following'
    render 'show_follow'
  end

  # GET /u/buddha/followers
  def followers
    @user = User.where("lower(username) = lower(?)", params[:username]).first!
    @users = @user.followers
    @latest = @user.latest_sit(current_user)

    if @user == current_user
      @title = "People who follow me"
    else
      @title = "People who follow #{@user.display_name}"
    end

    @page_class = 'followers'
    render 'show_follow'
  end

  # GET /u/buddha/export
  def export
    @user = User.where("lower(username) = lower(?)", params[:username]).first!

    if @user == current_user
      @sits = @user.sits.newest_first.with_body

      respond_to do |format|
        format.html
        format.json { render json: @sits }
        format.xml { render xml: @sits }
      end
    else
      render json: 'Not Authorised'
    end
  end

  private

    # Validate year and month params on user page
    def check_date
      [:year, :month].each do |v|
        if (params[v] && params[v].to_i.zero?) || params[v].to_i > (v == :year ? 3000 : 12)
          unit = v == :year ? 'year' : 'month'
          flash[:error] = "Invalid #{unit}!"
          redirect_to user_path(params[:username])
        end
      end
    end
end
