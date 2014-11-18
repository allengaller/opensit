class SitsController < ApplicationController
  before_filter :authenticate_user!, :except => [:show]

  # GET /sits/1
  def show
    @sit = Sit.find(params[:id])
    @latest = @sit.user.latest_sit(current_user)

    redirect_to me_path if !@sit.viewable?(current_user)

    # Views, not very accurate as any guest visit increments by one
    if current_user
      @sit.increment!(:views, by = 1) if current_user.id != @sit.user_id
    else
      @sit.increment!(:views, by = 1)
    end

    @user = @sit.user

    if @sit.is_sit?
      @title = "#{@sit.duration} minute meditation journal by #{@user.display_name}"
    else
      @title = "#{@sit.title}, a meditation journal by #{@user.display_name}"
    end

    @previous = @sit.prev(current_user)
    @next = @sit.next(current_user)

    @page_class = 'view-sit'
  end

  # GET /sits/new
  def new
    @sit ||= Sit.new
    @user = current_user

    @title = 'New sit'
    @page_class = 'new-sit'
  end

  # GET /sits/1/edit
  def edit
    @sit = Sit.find(params[:id])
    @user = current_user

    @title = 'Edit sit'
    @page_class = 'edit-sit'
  end

  # POST /sits
  def create
    @user = current_user
    @sit = @user.sits.new(params[:sit])

    @sit.private = true if @user.private_journal?
    @sit.created_at = DateTime.strptime(params[:custom_date], "%m/%d/%Y %l:%M %p") if params[:custom_date] != ''

    if @sit.save
      if !@sit.body.empty?
        redirect_to @sit, notice: 'Your entry was added. Good job!'
      else
        redirect_to user_path(@user, year: Date.today.year, month: Date.today.month), notice: 'Your entry was added. Good job!'
      end
    else
      @page_class = 'new-sit'
      render action: "new"
    end
  end

  # PUT /sits/1
  def update
    @sit = Sit.find(params[:id])
    @sit.created_at = DateTime.strptime(params[:custom_date], "%m/%d/%Y %l:%M %p") if params[:custom_date]

    if @sit.update_attributes(params[:sit])
      redirect_to @sit, notice: 'Sit was successfully updated.'
    else
      render action: "edit"
    end
  end

  # DELETE /sits/1
  def destroy
    @sit = Sit.find(params[:id])
    @sit.destroy

    redirect_to me_path
  end
end
