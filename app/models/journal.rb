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

  def first_sit
    return Sit.unscoped.where("user_id = ?", @user.id).oldest_first.first if viewing_my_journal?
    return Sit.where("user_id = ?", @user.id).oldest_first.first
  end

  def first_sit_date
    first_sit.created_at.strftime("%Y %m").split(' ')
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
end