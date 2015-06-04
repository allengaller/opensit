class SearchController < ApplicationController
  def main
    base_users = user_signed_in? ? current_user.viewable_users : User.public_users
    @users = base_users.fuzzy_search(params[:q]).paginate(:page => params[:page])

    base_sits = user_signed_in? ? Sit.content_i_can_view(current_user) : Sit.public_sits
    @sits = base_sits.basic_search(params[:q]).paginate(:page => params[:page])

    if Tag.find_by_name(params[:q])
      @tagged = Sit.tagged_with(params[:q]).paginate(:page => params[:page])
    end

    @page_class = "search-results"
    @title = "Search: #{params[:q]}"

    type = params[:type]

    if !type
      render 'sits'
    elsif type == 'users'
      render 'users'
    elsif type == 'tagged'
      render 'tagged'
    else
      render 'sits'
    end
  end

end
