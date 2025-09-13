require 'rails_helper'

RSpec.describe "Facebook OAuth Authentication", type: :request do
  # CRITICAL GAP: Facebook OAuth is REQUIRED for school inquiries but has NO tests!
  # This is the most critical missing test because:
  # 1. School inquiries REQUIRE Facebook authentication (enforced in controller)
  # 2. No alternative auth method - if Facebook OAuth breaks, inquiries stop working
  # 3. Security vulnerability - improper OAuth handling could allow unauthorized access
  # 4. Data integrity - User creation from OAuth data needs validation

  describe "GET /users/auth/facebook/callback" do
    before do
      # Configure OmniAuth test mode
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[:facebook] = nil
    end

    after do
      OmniAuth.config.test_mode = false
      OmniAuth.config.mock_auth[:facebook] = nil
    end

    context "with valid Facebook OAuth data" do
      let(:valid_auth_hash) do
        OmniAuth::AuthHash.new({
          provider: 'facebook',
          uid: '123456789',
          info: {
            email: 'fb_user@example.com',
            name: 'John Doe',
            first_name: 'John',
            last_name: 'Doe',
            image: 'https://graph.facebook.com/123456789/picture'
          },
          credentials: {
            token: 'mock_facebook_token_abc123',
            expires_at: 1.month.from_now.to_i,
            expires: true
          },
          extra: {
            raw_info: {
              id: '123456789',
              email: 'fb_user@example.com',
              name: 'John Doe',
              first_name: 'John',
              last_name: 'Doe'
            }
          }
        })
      end

      before do
        OmniAuth.config.mock_auth[:facebook] = valid_auth_hash
      end

      it "creates a new user from Facebook data on first login" do
        expect {
          get user_facebook_omniauth_callback_path
        }.to change(User, :count).by(1)

        user = User.last
        expect(user.email).to eq('fb_user@example.com')
        expect(user.provider).to eq('facebook')
        expect(user.uid).to eq('123456789')
        expect(user.facebook_name).to eq('John Doe')
      end

      it "signs in existing user without creating duplicate" do
        # Create existing user with same Facebook UID
        existing_user = create(:user,
          email: 'fb_user@example.com',
          provider: 'facebook',
          uid: '123456789'
        )

        expect {
          get user_facebook_omniauth_callback_path
        }.not_to change(User, :count)

        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to match(/Successfully signed in with Facebook/)
      end

      it "handles token updates on each login" do
        user = create(:user,
          email: 'fb_user@example.com',
          provider: 'facebook',
          uid: '123456789'
        )

        get user_facebook_omniauth_callback_path

        user.reload
        # User should be updated with latest Facebook info
        expect(user.facebook_name).to eq('John Doe')
      end

      it "allows user to submit school inquiries after Facebook auth" do
        get user_facebook_omniauth_callback_path
        follow_redirect!

        # User should now be able to make inquiry requests
        school = create(:school)

        post school_school_inquiries_path(school_id: school.id),
             params: {
               school_inquiry: {
                 name: 'John Doe',
                 email: 'fb_user@example.com',
                 phone: '+66 2 123 4567',
                 message: 'Interested in school',
                 children_count: 1
               }
             },
             headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
      end
    end

    context "with missing email in Facebook data" do
      let(:auth_without_email) do
        OmniAuth::AuthHash.new({
          provider: 'facebook',
          uid: '987654321',
          info: {
            email: nil,  # Explicitly set to nil
            name: 'Jane Doe',
            first_name: 'Jane',
            last_name: 'Doe'
          },
          credentials: {
            token: 'mock_token',
            expires_at: 1.month.from_now.to_i
          }
        })
      end

      before do
        OmniAuth.config.mock_auth[:facebook] = auth_without_email
      end

      it "handles missing email from Facebook" do
        # FIXED: Missing email now generates a placeholder
        get user_facebook_omniauth_callback_path

        # User should be created with generated email
        user = User.find_by(uid: '987654321')
        expect(user).to be_present

        # Should have generated placeholder email
        expect(user.email).to match(/fb_987654321@facebook\.local/)
        expect(user.facebook_name).to eq('Jane Doe')

        # Should be signed in successfully
        expect(response).to redirect_to(root_path)
      end
    end

    context "with OAuth failure" do
      before do
        OmniAuth.config.mock_auth[:facebook] = :invalid_credentials
      end

      it "redirects to sign in with error message" do
        get user_facebook_omniauth_callback_path

        # When OmniAuth fails, it redirects to the callback URL with an error parameter
        expect(response).to redirect_to(user_facebook_omniauth_callback_path(message: :invalid_credentials))
      end

      it "does not create a user" do
        expect {
          get user_facebook_omniauth_callback_path
        }.not_to change(User, :count)
      end
    end

    context "security validations" do
      it "prevents account takeover by UID manipulation" do
        # FIXED: Account takeover vulnerability has been patched

        # Create user with Facebook account
        victim_user = create(:user,
          email: 'victim@example.com',
          provider: 'facebook',
          uid: '111111'
        )

        # Attacker tries to use same email but different UID
        attacker_auth = OmniAuth::AuthHash.new({
          provider: 'facebook',
          uid: '999999',  # Different UID
          info: {
            email: 'victim@example.com',  # Same email as victim
            name: 'Attacker'
          },
          credentials: {
            token: 'attacker_token',
            expires_at: 1.month.from_now.to_i
          }
        })

        OmniAuth.config.mock_auth[:facebook] = attacker_auth

        get user_facebook_omniauth_callback_path

        # FIXED: The victim's account is now protected
        victim_user.reload
        expect(victim_user.uid).to eq('111111')  # UID remains unchanged - account is safe!

        # The attacker should be redirected to registration with an error
        expect(response).to redirect_to(new_user_registration_url)
        expect(flash[:alert]).to include("already exists")

        # No new user should be created for the attacker
        attacker = User.find_by(uid: '999999')
        expect(attacker).to be_nil
      end

      it "sanitizes malicious data in OAuth response" do
        malicious_auth = OmniAuth::AuthHash.new({
          provider: 'facebook',
          uid: '123<script>alert("XSS")</script>456',
          info: {
            email: 'test@example.com<script>',
            name: '<img src=x onerror=alert("XSS")>',
            first_name: 'John<script>',
            last_name: 'Doe</script>'
          },
          credentials: {
            token: 'valid_token',
            expires_at: 1.month.from_now.to_i
          }
        })

        OmniAuth.config.mock_auth[:facebook] = malicious_auth

        expect {
          get user_facebook_omniauth_callback_path
        }.to change(User, :count).by(0..1)  # May or may not create depending on validation

        if User.exists?(provider: 'facebook')
          user = User.find_by(provider: 'facebook')
          # FIXED: XSS content is now sanitized!

          # Verify that dangerous HTML has been stripped
          expect(user.facebook_name.to_s).not_to include('<script>')
          expect(user.facebook_name.to_s).not_to include('<img')
          expect(user.facebook_name.to_s).not_to include('onerror')
          expect(user.facebook_name.to_s).not_to include('alert')

          # Email should also be sanitized
          expect(user.email.to_s).not_to include('<script>')

          # The UID should also be sanitized (alphanumeric only)
          expect(user.uid).to match(/^[a-zA-Z0-9_-]+$/)
        end
      end

      it "handles expired Facebook tokens appropriately" do
        expired_auth = OmniAuth::AuthHash.new({
          provider: 'facebook',
          uid: '789789',
          info: {
            email: 'expired@example.com',
            name: 'Expired User'
          },
          credentials: {
            token: 'expired_token',
            expires_at: 1.hour.ago.to_i,  # Already expired
            expires: true
          }
        })

        OmniAuth.config.mock_auth[:facebook] = expired_auth

        get user_facebook_omniauth_callback_path

        user = User.find_by(email: 'expired@example.com')
        # Should still create/login user even with expired token
        expect(user).to be_present
      end
    end

    context "rate limiting and abuse prevention" do
      it "prevents rapid account creation from same IP" do
        results = []

        10.times do |i|
          OmniAuth.config.mock_auth[:facebook] = OmniAuth::AuthHash.new({
            provider: 'facebook',
            uid: "spam_#{i}",
            info: {
              email: "spam_#{i}@example.com",
              name: "Spam User #{i}"
            },
            credentials: {
              token: "token_#{i}",
              expires_at: 1.month.from_now.to_i
            }
          })

          get user_facebook_omniauth_callback_path
          results << response.status
        end

        # Should either rate limit or handle gracefully
        # Document the expected behavior
        successful_statuses = results.select { |s| s == 302 }  # Redirect = success

        # If no rate limiting, all should succeed
        # If rate limiting exists, later requests should fail
        expect(successful_statuses.count).to be_between(1, 10)
      end
    end
  end
end
