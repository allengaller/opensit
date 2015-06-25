class Journal
  def initialize(user, current_user = nil)
    @user = user
    @current_user = current_user if current_user
  end

  def viewing_my_journal?
    @current_user == @user
  end

  def has_sat?
    @user.sits.present?
  end

  def total_hours_sat
    @user.sits.sum(:duration) / 60
  end

  def latest_sit
    if viewing_my_journal?
      Sit.unscoped do
        return @user.sits.newest_first.limit(1)
      end
    else
      return @user.sits.newest_first.limit(1)
    end
  end

  def last_update
    latest_sit.created_at
  end

  def first_sit
    return Sit.unscoped.where("user_id = ?", @user.id).oldest_first.first if viewing_my_journal?
    return Sit.where("user_id = ?", @user.id).oldest_first.first
  end

  def first_sit_date
    first_sit.created_at.strftime("%Y %m").split(' ')
  end

  def months_sat
    dates = []
    from = first_sit.created_at
    to = Date.today
    (Date.new(from.year, from.month)..Date.new(to.year, to.month)).each do |d|
      if d.day == 1
        # PLUCK DATES ONLY on SINGLE QUERY and CALCULATE sits_this_month in ruby
        sits_this_month = sits_by_month(d.month, d.year).count
        if sits_this_month > 0
          padded_month = d.month.to_s.rjust(2, '0')
          key = "#{padded_month}_#{d.year}".to_s
          row = {}
          row[key] = [d.year, padded_month, sits_this_month]
          dates.push row
        end
      end
    end

    return dates.reverse
  end

  def most_recent_month
    months_sat.first.keys[0].split('_')
  end

  def next_month(month, year)
    key = "#{month}_#{year}"
    # Get a list of all month keys so we can
    # find current month and locate the next one
    months_list = months_sat.collect {|entry| entry.keys[0]}
    current_index = months_list.index key
    if current_index && current_index != 0 # Check there is a next month
      target_month = months_sat[current_index - 1].values[0][1]
      target_year = months_sat[current_index - 1].values[0][0]
      return "#{target_month}_#{target_year}"
    else
      return nil
    end
  end

  def previous_month(month, year)
    key = "#{month}_#{year}"
    # Get a list of all month keys so we can
    # find current month and locate the next one
    months_list = months_sat.collect {|entry| entry.keys[0]}
    current_index = months_list.index key
    if current_index && months_sat[current_index + 1] # Check there is a previous month
      target_month = months_sat[current_index + 1].values[0][1]
      target_year = months_sat[current_index + 1].values[0][0]
      return "#{target_month}_#{target_year}"
    else
      return nil
    end
    # check current_user
  end

  def sits_by_year(year)
    @user.sits.where("EXTRACT(year FROM created_at) = ?", year.to_s)
  end

  def sits_by_month(month, year)
    if viewing_my_journal?
      Sit.unscoped do
        @user.sits.where("EXTRACT(year FROM created_at) = ?
          AND EXTRACT(month FROM created_at) = ?", year.to_s, month.to_s.rjust(2, '0'))
      end
    elsif (@current_user && @current_user.can_view_content_of(@user)) || @user.public_journal?
      @user.sits.where("EXTRACT(year FROM created_at) = ?
        AND EXTRACT(month FROM created_at) = ?", year.to_s, month.to_s.rjust(2, '0'))
    end
  end

  def time_sat_this_month(month, year)
    minutes = @user.sits.where("EXTRACT(year FROM created_at) = ?
      AND EXTRACT(month FROM created_at) = ?", year.to_s, month.to_s.rjust(2, '0')).sum(:duration)
    total_time = minutes.divmod(60)
    text = "#{total_time[0]} hours"
    text << " #{total_time[1]} minutes" if !total_time[1].zero?
    text
  end

  # Do not put me in a loop! Use #days_sat_in_date_range
  # Returns true if user sat on the date passed
  def sat_on_date?(date)
    @user.sits.where(created_at: date.beginning_of_day..date.end_of_day).present?
  end

  def days_sat_this_month(month, year)
    days_sat_in_date_range(Date.new(year.to_i, month.to_i, 01), Date.new(year.to_i, month.to_i, -1))
  end

  def entries_this_month(month, year)
    sits_by_month(month, year).count
  end

  # Returns the number of days, in a date range, where the user sat
  def days_sat_in_date_range(start_date, end_date)
    all_dates = @user.sits.where(created_at: start_date.beginning_of_day..end_date.end_of_day).order('created_at DESC').pluck(:created_at)
    last_one = total = 0
    # Dates are ordered so just check the current date aint the same day as the one before
    # This stops multiple sits in one day incrementing the total by more than 1
    all_dates.each do |d|
      total += 1 if d.strftime("%d %B %Y") != last_one
      last_one = d.strftime("%d %B %Y")
    end
    total
  end

  # Do not put me in a loop! Use #days_sat_for_min_x_minutes_in_date_range
  def sat_for_x_on_date?(minutes, date)
    if @user.sits.where(created_at: date.beginning_of_day..date.end_of_day).present?
      time_sat_on_date(date) >= minutes
    else
      false
    end
  end

  # Returns the number of days, in a date range, where user sat for a minimum x minutes that day
  def days_sat_for_min_x_minutes_in_date_range(duration, start_date, end_date)
    all_sits = @user.sits.where(created_at: start_date.beginning_of_day..end_date.end_of_day).order('created_at DESC')
    all_datetimes = all_sits.pluck(:created_at)
    all_dates = []
    all_datetimes.each do |d|
      all_dates.push d.strftime("%d %B %Y")
    end
    all_dates.uniq! # Stop multiple sits on the same day incrementing the total

    total_days = 0

    all_dates.each do |d|
      total_time = 0
      all_sits.where(created_at: d.to_date.beginning_of_day..d.to_date.end_of_day).each do |s|
        total_time += s.duration
      end
      total_days += 1 if total_time >= duration
    end
    total_days
  end

  def time_sat_on_date(date)
    total_time = 0
    @user.sits.where(created_at: date.beginning_of_day..date.end_of_day).each do |s|
      total_time += s.duration
    end
    total_time
  end
end