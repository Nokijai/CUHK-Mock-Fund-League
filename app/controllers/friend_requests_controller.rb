class FriendRequestsController < ApplicationController
  # GET /friend_requests — pending incoming requests (Turbo Frame)
  def index
    @incoming = current_user.pending_received_friend_requests.includes(:sender).order(created_at: :desc)
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  # POST /friend_requests — send a friend request
  def create
    receiver = User.find(params[:receiver_id])
    @friend_request = current_user.sent_friend_requests.build(receiver: receiver)

    if @friend_request.save
      # Broadcast to receiver in real-time via Turbo Stream
      Turbo::StreamsChannel.broadcast_prepend_to(
        [receiver, "friend_notifications"],
        target: "friend-requests-list",
        partial: "friend_requests/friend_request",
        locals: { friend_request: @friend_request }
      )

      # Also update the receiver's pending count badge
      Turbo::StreamsChannel.broadcast_update_to(
        [receiver, "friend_notifications"],
        target: "friend-requests-count",
        html: receiver.pending_received_friend_requests.count.to_s
      )

      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace(
            "friend-search-user-#{receiver.id}",
            html: "<div id=\"friend-search-user-#{receiver.id}\" class=\"terminal-friend-search-row\"><span class=\"terminal-friend-name\">#{ERB::Util.html_escape(receiver.username)}</span><span class=\"terminal-friend-status-sent\">REQUEST SENT</span></div>".html_safe
          )
        }
        format.html { redirect_to friendships_path, notice: "Friend request sent to #{receiver.username}." }
      end
    else
      respond_to do |format|
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace(
            "friend-search-user-#{receiver.id}",
            html: "<div id=\"friend-search-user-#{receiver.id}\" class=\"terminal-friend-search-row\"><span class=\"terminal-friend-name\">#{ERB::Util.html_escape(receiver.username)}</span><span class=\"terminal-friend-status-error\">#{ERB::Util.html_escape(@friend_request.errors.full_messages.first)}</span></div>".html_safe
          )
        }
        format.html { redirect_to friendships_path, alert: @friend_request.errors.full_messages.first }
      end
    end
  end

  # PATCH /friend_requests/:id/accept
  def accept
    @friend_request = current_user.received_friend_requests.pending.find(params[:id])
    @friend_request.accept!

    # Notify the sender in real-time
    Turbo::StreamsChannel.broadcast_prepend_to(
      [@friend_request.sender, "friend_notifications"],
      target: "realtime-notifications",
      html: "<div class=\"terminal-realtime-notif-card terminal-realtime-notif-card--success\" data-controller=\"realtime-notification\" data-realtime-notification-auto-dismiss-ms-value=\"8000\"><span class=\"terminal-notif-body\"><strong>#{ERB::Util.html_escape(@friend_request.receiver.username)}</strong> accepted your friend request!</span><button class=\"terminal-notif-close\" data-action=\"realtime-notification#dismiss\">&times;</button></div>"
    )

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.remove("friend-request-#{@friend_request.id}"),
          turbo_stream.update("friend-requests-count", current_user.pending_received_friend_requests.count.to_s)
        ]
      }
      format.html { redirect_to friendships_path, notice: "You are now friends with #{@friend_request.sender.username}!" }
    end
  end

  # PATCH /friend_requests/:id/decline
  def decline
    @friend_request = current_user.received_friend_requests.pending.find(params[:id])
    @friend_request.decline!

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.remove("friend-request-#{@friend_request.id}"),
          turbo_stream.update("friend-requests-count", current_user.pending_received_friend_requests.count.to_s)
        ]
      }
      format.html { redirect_to friendships_path, notice: "Friend request declined." }
    end
  end
end
