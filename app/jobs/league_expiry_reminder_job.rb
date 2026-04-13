class LeagueExpiryReminderJob < ApplicationJob
  queue_as :default

  # Reminder checkpoints in seconds; 0 means the league has just expired.
  CHECKPOINTS = {
    1.hour.to_i => "1 hour left",
    15.minutes.to_i => "15 minutes left",
    5.minutes.to_i => "5 minutes left",
    0 => "League expired"
  }.freeze
  CHECK_WINDOW = 1.minute

  def perform(now: Time.current)
    # Scan only a tight time range around now to keep the recurring job cheap.
    leagues = League
      .where(end_date: (now - CHECK_WINDOW)..(now + 1.hour + CHECK_WINDOW))
      .includes(league_memberships: :user)

    leagues.find_each do |league|
      next if league.end_date.blank?

      seconds_left = (league.end_date - now).to_i
      checkpoint = due_checkpoint(seconds_left)
      next unless checkpoint

      message = "League #{league.name} has #{CHECKPOINTS.fetch(checkpoint)}."
      notify_joined_users(league, checkpoint, message)
    end
  end

  private

  def due_checkpoint(seconds_left)
    # 0 bucket is a tiny "just expired" window to avoid repeated late sends.
    return 0 if seconds_left <= 0 && seconds_left > -CHECK_WINDOW.to_i

    CHECKPOINTS.keys
      .reject(&:zero?)
      .find { |seconds| seconds_left <= seconds && seconds_left > (seconds - CHECK_WINDOW.to_i) }
  end

  def notify_joined_users(league, checkpoint, message)
    league.league_memberships.each do |membership|
      user = membership.user
      next unless user

      # Dedupe by league/user/checkpoint so recurring runs do not send duplicates.
      next unless claim_delivery_slot(league.id, user.id, checkpoint)

      broadcast_member_notice(user, league, message)
    end
  end

  def claim_delivery_slot(league_id, user_id, checkpoint)
    key = "league_expiry_notice/#{league_id}/#{user_id}/#{checkpoint}"
    Rails.cache.write(key, true, expires_in: 3.days, unless_exist: true)
  end

  def broadcast_member_notice(user, league, message)
    league.broadcast_prepend_to(
      [ user, "league_notifications" ],
      target: "realtime-notifications",
      partial: "leagues/realtime_notification",
      locals: {
        title: "League reminder",
        body: message,
        league: league
      }
    )
  end
end
