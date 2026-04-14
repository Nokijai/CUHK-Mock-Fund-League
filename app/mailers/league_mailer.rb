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
    attach_league_certificate_pdf!
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

    # Final account balance is computed at closure time so both email + PDF use the same figure.
    @final_balance_date = @league.end_date.to_date
    @final_balance = compute_final_balance_for_member
  end

  def compute_final_balance_for_member
    portfolio = Portfolio
      .includes(:holdings)
      .find_by(user_id: @user.id, league_id: @league.id)
    return @league.starting_capital.to_f unless portfolio

    # Use the same valuation logic as leaderboards / portfolio dashboards.
    valuator = PortfolioValuationService.new
    valuator.preload_symbols(portfolio.holdings.map(&:symbol))

    total = valuator.total_value(portfolio).to_f

    # Persist a snapshot at the league end date for auditability and future reporting.
    # If a snapshot already exists for that date, `find_or_initialize_by` will update it.
    PortfolioSnapshotService.new(valuator: valuator).take_snapshot(portfolio, date: @final_balance_date)

    total
  end

  def attach_league_certificate_pdf!
    pdf = LeagueCertificatePdfService.new(
      league: @league,
      user: @user,
      final_balance: @final_balance,
      ranked_at: Time.current
    ).render

    attachments["league-certificate-#{@league.id}.pdf"] = {
      mime_type: "application/pdf",
      content: pdf
    }
  end
end
