class LeagueMailer < ApplicationMailer
  def invitation_email(user, league)
    @user = user
    @league = league
    mail(to: @user.email, subject: "You've been invited to #{@league.name}")
  end

  # Sent when the competition window opens (scheduled job); includes rich league context for participants.
  def league_opened(user, league)
    assign_league_lifecycle(user, league)
    mail(
      to: @user.email,
      subject: %(Mock-Fund League — "#{@league.name}" is now open)
    )
  end

  # Sent right after the scheduled end time so members know results are final for this window.
  def league_closed(user, league)
    assign_league_lifecycle(user, league)
    mail(
      to: @user.email,
      subject: %(Mock-Fund League — "#{@league.name}" has closed)
    )
  end

  private

  # Shared assigns for HTML/text templates (fact sheet + safe plain-text description).
  def assign_league_lifecycle(user, league)
    @user = user
    @league = league
    @league_url = league_url(league)
    @leaderboard_url = league_leaderboard_url(league)
    raw_description = league.description.to_s
    # Mailers do not expose `helpers` until a view renders; use the global helper proxy for HTML email safety.
    plain = ActionController::Base.helpers.strip_tags(raw_description).squish.presence
    @league_description_plain = plain&.truncate(480)
    @participant_count = league.league_memberships.size
  end
end
