class ProfilesController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
    @level = @user.current_level
    @next_level = @user.next_level
    @progress = @user.xp_progress_to_next
    @leagues_played = @user.league_memberships.count
    @friends_count = @user.friends.count
    @member_since = @user.created_at
  end
end
