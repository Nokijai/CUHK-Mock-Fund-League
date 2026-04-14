class MessagesController < ApplicationController
  # GET /messages/world — world chat conversation
  def world
    @messages = Message.world_messages.includes(:sender).last(100)
    stream_key = Message.world_stream_key

    render partial: "messages/world_conversation", locals: {
      messages: @messages,
      stream_key: stream_key
    }
  end

  # GET /messages/team_list — list of teams user is in (grouped by league)
  def team_list
    @team_memberships = current_user.team_memberships
                          .includes(team: :league)
                          .order("leagues.name ASC, teams.name ASC")
    render partial: "messages/team_list", locals: { team_memberships: @team_memberships }
  end

  # GET /messages/team_conversation/:team_id — team chat
  def team_conversation
    @team = Team.find(params[:team_id])

    unless TeamMembership.exists?(team_id: @team.id, user_id: current_user.id)
      render html: '<div class="terminal-chat-empty">You are not a member of this team.</div>'.html_safe
      return
    end

    league = @team.league
    league_ended = league.end_date.present? && league.end_date < Time.current

    @messages = Message.team_messages(@team).includes(:sender).last(100)
    stream_key = Message.team_stream_key(@team.id)

    render partial: "messages/team_conversation", locals: {
      team: @team,
      league: league,
      messages: @messages,
      stream_key: stream_key,
      league_ended: league_ended
    }
  end

  # GET /messages/conversation/:friend_id — individual chat
  def conversation
    @friend = current_user.friends.find(params[:friend_id])
    @messages = Message.conversation_between(current_user, @friend).last(50)
    stream_key = Message.chat_stream_key(current_user.id, @friend.id)

    render partial: "messages/conversation", locals: {
      friend: @friend,
      messages: @messages,
      stream_key: stream_key
    }
  end

  # POST /messages — send a message (handles all channel types)
  def create
    channel = params[:channel_type].to_s

    case channel
    when "world"
      send_world_message
    when "team"
      send_team_message
    when "individual"
      send_individual_message
    else
      render json: { error: "Invalid channel type" }, status: :unprocessable_entity
    end
  end

  # GET /messages/friends_list — friends list for individual chat
  def friends_list
    @friends = current_user.friends.order(:username)
    render partial: "messages/friends_list", locals: { friends: @friends }
  end

  private

  def send_world_message
    @message = current_user.sent_messages.build(
      channel_type: "world",
      body: params[:body].to_s.strip
    )

    if @message.save
      Turbo::StreamsChannel.broadcast_append_to(
        Message.world_stream_key,
        target: "chat-messages-#{Message.world_stream_key}",
        partial: "messages/message",
        locals: { message: @message, current_user_id: @message.sender_id }
      )
      head :ok
    else
      render json: { error: @message.errors.full_messages.first }, status: :unprocessable_entity
    end
  end

  def send_team_message
    @team = Team.find(params[:team_id])
    league = @team.league

    @message = current_user.sent_messages.build(
      channel_type: "team",
      team: @team,
      league: league,
      body: params[:body].to_s.strip
    )

    if @message.save
      stream_key = Message.team_stream_key(@team.id)
      Turbo::StreamsChannel.broadcast_append_to(
        stream_key,
        target: "chat-messages-#{stream_key}",
        partial: "messages/message",
        locals: { message: @message, current_user_id: @message.sender_id }
      )
      head :ok
    else
      render json: { error: @message.errors.full_messages.first }, status: :unprocessable_entity
    end
  end

  def send_individual_message
    @friend = current_user.friends.find(params[:receiver_id])
    @message = current_user.sent_messages.build(
      channel_type: "individual",
      receiver: @friend,
      body: params[:body].to_s.strip
    )

    if @message.save
      stream_key = Message.chat_stream_key(current_user.id, @friend.id)
      Turbo::StreamsChannel.broadcast_append_to(
        stream_key,
        target: "chat-messages-#{stream_key}",
        partial: "messages/message",
        locals: { message: @message, current_user_id: @message.sender_id }
      )
      head :ok
    else
      render json: { error: @message.errors.full_messages.first }, status: :unprocessable_entity
    end
  end
end
