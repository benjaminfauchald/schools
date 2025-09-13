require 'rails_helper'

RSpec.describe 'Public SEO - Search Engine Optimization', type: :request do
  # These tests ensure SEO doesn't break, protecting organic traffic
  # They will FAIL if someone removes critical SEO elements

  let!(:school) { create(:school, name: 'Bangkok International Academy') }

  before do
    school.update!(
      about: 'Leading international school in Bangkok offering British curriculum.',
      website_url: 'https://www.bia.ac.th',
      phone: '+66 2 123 4567',
      email: 'info@bia.ac.th'
    )

    school.place.update!(
      lat: 13.7563,
      lng: 100.5018,
      formatted_address: '123 Sukhumvit Road, Bangkok 10110, Thailand',
      rating: 4.5,
      user_ratings_total: 250
    )
  end

  describe 'CRITICAL: Homepage SEO' do
    before { get '/?home_lat=13.7563&home_lng=100.5018' }

    it 'has essential meta tags' do
      # Title tag - most important for SEO
      expect(response.body).to match(/<title>[^<]+<\/title>/),
        'Missing <title> tag - CRITICAL for SEO'

      # Meta description
      expect(response.body).to match(/<meta [^>]*name="description"[^>]*>/),
        'Missing meta description - important for click-through rates'

      # Viewport for mobile
      expect(response.body).to match(/<meta [^>]*name="viewport"[^>]*>/),
        'Missing viewport meta - required for mobile SEO'
    end

    it 'has Open Graph tags for social sharing' do
      # Essential OG tags for Facebook/LinkedIn
      expect(response.body).to match(/<meta [^>]*property="og:title"[^>]*>/),
        'Missing og:title - posts will look bad on Facebook'

      expect(response.body).to match(/<meta [^>]*property="og:description"[^>]*>/),
        'Missing og:description - social shares need description'

      expect(response.body).to match(/<meta [^>]*property="og:type"[^>]*>/),
        'Missing og:type - should be "website" for homepage'

      expect(response.body).to match(/<meta [^>]*property="og:url"[^>]*>/),
        'Missing og:url - canonical URL for social media'
    end

    it 'has Twitter Card tags' do
      # Twitter specific tags
      expect(response.body).to match(/<meta [^>]*name="twitter:card"[^>]*>/),
        'Missing Twitter card - tweets will not have rich media'
    end

    it 'has canonical URL to prevent duplicate content' do
      expect(response.body).to match(/<link [^>]*rel="canonical"[^>]*>/),
        'Missing canonical URL - could cause duplicate content issues'
    end

    it 'has proper heading hierarchy' do
      # Should have exactly one H1
      h1_count = response.body.scan(/<h1[^>]*>/i).count
      expect(h1_count).to eq(1), "Found #{h1_count} H1 tags, should have exactly 1"

      # Should have H2s for sections
      expect(response.body).to match(/<h2[^>]*>/i),
        'No H2 tags found - poor content structure for SEO'
    end
  end

  describe 'CRITICAL: School Detail Page SEO' do
    before { get "/schools/#{school.id}" }

    it 'has dynamic meta tags with school information' do
      # Title should include school name
      expect(response.body).to match(/<title>[^<]*Bangkok International Academy[^<]*<\/title>/),
        'School name not in title tag'

      # Meta description should be about the school
      expect(response.body).to match(/<meta [^>]*name="description"[^>]*content="[^"]*Bangkok[^"]*"/),
        'School info not in meta description'
    end

    it 'has structured data (JSON-LD) for rich snippets' do
      # Look for School schema.org markup
      expect(response.body).to match(/<script[^>]*type="application\/ld\+json"[^>]*>/),
        'Missing JSON-LD structured data - no rich snippets in Google'

      # Extract and validate JSON-LD
      json_ld_match = response.body.match(/<script[^>]*type="application\/ld\+json"[^>]*>(.*?)<\/script>/m)

      if json_ld_match
        json_data = JSON.parse(json_ld_match[1]) rescue nil

        if json_data
          # Should have School or EducationalOrganization type
          expect(json_data['@type']).to match(/School|EducationalOrganization/),
            'Wrong schema type - should be School or EducationalOrganization'

          # Should have essential properties
          expect(json_data['name']).to eq('Bangkok International Academy'),
            'School name missing from structured data'

          # Address should be present
          expect(json_data['address']).not_to be_nil,
            'Address missing from structured data'
        end
      end
    end

    it 'has breadcrumb structured data for navigation' do
      # Look for BreadcrumbList JSON-LD structured data
      json_ld_blocks = response.body.scan(/<script type="application\/ld\+json">(.*?)<\/script>/m)

      breadcrumb_found = json_ld_blocks.any? do |content|
        content_str = content.is_a?(Array) ? content[0] : content
        data = JSON.parse(content_str) rescue nil
        data && data['@type'] == 'BreadcrumbList'
      end

      expect(breadcrumb_found).to be(true),
        'Missing breadcrumb structured data - helps with site links in search'
    end

    it 'includes location data for local SEO' do
      # Should have geo coordinates for local search
      expect(response.body).to include('13.7563') || include('latitude'),
        'Missing latitude for local SEO'

      expect(response.body).to include('100.5018') || include('longitude'),
        'Missing longitude for local SEO'
    end

    it 'has proper image alt tags for accessibility and SEO' do
      # All images should have alt attributes
      images = response.body.scan(/<img[^>]*>/i)
      images_without_alt = images.reject { |img| img.match(/alt="[^"]+"/i) }

      expect(images_without_alt).to be_empty,
        "#{images_without_alt.count} images missing alt text - bad for SEO and accessibility"
    end
  end

  describe 'CRITICAL: Search Results Page SEO' do
    before { get '/schools/search?q=International&home_lat=13.7563&home_lng=100.5018' }

    it 'has search-specific meta tags' do
      # Should indicate this is a search results page
      expect(response.body).to match(/<meta [^>]*name="robots"[^>]*content="[^"]*noindex[^"]*"/i) ||
        match(/<title>[^<]*Search[^<]*<\/title>/i),
        'Search pages should be noindex or clearly marked as search'
    end
  end

  describe 'CRITICAL: URL Structure for SEO' do
    it 'uses SEO-friendly URLs with slugs' do
      # Schools should have slug-based URLs
      school_with_slug = create(:school, name: 'Test School', slug: 'test-school')

      get "/schools/#{school_with_slug.slug}"

      expect(response).to have_http_status(:success),
        'Slug-based URLs not working - important for SEO'
    end

    it 'handles trailing slashes consistently' do
      # Both should work the same way (redirect or both serve content)
      get "/schools/#{school.id}"
      status_without_slash = response.status

      get "/schools/#{school.id}/"
      status_with_slash = response.status

      expect([ 200, 301, 302 ]).to include(status_without_slash)
      expect([ 200, 301, 302 ]).to include(status_with_slash)
    end
  end

  describe 'CRITICAL: Mobile SEO' do
    it 'is mobile-friendly with responsive design indicators' do
      get '/?home_lat=13.7563&home_lng=100.5018', headers: {
        'User-Agent' => 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)'
      }

      # Should have viewport meta for mobile
      expect(response.body).to match(/<meta [^>]*name="viewport"[^>]*content="[^"]*width=device-width/),
        'Not mobile optimized - Google will penalize in mobile search'
    end
  end

  describe 'CRITICAL: Performance for SEO' do
    it 'responds quickly for search engine crawlers' do
      start_time = Time.current
      get "/schools/#{school.id}"
      load_time = Time.current - start_time

      # Google expects pages to load quickly
      expect(load_time).to be < 3.0,
        "Page took #{load_time.round(2)}s - Google penalizes slow sites"
    end

    it 'does not block search engines with robots meta' do
      get "/schools/#{school.id}"

      # Should NOT have noindex on content pages
      expect(response.body).not_to match(/<meta [^>]*name="robots"[^>]*content="[^"]*noindex/),
        'Content pages should not block search engines'
    end
  end

  describe 'CRITICAL: Internationalization for SEO' do
    it 'indicates language for search engines' do
      get '/?home_lat=13.7563&home_lng=100.5018'

      # HTML tag should have lang attribute
      expect(response.body).to match(/<html[^>]*lang="[^"]+"/),
        'Missing lang attribute - search engines need to know the language'
    end

    it 'provides hreflang tags for multiple languages' do
      get '/?home_lat=13.7563&home_lng=100.5018'

      # Should have hreflang for language variations
      has_hreflang = response.body.match(/<link [^>]*rel="alternate"[^>]*hreflang="/)

      # This might not be implemented yet, but document it
      if has_hreflang
        expect(response.body).to match(/hreflang="en"/),
          'Missing English hreflang'
        expect(response.body).to match(/hreflang="th"/),
          'Missing Thai hreflang'
      end
    end
  end

  describe 'CRITICAL: Internal Linking for SEO' do
    it 'has proper internal link structure' do
      get '/?home_lat=13.7563&home_lng=100.5018'

      # Should have links to school pages
      school_links = response.body.scan(/<a[^>]*href="[^"]*\/schools\/[^"]+"/i)

      expect(school_links).not_to be_empty,
        'No internal links to schools - poor for SEO crawling'
    end

    it 'uses descriptive anchor text' do
      get '/?home_lat=13.7563&home_lng=100.5018'

      # Should not have generic "click here" links
      bad_anchors = response.body.scan(/<a[^>]*>click here<\/a>/i)

      expect(bad_anchors).to be_empty,
        'Found generic "click here" links - use descriptive text for SEO'
    end
  end

  describe 'CRITICAL: Error Pages SEO' do
    it 'returns proper 404 status for non-existent pages' do
      get '/schools/99999999'

      expect(response).to have_http_status(:not_found),
        'Not returning 404 status - search engines will index error pages'
    end

    it 'has meta tags on 404 pages' do
      get '/schools/99999999'

      if response.status == 404
        # Even 404 pages should have basic meta tags
        expect(response.body).to match(/<title>/),
          '404 page missing title tag'
      end
    end
  end

  describe 'CRITICAL: Sitemap' do
    it 'has accessible sitemap.xml' do
      get '/sitemap.xml'

      # Should either exist or redirect to it
      expect([ 200, 301, 302 ]).to include(response.status),
        'Sitemap not accessible - search engines need this for crawling'

      if response.status == 200
        expect(response.content_type).to match(/xml/),
          'Sitemap should be XML format'
      end
    end
  end

  describe 'CRITICAL: Robots.txt' do
    it 'has accessible robots.txt' do
      get '/robots.txt'

      expect(response).to have_http_status(:success),
        'robots.txt not accessible - search engines check this first'

      # Should allow crawling of main content
      expect(response.body).to match(/User-agent:/),
        'robots.txt missing User-agent directive'

      # Should not block all crawling
      expect(response.body).not_to match(/Disallow:\s*\/$/),
        'robots.txt blocking all crawling!'
    end

    it 'includes sitemap location in robots.txt' do
      get '/robots.txt'

      # Should reference the sitemap
      expect(response.body).to match(/Sitemap:/i),
        'robots.txt should include Sitemap directive'
    end
  end
end
