class LeagueMailer < ApplicationMailer
  def invitation_email(user, league)
    @user = user
    @league = league
    mail(to: @user.email, subject: "You've been invited to #{@league.name}")
  end
end
