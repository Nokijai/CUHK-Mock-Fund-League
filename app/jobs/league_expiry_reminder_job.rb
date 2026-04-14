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

  # Recurring job: live toasts near end, plus lifecycle emails when a league opens or officially closes.
  def perform(now: Time.current)
    deliver_league_started_to_members(now)
    deliver_league_ended_emails_to_members(now)
    deliver_end_reminders_to_members(now)
  end

  private

  # When start_date enters the recent past, tell joined users the league is live (10s toast) and email them once.
  def deliver_league_started_to_members(now)
    League
      .where(start_date: (now - CHECK_WINDOW)..now)
      .where("end_date > ?", now)
      .includes(league_memberships: :user)
      .find_each do |league|
        league.league_memberships.each do |membership|
          user = membership.user
          next unless user

          if claim_started_toast_slot(league.id, user.id)
            broadcast_member_card(
              user,
              league,
              title: "League started",
              body: "\"#{league.name}\" is now open for trading.",
              notification_id: "league-started-#{league.id}-#{user.id}",
              auto_dismiss_ms: MEMBER_TOAST_MS
            )
          end

          next unless claim_started_email_slot(league.id, user.id)

          LeagueMailer.league_opened(user, league).deliver_now
        end
      end
  end

  # After end_date passes, email every member once so they know the league window is officially closed.
  def deliver_league_ended_emails_to_members(now)
    # Email delivery should not depend on a narrow timing window:
    # if the worker is down for a few minutes, we still want every joined user
    # to receive the closure email once the league has ended.
    LeagueMembership
      .joins(:league)
      .where(leagues: { end_date: ..now })
      .where(league_closed_email_sent_at: nil)
      .includes(:user, :league)
      .find_each do |membership|
        membership.with_lock do
          # Double-check under the row lock to prevent double-sends in multi-worker setups.
          next if membership.league_closed_email_sent_at.present?

          user = membership.user
          league = membership.league
          next unless user && league

          LeagueMailer.league_closed(user, league).deliver_now
          membership.update!(league_closed_email_sent_at: now)
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

  # Toast dedupe key (independent from email so both channels can fire together once).
  def claim_started_toast_slot(league_id, user_id)
    key = "league_started_notice/#{league_id}/#{user_id}"
    Rails.cache.write(key, true, expires_in: 2.days, unless_exist: true)
  end

  # Email dedupe: same 1-minute window as the toast, but its own key so we never double-send after a restart.
  def claim_started_email_slot(league_id, user_id)
    key = "league_started_email/#{league_id}/#{user_id}"
    Rails.cache.write(key, true, expires_in: 2.days, unless_exist: true)
  end

  # One closure email per member; relies on Solid Queue recurring tick (see config/recurring.yml).
  def claim_ended_email_slot(league_id, user_id)
    key = "league_ended_email/#{league_id}/#{user_id}"
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
