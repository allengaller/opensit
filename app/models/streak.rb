module Streak
  def streak
    streak_count = 0
    if sits.yesterday.count > 0
      next_newest = false
      sits.newest_first.each do |sit|
        # Only proceed if this isn't the first iteration
        if !next_newest
          next_newest = sit
          next
        end
        # If the 2 consecutive sits weren't on the same day
        if sit.created_at.to_date != next_newest.created_at.to_date
          # Only increment if the distance between the sits is exactly a day
          distance = (next_newest.created_at.to_date - sit.created_at.to_date).to_i
          if distance == 1
            streak_count += 1
          else
            # End of sit streak :(
            break
          end
        end
        next_newest = sit
      end
    end

    # If they sat at least yesterday, or more
    if streak_count > 0
      # And they sat today. Then they get today's sit added to their streak
      if sits.today.count > 0
        streak_count += 1
      else
        # Otherwise a sit streak of 1 doesn't count as a streak :(
        streak_count = 0
      end
    end

    streak_count
  end
end