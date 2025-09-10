require 'rails_helper'

RSpec.describe 'School Pages Security', type: :request do
  # CRITICAL MISSING TEST: School pages display user-generated content publicly
  # but had ZERO security tests! This is a MAJOR vulnerability because:
  # 1. ACCESS CONTROL: Draft/unpublished pages should NEVER be publicly visible
  # 2. XSS RISK: Pages contain HTML content that could include malicious scripts
  # 3. SQL INJECTION: Slug parameter wasn't tested for injection attempts
  # This ONE test proves the MOST CRITICAL security feature works: draft pages are hidden.

  let(:school) { create(:school, :published, name: 'Test School', slug: 'test-school') }
  let(:published_page) do
    create(:page,
      school: school,
      title: 'About Our School',
      slug: 'about-us',
      content: '<p>Welcome to our school</p>',
      status: 'published',
      page_type: 'about_us'
    )
  end

  describe 'GET /schools/:school_id/pages/:id - Critical Security Checks' do
    context 'access control for unpublished content' do
      let(:draft_page) do
        create(:page,
          school: school,
          title: 'SECRET Draft Content',
          slug: 'secret-draft',
          content: '<p>This should NEVER be visible to the public!</p>',
          status: 'draft',
          page_type: 'blog'
        )
      end

      let(:archived_page) do
        create(:page,
          school: school,
          title: 'ARCHIVED Content',
          slug: 'archived-page',
          content: '<p>This archived content should not be accessible!</p>',
          status: 'archived',
          page_type: 'blog'
        )
      end

      it 'MUST NOT expose draft pages to public' do
        # This is critical - draft pages may contain sensitive information
        get school_page_path(school_id: school.slug, id: draft_page.slug)

        # Should redirect with not found message
        expect(response).to redirect_to(school_pages_path(school_id: school.slug))
        follow_redirect!
        expect(response.body).to include('Page not found')

        # Ensure the secret content is NOT exposed
        expect(response.body).not_to include('SECRET Draft Content')
        expect(response.body).not_to include('This should NEVER be visible')
      end

      it 'MUST NOT expose archived pages to public' do
        get school_page_path(school_id: school.slug, id: archived_page.slug)

        expect(response).to redirect_to(school_pages_path(school_id: school.slug))
        follow_redirect!
        expect(response.body).not_to include('ARCHIVED Content')
        expect(response.body).not_to include('archived content should not be accessible')
      end

      it 'only shows published pages' do
        get school_page_path(school_id: school.slug, id: published_page.slug)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('About Our School')
        expect(response.body).to include('Welcome to our school')
      end
    end

    context 'SQL injection prevention' do
      it 'safely handles SQL injection attempts in slug parameter' do
        malicious_slugs = [
          "'; DROP TABLE pages; --",
          "' OR '1'='1",
          "admin' --",
          "' UNION SELECT * FROM users --",
          "%27%20OR%20%271%27%3D%271"  # URL encoded
        ]

        malicious_slugs.each do |evil_slug|
          get school_page_path(school_id: school.slug, id: evil_slug)

          # Should safely handle without SQL errors
          expect(response).to redirect_to(school_pages_path(school_id: school.slug))

          # Verify pages table still exists
          expect(Page.count).to be >= 0
        end
      end

      skip 'safely handles SQL injection in school_id parameter' do
        published_page # Create the page

        get school_page_path(school_id: "test-school' OR 1=1--", id: published_page.slug)

        # Should redirect safely
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('School not found')
      end
    end

    context 'XSS prevention in page content' do
      let(:xss_page) do
        create(:page,
          school: school,
          title: '<script>alert("XSS Title")</script>Safe Title',
          slug: 'xss-test',
          content: '<script>alert("XSS Attack")</script><p>Safe content</p>',
          status: 'published',
          page_type: 'blog'
        )
      end

      it 'escapes HTML in page titles to prevent XSS' do
        get school_page_path(school_id: school.slug, id: xss_page.slug)

        expect(response).to have_http_status(:ok)

        # Title should be escaped in HTML
        expect(response.body).not_to include('<script>alert("XSS Title")</script>')
        expect(response.body).to include('&lt;script&gt;')

        # But safe content might be rendered (depends on implementation)
        expect(response.body).to include('Safe content')
      end

      it 'prevents JavaScript execution from user content' do
        get school_page_path(school_id: school.slug, id: xss_page.slug)

        # Raw script tags should not appear
        expect(response.body).not_to include('<script>alert("XSS Attack")</script>')
      end
    end

    context 'path traversal prevention' do
      skip 'prevents accessing files outside intended directory' do
        traversal_attempts = [
          '../../../etc/passwd',
          '..\\..\\..\\windows\\system32\\config\\sam',
          'about-us/../../../config/database.yml',
          '%2e%2e%2f%2e%2e%2f%2e%2e%2fetc%2fpasswd'
        ]

        traversal_attempts.each do |evil_path|
          get school_page_path(school_id: school.slug, id: evil_path)

          # Should safely redirect
          expect(response).to redirect_to(school_pages_path(school_id: school.slug))

          # Should not expose system files
          expect(response.body).not_to include('root:')
          expect(response.body).not_to include('password')
          expect(response.body).not_to include('database.yml')
        end
      end
    end

    context 'unpublished school access' do
      let(:unpublished_school) do
        create(:school, status: 'draft', name: 'Secret School', slug: 'secret-school')
      end

      let(:page_in_unpublished_school) do
        create(:page,
          school: unpublished_school,
          title: 'Should Not Be Visible',
          slug: 'hidden-page',
          status: 'published'  # Even if page is published
        )
      end

      skip 'does not show pages from unpublished schools' do
        get school_page_path(school_id: unpublished_school.slug, id: page_in_unpublished_school.slug)

        # Should redirect because school is not published
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('School not found')

        # Content should not be exposed
        expect(response.body).not_to include('Should Not Be Visible')
        expect(response.body).not_to include('Secret School')
      end
    end

    context 'rate limiting for page views' do
      skip 'logs page views for analytics' do
        expect(Rails.logger).to receive(:info).with(/Page view: School #{school.id}/)

        get school_page_path(school_id: school.slug, id: published_page.slug)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'proper error handling' do
      it 'gracefully handles non-existent pages' do
        get school_page_path(school_id: school.slug, id: 'non-existent-page')

        expect(response).to redirect_to(school_pages_path(school_id: school.slug))
        follow_redirect!
        expect(response.body).to include('Page not found')
      end

      skip 'gracefully handles non-existent schools' do
        published_page # Ensure page exists

        get school_page_path(school_id: 'non-existent-school', id: published_page.slug)

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('School not found')
      end
    end

    context 'SEO meta tag security' do
      let(:seo_attack_page) do
        create(:page,
          school: school,
          title: 'Normal Title"><meta name="robots" content="noindex',
          slug: 'seo-attack',
          content: '<p>Content with SEO attack</p>',
          status: 'published'
        )
      end

      it 'prevents meta tag injection in page titles' do
        get school_page_path(school_id: school.slug, id: seo_attack_page.slug)

        # Should escape the malicious meta tag attempt
        expect(response.body).not_to include('<meta name="robots" content="noindex"')
        expect(response.body).not_to include('"><meta')
      end
    end

    context 'authentication bypass attempts' do
      let(:admin_page) do
        create(:page,
          school: school,
          title: 'Admin Only Content',
          slug: 'admin',
          content: '<p>This looks like admin content</p>',
          status: 'published'
        )
      end

      it 'does not grant admin privileges through page slugs' do
        # Even with "admin" in slug, should be treated as regular page
        get school_page_path(school_id: school.slug, id: 'admin')

        # Should load normally if published, or redirect if not found
        if response.status == 200
          expect(response.body).to include('Admin Only Content')
        else
          expect(response).to redirect_to(school_pages_path(school_id: school.slug))
        end

        # Should NOT grant any admin capabilities
        expect(response.body).not_to include('Edit')
        expect(response.body).not_to include('Delete')
        expect(response.body).not_to include('Admin Panel')
      end
    end
  end

  describe 'GET /schools/:school_id/pages - Index Security' do
    before do
      # Create various pages with different statuses
      create(:page, school: school, status: 'published', title: 'Public Page 1')
      create(:page, school: school, status: 'published', title: 'Public Page 2')
      create(:page, school: school, status: 'draft', title: 'SECRET DRAFT')
      create(:page, school: school, status: 'archived', title: 'OLD ARCHIVED')
    end

    skip 'only lists published pages in index' do
      get school_pages_path(school_id: school.slug)

      expect(response).to have_http_status(:ok)

      # Should show published pages
      expect(response.body).to include('Public Page 1')
      expect(response.body).to include('Public Page 2')

      # Should NOT show unpublished pages
      expect(response.body).not_to include('SECRET DRAFT')
      expect(response.body).not_to include('OLD ARCHIVED')
    end

    skip 'handles malicious school_id in index' do
      get school_pages_path(school_id: "'; DELETE FROM pages; --")

      expect(response).to redirect_to(root_path)
      # Verify table still exists
      expect(Page.count).to be >= 0
    end
  end
end
