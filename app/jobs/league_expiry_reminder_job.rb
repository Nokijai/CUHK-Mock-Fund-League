class LeagueExpiryReminderJob < ApplicationJob
  queue_as :default

  # Fires once per user per checkpoint inside a 1-minute window before that offset from league end.
  # Hash order is high → low so `due_checkpoint` picks the tightest matching band first.
  END_CHECKPOINTS = {
    1.day.to_i => "1 day left",
    1.hour.to_i => "1 hour left",
    30.minutes.to_i => "30 minutes left",
    15.minutes.to_i => "15 minutes left"
  }.freeze
  CHECK_WINDOW = 1.minute
  # Scan far enough ahead to catch the 1-day reminder without scanning the whole table.
  MAX_END_LOOKAHEAD = 1.day + CHECK_WINDOW
  MEMBER_TOAST_MS = 10_000

  def perform(now: Time.current)
    deliver_league_started_to_members(now)
    deliver_end_reminders_to_members(now)
  end

  private

  # When start_date enters the recent past, tell joined users the league is live (10s toast).
  def deliver_league_started_to_members(now)
    League
      .where(start_date: (now - CHECK_WINDOW)..now)
      .where("end_date > ?", now)
      .includes(league_memberships: :user)
      .find_each do |league|
        league.league_memberships.each do |membership|
          user = membership.user
          next unless user
          next unless claim_started_slot(league.id, user.id)

          broadcast_member_card(
            user,
            league,
            title: "League started",
            body: "\"#{league.name}\" is now open for trading.",
            notification_id: "league-started-#{league.id}-#{user.id}",
            auto_dismiss_ms: MEMBER_TOAST_MS
          )
        end
      end
  end

  def deliver_end_reminders_to_members(now)
    League
      .where(end_date: (now - CHECK_WINDOW)..(now + MAX_END_LOOKAHEAD))
      .includes(league_memberships: :user)
      .find_each do |league|
        next if league.end_date.blank?

        seconds_left = (league.end_date - now).to_i
        checkpoint = due_end_checkpoint(seconds_left)
        next unless checkpoint

        message = "League \"#{league.name}\" — #{END_CHECKPOINTS.fetch(checkpoint)} until the end."
        notify_joined_users(league, checkpoint, message)
      end
  end

  def due_end_checkpoint(seconds_left)
    END_CHECKPOINTS.keys.find { |seconds| seconds_left <= seconds && seconds_left > (seconds - CHECK_WINDOW.to_i) }
  end

  def notify_joined_users(league, checkpoint, message)
    league.league_memberships.each do |membership|
      user = membership.user
      next unless user
      next unless claim_end_slot(league.id, user.id, checkpoint)

      broadcast_member_card(
        user,
        league,
        title: "League ending soon",
        body: message,
        notification_id: "league-end-#{league.id}-#{checkpoint}-#{user.id}",
        auto_dismiss_ms: MEMBER_TOAST_MS
      )
    end
  end

  def claim_started_slot(league_id, user_id)
    key = "league_started_notice/#{league_id}/#{user_id}"
    Rails.cache.write(key, true, expires_in: 2.days, unless_exist: true)
  end

  def claim_end_slot(league_id, user_id, checkpoint)
    key = "league_expiry_notice/#{league_id}/#{user_id}/#{checkpoint}"
    Rails.cache.write(key, true, expires_in: 3.days, unless_exist: true)
  end

  # Private per-user Turbo stream (see layout): timed toasts share the same dismiss controller as global notices.
  def broadcast_member_card(user, league, title:, body:, notification_id:, auto_dismiss_ms:)
    league.broadcast_prepend_to(
      [ user, "league_notifications" ],
      target: "realtime-notifications",
      partial: "leagues/realtime_notification",
      locals: {
        title: title,
        body: body,
        league: league,
        tone: :accent,
        notification_id: notification_id,
        auto_dismiss_ms: auto_dismiss_ms
      }
    )
  end
end
