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

  def latest_sit
    if viewing_my_journal?
      Sit.unscoped do
        return @user.sits.newest_first.limit(1)
      end
    else
      return @user.sits.newest_first.limit(1)
    end
  end

  def total_hours_sat
    @user.sits.sum(:duration) / 60
  end

  def first_sit
    return Sit.unscoped.where("user_id = ?", @user.id).oldest_first.first if viewing_my_journal?
    return Sit.where("user_id = ?", @user.id).oldest_first.first
  end

  def first_sit_date
    first_sit.created_at.strftime("%Y %m").split(' ')
  end

  def months_sat
    dates = {}
    from = first_sit.created_at
    to = Date.today
    (Date.new(from.year, from.month)..Date.new(to.year, to.month)).each do |d|
      if d.day == 1
        # PLUCK DATES ONLY on SINGLE QUERY and CALCULATE sits_this_month in ruby
        sits_this_month = sits_by_month(d.month, d.year).count
        if sits_this_month > 0
          dates[d.year] = {} if !dates[d.year]
          dates[d.year][d.month] = sits_this_month
        end
      end
    end

    return dates
  end

  def dropdown_months
    return false if !has_sat?

    year, month = Time.now.strftime("%Y %m").split(' ')
    dates = []

    # Build list of all months from current date to first sit
    while [year.to_s, month.to_s.rjust(2, '0')] != first_sit_date
      month = month.to_i
      year = year.to_i
      if month != 0
        dates << [year, month]
        month -= 1
      else
        year -= 1
        month = 12
      end
    end

    # Add first sitting month
    dates << [first_sit_date[0].to_i, first_sit_date[1].to_i]

    # Filter out any months with no activity
    pointer = 2000
    dates_totals = []

    # dates is an array of months: ["2014 10", "2014 09"]
    dates.each do |m|
      year, month = m
      month_total = @user.sits_by_month(month, year).count

      if pointer != year
        year_total = @user.sits_by_year(year).count
        dates_totals << [year, year_total] if !year_total.zero?
      end

      if month_total != 0
        dates_totals << [month, month_total]
      end

      pointer = year
    end

    return dates_totals
  end

  def sits_by_year(year)
    sits.where("EXTRACT(year FROM created_at) = ?", year.to_s)
  end

  def sits_by_month(month, year)
    if viewing_my_journal?
      Sit.unscoped do
        @user.sits.where("EXTRACT(year FROM created_at) = ?
          AND EXTRACT(month FROM created_at) = ?", year.to_s, month.to_s.rjust(2, '0'))
      end
    elsif @current_user.can_view_content_of(@user)
      sits.where("EXTRACT(year FROM created_at) = ?
        AND EXTRACT(month FROM created_at) = ?", year.to_s, month.to_s.rjust(2, '0'))
      .where('user_id in (?)')
    else
      # Guests - public only
      # Make where("sits.user_id IN (?)", public_users) a scope to use in EXPLORE too
    end
  end

  def time_sat_this_month(month: month, year: year)
    minutes = sits.where("EXTRACT(year FROM created_at) = ?
      AND EXTRACT(month FROM created_at) = ?", year.to_s, month.to_s.rjust(2, '0')).sum(:duration)
    total_time = minutes.divmod(60)
    text = "#{total_time[0]} hours"
    text << " #{total_time[1]} minutes" if !total_time[1].zero?
    text
  end

  # Do not put me in a loop! Use #days_sat_in_date_range
  # Returns true if user sat on the date passed
  def sat_on_date?(date)
    sits.where(created_at: date.beginning_of_day..date.end_of_day).present?
  end

  # Convenience method for generating monthly stats for /u/
  def get_monthly_stats(month, year)
    @stats = {}
    @stats[:days_sat_this_month] = days_sat_in_date_range(Date.new(year.to_i, month.to_i, 01), Date.new(year.to_i, month.to_i, -1))
    @stats[:time_sat_this_month] = time_sat_this_month(month: month, year: year)
    @stats[:entries_this_month] = sits_by_month(month, year).count
    @stats
  end

  # Returns the number of days, in a date range, where the user sat
  def days_sat_in_date_range(start_date, end_date)
    all_dates = sits.where(created_at: start_date.beginning_of_day..end_date.end_of_day).order('created_at DESC').pluck(:created_at)
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
    if sits.where(created_at: date.beginning_of_day..date.end_of_day).present?
      time_sat_on_date(date) >= minutes
    else
      false
    end
  end

  # Returns the number of days, in a date range, where user sat for a minimum x minutes that day
  def days_sat_for_min_x_minutes_in_date_range(duration, start_date, end_date)
    all_sits = sits.where(created_at: start_date.beginning_of_day..end_date.end_of_day).order('created_at DESC')
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
    sits.where(created_at: date.beginning_of_day..date.end_of_day).each do |s|
      total_time += s.duration
    end
    total_time
  end

  # MERGE INTO THE ABOVE
  def journal_next_prev_links(by_month)
    index = @by_month[:list_of_months].index "#{year} #{sprintf '%02d', month}" if user.sits.present?

    # Generate prev/next links
    # .. for someone who's sat this month
    if index
      if @by_month[:list_of_months][index + 1]
        @prev = @by_month[:list_of_months][index + 1].split(' ')
      end

      if !index.zero?
        @next = @by_month[:list_of_months][index - 1].split(' ')
      end
    else
      if @by_month
        # Haven't sat this month - when was the last time they sat?
        @first_month =  @by_month[:list_of_months].first.split(' ')
      end
      # Haven't sat at all
    end
  end
end