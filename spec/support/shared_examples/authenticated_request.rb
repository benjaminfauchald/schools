RSpec.shared_examples "requires authentication" do
  context "without authentication" do
    it "redirects to login page" do
      make_request
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end

RSpec.shared_examples "requires admin authentication" do
  context "without authentication" do
    it "redirects to admin login" do
      make_request
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(new_admin_user_session_path)
    end
  end

  context "with non-admin user" do
    let(:user) { create(:user) }
    
    before { sign_in user }
    
    it "returns forbidden" do
      make_request
      expect(response).to have_http_status(:forbidden)
    end
  end
end

RSpec.shared_examples "requires school ownership" do
  context "with different school owner" do
    let(:other_user) { create(:user, :school_owner) }
    let(:other_school) { create(:school) }
    
    before do
      create(:school_claim, user: other_user, school: other_school, status: 'approved')
      sign_in other_user
    end
    
    it "returns forbidden" do
      make_request
      expect(response).to have_http_status(:forbidden)
    end
  end
end

RSpec.shared_examples "API endpoint" do
  it "returns JSON content type" do
    make_request
    expect(response.content_type).to match(/json/)
  end
end

RSpec.shared_examples "paginated response" do
  it "includes pagination metadata" do
    make_request
    expect(json_response).to include('data', 'meta')
    expect(json_response['meta']).to include('current_page', 'total_pages', 'total_count')
  end
end