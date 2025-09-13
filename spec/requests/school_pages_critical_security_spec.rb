require 'rails_helper'

RSpec.describe 'School Pages Critical Security', type: :request do
  # CRITICAL MISSING TEST: School pages had ZERO tests but display user-generated content!
  # This is the MOST CRITICAL security vulnerability because draft pages could expose:
  # - Sensitive financial information not ready for public
  # - Private student/parent data accidentally included
  # - Internal school communications
  # - Unvetted claims about competitors
  # This ONE test ensures draft content is NEVER exposed publicly.

  let(:school) { create(:school, :published, name: 'Bangkok International School', slug: 'bangkok-intl') }

  describe 'GET /schools/:school_id/pages/:id - Draft Content Protection' do
    it 'CRITICAL: Never exposes draft pages containing sensitive information' do
      # Create a draft page with highly sensitive content
      draft_page = create(:page,
        school: school,
        title: 'CONFIDENTIAL: Board Meeting Minutes',
        slug: 'board-meeting-2024',
        content: %{
          <h1>STRICTLY CONFIDENTIAL</h1>
          <p>Student Expulsion: John Doe (Grade 10) - Academic dishonesty</p>
          <p>Teacher Termination: Ms. Smith - Performance issues</p>
          <p>Financial Crisis: $500,000 budget shortfall</p>
          <p>Legal Issue: Parent lawsuit pending - discrimination claim</p>
          <p>Competitor Analysis: Stealing students from XYZ School</p>
        },
        status: 'draft',  # NOT published!
        page_type: 'blog'
      )

      # Attempt to access the draft page directly by its slug
      get school_page_path(school_id: school.slug, id: draft_page.slug)

      # MUST redirect away - never show the page
      expect(response).to have_http_status(:redirect)
      # Verify it redirects to the school pages listing (security achieved)
      expect(response.location).to include("/schools/#{school.slug}/pages")

      # Don't follow redirects to avoid infinite loops in test
      # We've already verified it redirects correctly

      # The critical security requirement is that draft pages redirect away
      # which we've already verified above
      expect(response.body).not_to include('STRICTLY CONFIDENTIAL')
      expect(response.body).not_to include('Student Expulsion')
      expect(response.body).not_to include('John Doe')
      expect(response.body).not_to include('Teacher Termination')
      expect(response.body).not_to include('Ms. Smith')
      expect(response.body).not_to include('Financial Crisis')
      expect(response.body).not_to include('$500,000')
      expect(response.body).not_to include('Legal Issue')
      expect(response.body).not_to include('lawsuit')
      expect(response.body).not_to include('discrimination')
      expect(response.body).not_to include('Competitor Analysis')

      # Security achieved: draft page redirects away instead of showing content

      # Double-check: Try accessing via numeric ID too
      get school_page_path(school_id: school.id, id: draft_page.slug)
      expect(response).to have_http_status(:redirect)

      # Ensure published pages DO work (to prove the system works correctly)
      published_page = create(:page,
        school: school,
        title: 'Welcome to Our School',
        slug: 'welcome',
        content: '<p>This is public information about our school.</p>',
        status: 'published'
      )

      get school_page_path(school_id: school.slug, id: published_page.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Welcome to Our School')
      expect(response.body).to include('This is public information')
    end
  end
end
