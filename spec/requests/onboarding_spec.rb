require 'rails_helper'

RSpec.describe "Onboarding", type: :request do
  let(:user) { create(:user, confirmed_at: Time.current) }

  describe "GET /onboarding" do
    context "when not authenticated" do
      it "shows onboarding page without requiring login" do
        get onboarding_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Set Your Home Location")
      end
    end

    context "when authenticated" do
      before { sign_in_user(user) }

      it "displays onboarding page" do
        get onboarding_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Set Your Home Location")
      end

      it "shows location setup form" do
        get onboarding_path
        expect(response.body).to include("Enter your home address")
        expect(response.body).to include("location")
      end

      it "renders using application layout without duplicate HTML structure" do
        get onboarding_path
        # Should contain exactly one DOCTYPE (from application layout)
        expect(response.body.scan(/<!DOCTYPE html>/i).count).to eq(1)
        # Should contain exactly one opening html tag
        expect(response.body.scan(/<html[^>]*>/i).count).to eq(1)
        # Should contain the content
        expect(response.body).to include("Set Your Home Location")
      end

      it "works with Turbo navigation" do
        get onboarding_path
        expect(response).to have_http_status(:success)
        # Should have only one DOCTYPE and one HTML tag (no duplicates)
        expect(response.body.scan(/<!DOCTYPE html>/i).count).to eq(1)
        expect(response.body.scan(/<html[^>]*>/i).count).to eq(1)
        expect(response.body.scan(/<\/html>/i).count).to eq(1)
      end

      it "does not include location controller to prevent redirect loops" do
        get onboarding_path
        # Should NOT have the location controller that causes redirect loops
        expect(response.body).not_to include('data-controller="location"')
        # Should still have the onboarding content
        expect(response.body).to include("Set Your Home Location")
      end
    end
  end

  describe "POST /onboarding/complete" do
    context "with HTML request" do
      it "redirects to root with success message" do
        post onboarding_complete_path
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(flash[:notice]).to eq("Welcome! Your home location has been set.")
      end
    end

    context "with JSON request" do
      it "returns JSON success response" do
        post onboarding_complete_path, headers: { "Accept" => "application/json" }
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("success")
        expect(json["redirect_url"]).to eq(root_path)
      end
    end
  end
end
