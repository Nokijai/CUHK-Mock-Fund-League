class LeagueExpiryReminderJob < ApplicationJob
  queue_as :default

  # Fires once per user per checkpoint inside a 1-minute window before that offset from league end.
  END_CHECKPOINTS = {
    1.day.to_i => "1 day left",
    1.hour.to_i => "1 hour left",
    30.minutes.to_i => "30 minutes left",
    15.minutes.to_i => "15 minutes left"
  }.freeze
  CHECK_WINDOW = 1.minute
  MAX_END_LOOKAHEAD = 1.day + CHECK_WINDOW
  MEMBER_TOAST_MS = 0

  def perform(now: Time.current)
    deliver_league_started_notifications(now)
    deliver_end_reminder_notifications(now)
    deliver_league_ended_notifications(now)
  end

  private

  # Notify only joined users when a league starts.
  def deliver_league_started_notifications(now)
    League
      .where(start_date: (now - CHECK_WINDOW)..now)
      .where("end_date > ?", now)
      .find_each do |league|
        league.league_memberships.includes(:user).find_each do |membership|
          user = membership.user
          next unless claim_user_slot("league_started_notice/#{league.id}/#{user.id}", event_at: league.start_date)

          LeagueMailer.league_opened(user, league).deliver_now
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

  # Broadcast 15-minute warnings only for leagues that run longer than 30 minutes.
  def deliver_end_reminder_notifications(now)
    League
      .where(end_date: (now - CHECK_WINDOW)..(now + MAX_END_LOOKAHEAD))
      .find_each do |league|
        next if league.end_date.blank?
        next unless fifteen_minute_notice_allowed?(league)

        seconds_left = (league.end_date - now).to_i
        checkpoint = due_end_checkpoint(seconds_left)
        next unless checkpoint

        league.league_memberships.includes(:user).find_each do |membership|
          user = membership.user
          next unless claim_user_slot("league_expiry_notice/#{league.id}/#{user.id}/#{checkpoint}", event_at: league.end_date)

          broadcast_member_card(
            user,
            league,
            title: "League ending soon",
            body: "League \"#{league.name}\" — #{END_CHECKPOINTS.fetch(checkpoint)} until the end.",
            notification_id: "league-end-#{league.id}-#{checkpoint}-#{user.id}",
            auto_dismiss_ms: MEMBER_TOAST_MS
          )
        end
      end
  end

  def deliver_league_ended_notifications(now)
    League
      .where(end_date: (now - CHECK_WINDOW)..now)
      .find_each do |league|
        league.league_memberships.includes(:user).find_each do |membership|
          user = membership.user
          next unless claim_user_slot("league_ended_notice/#{league.id}/#{user.id}", event_at: league.end_date)

          LeagueMailer.league_closed(user, league).deliver_now
          membership.update_column(:league_closed_email_sent_at, Time.current)
          broadcast_member_card(
            user,
            league,
            title: "League ended",
            body: "\"#{league.name}\" has ended. Final standings are now available.",
            notification_id: "league-ended-#{league.id}-#{user.id}",
            auto_dismiss_ms: MEMBER_TOAST_MS
          )
        end
      end
  end

  def due_end_checkpoint(seconds_left)
    END_CHECKPOINTS.keys.find { |seconds| seconds_left <= seconds && seconds_left > (seconds - CHECK_WINDOW.to_i) }
  end

  def fifteen_minute_notice_allowed?(league)
    return false if league.start_date.blank? || league.end_date.blank?

    (league.end_date - league.start_date) > 30.minutes
  end

  def claim_user_slot(key, event_at: nil)
    Rails.cache.write(key, true, expires_in: 3.days, unless_exist: true)
  end

  # Private Turbo stream to a member-only reminder channel.
  def broadcast_member_card(user, league, title:, body:, notification_id:, auto_dismiss_ms:)
    user.broadcast_prepend_to(
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
