require "rails_helper"

RSpec.describe "Api::V1::Leagues", type: :request do
  let(:headers) { { "Content-Type" => "application/json", "Accept" => "application/json" } }

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
          start_date:       "2026-04-01",
          end_date:         "2026-06-30"
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
  # POST /api/v1/leagues/:id/join
  # ─────────────────────────────────────────────────────────────
  describe "POST /api/v1/leagues/:id/join" do
    let!(:league) { create(:league, starting_capital: 100_000) }
    let!(:user)   { create(:user) }

    it "creates a membership and a portfolio, returns 201" do
      expect {
        post "/api/v1/leagues/#{league.id}/join",
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
      post "/api/v1/leagues/#{league.id}/join",
           params: { user_id: user.id }.to_json,
           headers: headers
      expect {
        post "/api/v1/leagues/#{league.id}/join",
             params: { user_id: user.id }.to_json,
             headers: headers
      }.not_to change(LeagueMembership, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 404 when user does not exist" do
      post "/api/v1/leagues/#{league.id}/join",
           params: { user_id: 0 }.to_json,
           headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when league does not exist" do
      post "/api/v1/leagues/0/join",
           params: { user_id: user.id }.to_json,
           headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ─────────────────────────────────────────────────────────────
  # DELETE /api/v1/leagues/:id/leave
  # ─────────────────────────────────────────────────────────────
  describe "DELETE /api/v1/leagues/:id/leave" do
    let!(:league)     { create(:league) }
    let!(:user)       { create(:user) }
    let!(:membership) { create(:league_membership, user: user, league: league) }

    it "removes the membership and returns 200" do
      expect {
        delete "/api/v1/leagues/#{league.id}/leave",
               params: { user_id: user.id }.to_json,
               headers: headers
      }.to change(LeagueMembership, :count).by(-1)
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["message"]).to eq("Left league")
    end

    it "returns 404 when user is not a member" do
      other = create(:user)
      delete "/api/v1/leagues/#{league.id}/leave",
             params: { user_id: other.id }.to_json,
             headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 when league does not exist" do
      delete "/api/v1/leagues/0/leave",
             params: { user_id: user.id }.to_json,
             headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ─────────────────────────────────────────────────────────────
  # GET /api/v1/leagues/:id/leaderboard
  # ─────────────────────────────────────────────────────────────
  describe "GET /api/v1/leagues/:id/leaderboard" do
    let!(:league) { create(:league) }
    let!(:user1)  { create(:user, name: "Alice") }
    let!(:user2)  { create(:user, name: "Bob") }
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
      expect(standings.map { |s| s["name"] }).to include("Alice", "Bob")
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
