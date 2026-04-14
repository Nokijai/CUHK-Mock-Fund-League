class AddLeagueClosedEmailSentAtToLeagueMemberships < ActiveRecord::Migration[8.1]
  def change
    # Persistent dedupe for "league closed" emails.
    #
    # We intentionally track this on `league_memberships` (not Rails.cache) so:
    # - restarts don't re-send
    # - missing a 1-minute job window still allows catch-up sends later
    add_column :league_memberships, :league_closed_email_sent_at, :datetime
    add_index :league_memberships, :league_closed_email_sent_at
  end
end

