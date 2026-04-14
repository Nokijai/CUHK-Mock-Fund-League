require "rails_helper"

RSpec.describe "Api::V1::Leagues", type: :request do
  let(:headers) { { "Content-Type" => "application/json", "Accept" => "application/json" } }
  let(:current_user) { create(:user) }

  before do
    # API controllers inherit authentication from ApplicationController.
    sign_in current_user
  end

  # ─────────────────────────────────────────────────────────────
  # GET /api/v1/leagues
  # ─────────────────────────────────────────────────────────────
  describe "GET /api/v1/leagues" do
    context "when there are leagues" do
      before { create_list(:league, 3) }

      it "returns 200 and an array of leagues" do
        get "/api/v1/leagues", headers: headers
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.length).to eq(3)
      end

      it "includes expected fields in each item" do
        get "/api/v1/leagues", headers: headers
        json = JSON.parse(response.body)
        expect(json.first.keys).to include("id", "name", "description",
                                           "starting_capital", "start_date",
                                           "end_date", "member_count")
      end
    end

    context "when there are no leagues" do
      it "returns an empty array" do
        get "/api/v1/leagues", headers: headers
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq([])
      end
    end
  end

  # ─────────────────────────────────────────────────────────────
  # GET /api/v1/leagues/:id
  # ─────────────────────────────────────────────────────────────
  describe "GET /api/v1/leagues/:id" do
    let!(:league) { create(:league) }
    let!(:user)   { create(:user) }
    let!(:membership) { create(:league_membership, user: user, league: league) }

    it "returns 200 with full details" do
      get "/api/v1/leagues/#{league.id}", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(league.id)
      expect(json["name"]).to eq(league.name)
      expect(json.keys).to include("rules", "members")
    end

    it "includes member list" do
      get "/api/v1/leagues/#{league.id}", headers: headers
      json = JSON.parse(response.body)
      expect(json["member_count"]).to eq(1)
      expect(json["members"].first["email"]).to eq(user.email)
    end

    it "returns 404 for unknown id" do
      get "/api/v1/leagues/0", headers: headers
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["errors"]).to include("League not found")
    end
  end

  # ─────────────────────────────────────────────────────────────
  # POST /api/v1/leagues
  # ─────────────────────────────────────────────────────────────
  describe "POST /api/v1/leagues" do
    let(:valid_params) do
      {
        league: {
          name:             "Spring Cup 2026",
          description:      "A fun league",
          starting_capital: 50_000,
          # Keep request specs valid regardless of calendar date.
          start_date:       1.day.from_now.to_date.iso8601,
          end_date:         2.months.from_now.to_date.iso8601
        }
      }.to_json
    end

    it "creates a league and returns 201" do
      expect {
        post "/api/v1/leagues", params: valid_params, headers: headers
      }.to change(League, :count).by(1)
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["name"]).to eq("Spring Cup 2026")
      expect(json["starting_capital"].to_f).to eq(50_000.0)
    end

    it "returns 422 when name is missing" do
      invalid = { league: { description: "no name" } }.to_json
      post "/api/v1/leagues", params: invalid, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["errors"]).to be_present
    end
  end

  # ─────────────────────────────────────────────────────────────
  # PATCH /api/v1/leagues/:id
  # ─────────────────────────────────────────────────────────────
  describe "PATCH /api/v1/leagues/:id" do
    let!(:league) { create(:league, name: "Old Name") }

    it "updates the league and returns 200" do
      patch "/api/v1/leagues/#{league.id}",
            params: { league: { name: "New Name" } }.to_json,
            headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["name"]).to eq("New Name")
      expect(league.reload.name).to eq("New Name")
    end

    it "returns 404 for unknown league" do
      patch "/api/v1/leagues/0",
            params: { league: { name: "x" } }.to_json,
            headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 422 for invalid data" do
      patch "/api/v1/leagues/#{league.id}",
            params: { league: { name: "" } }.to_json,
            headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "does not change rules via PATCH (ignored at strong params)" do
      league.update_column(:rules, { "max_participants" => 5 })
      patch "/api/v1/leagues/#{league.id}",
            params: { league: { name: league.name, rules: { "max_participants" => 99 } } }.to_json,
            headers: headers
      expect(response).to have_http_status(:ok)
      expect(league.reload.rules["max_participants"]).to eq(5)
    end

    it "does not change starting_capital via PATCH (ignored at strong params)" do
      original = league.starting_capital
      patch "/api/v1/leagues/#{league.id}",
            params: { league: { name: league.name, starting_capital: 999_999 } }.to_json,
            headers: headers
      expect(response).to have_http_status(:ok)
      expect(league.reload.starting_capital).to eq(original)
    end
  end

  # ─────────────────────────────────────────────────────────────
  # DELETE /api/v1/leagues/:id
  # ─────────────────────────────────────────────────────────────
  describe "DELETE /api/v1/leagues/:id" do
    let!(:league) { create(:league) }

    it "deletes the league and returns 200" do
      expect {
        delete "/api/v1/leagues/#{league.id}", headers: headers
      }.to change(League, :count).by(-1)
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["message"]).to eq("League deleted")
    end

    it "returns 404 for unknown league" do
      delete "/api/v1/leagues/0", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ─────────────────────────────────────────────────────────────
  # POST /api/v1/leagues/:league_id/memberships
  # ─────────────────────────────────────────────────────────────
  describe "POST /api/v1/leagues/:league_id/memberships" do
    let!(:league) do
      create(:league, starting_capital: 100_000).tap do |open_league|
        # Membership join tests assume a running league window by default.
        open_league.update!(
          start_date: 1.day.ago,
          end_date: 2.days.from_now
        )
      end
    end
    let!(:user)   { create(:user) }

    it "creates a membership and a portfolio while the league is running, returns 201" do
      expect {
        post "/api/v1/leagues/#{league.id}/memberships",
             params: { user_id: user.id }.to_json,
             headers: headers
      }.to change(LeagueMembership, :count).by(1)
          .and change(Portfolio, :count).by(1)
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["message"]).to eq("Joined league")
      expect(json["cash_balance"].to_f).to eq(100_000.0)
    end

    it "does not create a duplicate membership" do
      post "/api/v1/leagues/#{league.id}/memberships",
           params: { user_id: user.id }.to_json,
           headers: headers
      expect {
        post "/api/v1/leagues/#{league.id}/memberships",
             params: { user_id: user.id }.to_json,
             headers: headers
      }.not_to change(LeagueMembership, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 404 when user does not exist" do
      post "/api/v1/leagues/#{league.id}/memberships",
           params: { user_id: 0 }.to_json,
           headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when league does not exist" do
      post "/api/v1/leagues/0/memberships",
           params: { user_id: user.id }.to_json,
           headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "allows join when league is running" do
      running_league = create(
        :league,
        start_date: 2.days.ago,
        end_date: 3.days.from_now,
        starting_capital: 100_000
      )

      post "/api/v1/leagues/#{running_league.id}/memberships",
           params: { user_id: user.id }.to_json,
           headers: headers

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["message"]).to eq("Joined league")
    end

    it "allows join when league has not started yet" do
      scheduled_league = create(
        :league,
        start_date: 2.days.from_now,
        end_date: 5.days.from_now,
        starting_capital: 100_000
      )

      expect {
        post "/api/v1/leagues/#{scheduled_league.id}/memberships",
             params: { user_id: user.id }.to_json,
             headers: headers
      }.to change(LeagueMembership, :count).by(1)
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["message"]).to eq("Joined league")
    end

    it "rejects join when league has expired" do
      expired_league = create(:league, starting_capital: 100_000)
      # Update after create to model an already-finished league window.
      expired_league.update!(
        start_date: 3.days.ago,
        end_date: 1.day.ago
      )

      post "/api/v1/leagues/#{expired_league.id}/memberships",
           params: { user_id: user.id }.to_json,
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["errors"]).to include("League has expired")
    end
  end

  # ─────────────────────────────────────────────────────────────
  # DELETE /api/v1/leagues/:league_id/memberships/:user_id
  # ─────────────────────────────────────────────────────────────
  describe "DELETE /api/v1/leagues/:league_id/memberships/:user_id" do
    let!(:league)     { create(:league) }
    # Caller must match membership user (or be admin); signed-in user is current_user.
    let!(:membership) { create(:league_membership, user: current_user, league: league) }

    it "removes the membership and returns 200" do
      expect {
        delete "/api/v1/leagues/#{league.id}/memberships/#{current_user.id}", headers: headers
      }.to change(LeagueMembership, :count).by(-1)
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["message"]).to eq("Left league")
    end

    it "removes the portfolio for that league when leaving" do
      create(:portfolio, user: current_user, league: league)
      expect {
        delete "/api/v1/leagues/#{league.id}/memberships/#{current_user.id}", headers: headers
      }.to change(LeagueMembership, :count).by(-1)
        .and change(Portfolio, :count).by(-1)
      expect(response).to have_http_status(:ok)
    end

    it "returns 403 when trying to remove another user's membership" do
      other = create(:user)
      create(:league_membership, user: other, league: league)
      delete "/api/v1/leagues/#{league.id}/memberships/#{other.id}", headers: headers
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 404 when user is not a member" do
      other = create(:user)
      delete "/api/v1/leagues/#{league.id}/memberships/#{other.id}", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "blocks leaving after league start" do
      league.update!(start_date: 1.day.ago, end_date: 1.day.from_now)

      expect {
        delete "/api/v1/leagues/#{league.id}/memberships/#{current_user.id}", headers: headers
      }.not_to change(LeagueMembership, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["errors"]).to include("Cannot leave league after it has started")
    end

    it "returns 404 when league does not exist" do
      delete "/api/v1/leagues/0/memberships/#{current_user.id}", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    context "when signed in as admin" do
      let(:admin) { create(:user, role: "admin") }
      let(:member) { create(:user) }

      before do
        # Parent example group signs in `current_user`; admins need their own session for this case.
        sign_in admin
      end

      it "may remove another user's membership" do
        create(:league_membership, user: member, league: league)
        expect {
          delete "/api/v1/leagues/#{league.id}/memberships/#{member.id}", headers: headers
        }.to change(LeagueMembership, :count).by(-1)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ─────────────────────────────────────────────────────────────
  # GET /api/v1/leagues/:league_id/leaderboard
  # ─────────────────────────────────────────────────────────────
  describe "GET /api/v1/leagues/:league_id/leaderboard" do
    let!(:league) { create(:league, start_date: 1.day.ago, end_date: 1.day.from_now) }
    let!(:user1)  { create(:user, username: "alice") }
    let!(:user2)  { create(:user, username: "bob") }
    let!(:p1) { create(:portfolio, user: user1, league: league, total_value: 120_000) }
    let!(:p2) { create(:portfolio, user: user2, league: league, total_value: 95_000) }

    it "returns 200 with ranked standings" do
      get "/api/v1/leagues/#{league.id}/leaderboard", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["league_id"]).to eq(league.id)
      standings = json["standings"]
      expect(standings).to be_an(Array)
      expect(standings.first["rank"]).to eq(1)
      expect(standings.map { |s| s["name"] }).to include("alice", "bob")
    end

    it "returns standings in descending value order" do
      get "/api/v1/leagues/#{league.id}/leaderboard", headers: headers
      standings = JSON.parse(response.body)["standings"]
      values = standings.map { |s| s["value"] }
      expect(values).to eq(values.sort.reverse)
    end

    it "returns 404 for unknown league" do
      get "/api/v1/leagues/0/leaderboard", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
