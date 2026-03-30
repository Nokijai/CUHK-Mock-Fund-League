require "rails_helper"

RSpec.describe "Home dashboard", type: :request do
  describe "GET /" do
    it "returns success" do
      get root_path
      expect(response).to have_http_status(:ok)
    end

    it "renders terminal dashboard shell" do
      get root_path
      expect(response.body).to include("DASHBOARD")
      expect(response.body).to include("MOCK-FUND")
    end
  end
end
