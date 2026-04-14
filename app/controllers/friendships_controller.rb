class FriendshipsController < ApplicationController
  # GET /friendships — render friends list (Turbo Frame)
  def index
    @friends = current_user.friends.order(:username)
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  # DELETE /friendships/:id — unfriend
  def destroy
    friendship = current_user.friendships.find(params[:id])
    friend = friendship.friend

    # Remove both directions
    Friendship.where(user: current_user, friend: friend).destroy_all
    Friendship.where(user: friend, friend: current_user).destroy_all

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.remove("friend_#{friend.id}"),
          turbo_stream.update("friends-count", current_user.friends.count.to_s)
        ]
      }
      format.html { redirect_to friendships_path, notice: "#{friend.username} removed from friends." }
    end
  end

  # GET /friendships/search — search users to add as friends
  def search
    query = params[:q].to_s.strip
    if query.length >= 2
      @users = User.where("lower(username) LIKE ?", "%#{sanitize_sql_like(query.downcase)}%")
                    .where.not(id: current_user.id)
                    .limit(10)
    else
      @users = User.none
    end

    render partial: "friendships/search_results", locals: { users: @users }
  end

  private

  def sanitize_sql_like(string)
    string.gsub(/[%_\\]/) { |m| "\\#{m}" }
  end
end
