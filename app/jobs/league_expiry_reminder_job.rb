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
    deliver_team_chat_expiry_warnings(now)
    deliver_winner_congratulations(now)
    award_experience_points(now)
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

  # When a league just ended, compute the final leaderboard and broadcast a global congrats to the winner.
  def deliver_winner_congratulations(now)
    League
      .where(end_date: (now - CHECK_WINDOW)..now)
      .find_each do |league|
        next unless claim_winner_congrats_slot(league.id)

        rankings = if league.team_mode?
          TeamLeaderboardService.new(league).compute
        else
          LeaderboardService.new(league).compute
        end

        winner = rankings.first
        next unless winner

        winner_name = league.team_mode? ? winner[:team_name] : winner[:name]

        league.broadcast_prepend_to(
          "league_notifications",
          target: "realtime-notifications",
          partial: "leagues/realtime_notification",
          locals: {
            title: "League finished! \u{1F3C6}",
            body: "Congratulations to #{winner_name} for winning \"#{league.name}\"!",
            league: league,
            tone: :success,
            notification_id: "league-winner-#{league.id}",
            auto_dismiss_ms: 0
          }
        )
      end
  end

  def claim_winner_congrats_slot(league_id)
    key = "league_winner_congrats/#{league_id}"
    Rails.cache.write(key, true, expires_in: 3.days, unless_exist: true)
  end

  # Broadcast a system warning into each team chat ~1 hour before the league ends.
  def deliver_team_chat_expiry_warnings(now)
    one_hour = 1.hour.to_i
    League
      .where(end_date: now..(now + one_hour + CHECK_WINDOW.to_i))
      .where("rules->>'team_mode' = ?", "true")
      .includes(:teams)
      .find_each do |league|
        league.teams.each do |team|
          next unless claim_team_chat_warning_slot(team.id)

          stream_key = Message.team_stream_key(team.id)
          minutes_left = ((league.end_date - now) / 60).round

          Turbo::StreamsChannel.broadcast_append_to(
            stream_key,
            target: "chat-messages-#{stream_key}",
            html: <<~HTML
              <div class="terminal-chat-message terminal-chat-system-message">
                <span class="terminal-chat-system-text">⚠ League &ldquo;#{ERB::Util.html_escape(league.name)}&rdquo; ends in ~#{minutes_left} min. This team chat will close.</span>
              </div>
            HTML
          )
        end
      end
  end

  def claim_team_chat_warning_slot(team_id)
    key = "team_chat_expiry_warning/#{team_id}"
    Rails.cache.write(key, true, expires_in: 2.days, unless_exist: true)
  end

  # Award experience points to all participants when a league just ended.
  def award_experience_points(now)
    League
      .where(end_date: (now - CHECK_WINDOW)..now)
      .find_each do |league|
        next unless claim_xp_award_slot(league.id)

        ExperienceAwardService.new(league).award!
      end
  end

  def claim_xp_award_slot(league_id)
    key = "league_xp_awarded/#{league_id}"
    Rails.cache.write(key, true, expires_in: 3.days, unless_exist: true)
  end

  # Private per-user Turbo stream (see layout): timed toasts share the same dismiss controller as global notices.
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
