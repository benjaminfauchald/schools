require 'rails_helper'

RSpec.describe 'SEO Regression Prevention', type: :request do
  # These tests document CURRENT SEO implementation
  # and will FAIL if someone removes working SEO features
  
  let!(:school) { create(:school, name: 'Test International School') }
  
  before do
    school.place.update!(
      lat: 13.7563,
      lng: 100.5018,
      formatted_address: '123 Test Road, Bangkok'
    )
  end

  describe 'Current Working SEO Features' do
    it 'has title tag on all pages' do
      # Homepage
      get '/?home_lat=13.7563&home_lng=100.5018'
      expect(response.body).to include('<title>')
      
      # School page
      get "/schools/#{school.id}"
      expect(response.body).to include('<title>')
    end

    it 'has viewport meta for mobile' do
      get '/?home_lat=13.7563&home_lng=100.5018'
      expect(response.body).to include('viewport')
    end

    it 'has proper HTTP status codes' do
      # Valid page returns 200
      get "/schools/#{school.id}"
      expect(response).to have_http_status(:success)
      
      # Invalid page returns 404
      get "/schools/99999999"
      expect(response).to have_http_status(:not_found)
    end

    it 'serves robots.txt' do
      get '/robots.txt'
      expect(response).to have_http_status(:success)
    end

    it 'has clean URLs without file extensions' do
      # Should work without .html
      get "/schools/#{school.id}"
      expect(response).to have_http_status(:success)
    end
  end

  describe 'SEO Features That SHOULD Be Added' do
    xit 'MISSING: meta description tags' do
      get '/?home_lat=13.7563&home_lng=100.5018'
      expect(response.body).to match(/<meta [^>]*name="description"/),
        'Add: <meta name="description" content="Find international schools near you...">'
    end

    xit 'MISSING: Open Graph tags for social media' do
      get "/schools/#{school.id}"
      expect(response.body).to match(/<meta [^>]*property="og:title"/),
        'Add Open Graph tags for better social sharing'
    end

    xit 'MISSING: structured data for rich snippets' do
      get "/schools/#{school.id}"
      expect(response.body).to match(/application\/ld\+json/),
        'Add JSON-LD structured data for Google rich snippets'
    end

    xit 'MISSING: canonical URLs' do
      get "/schools/#{school.id}"
      expect(response.body).to match(/<link [^>]*rel="canonical"/),
        'Add canonical URLs to prevent duplicate content issues'
    end

    xit 'MISSING: sitemap.xml' do
      get '/sitemap.xml'
      expect(response).to have_http_status(:success),
        'Generate sitemap.xml for better crawling'
    end

    xit 'MISSING: language attribute' do
      get '/?home_lat=13.7563&home_lng=100.5018'
      expect(response.body).to match(/<html[^>]*lang="/),
        'Add lang="en" to html tag'
    end

    xit 'MISSING: heading hierarchy' do
      get '/?home_lat=13.7563&home_lng=100.5018'
      
      h1_count = response.body.scan(/<h1/i).count
      expect(h1_count).to eq(1),
        'Should have exactly one H1 tag per page'
    end
  end

  describe 'Critical SEO Rules to Maintain' do
    it 'does not block search engines on content pages' do
      get "/schools/#{school.id}"
      
      # Should NOT have noindex on content
      expect(response.body).not_to include('noindex'),
        'WARNING: Content pages must not block search engines!'
    end

    it 'returns 404 for non-existent pages (not 500 or 200)' do
      get '/schools/99999999'
      
      expect(response.status).to eq(404),
        'CRITICAL: Must return 404 for missing pages, not #{response.status}'
    end

    it 'loads quickly enough for SEO' do
      start = Time.current
      get "/schools/#{school.id}"
      duration = Time.current - start
      
      expect(duration).to be < 5.0,
        'Page loads too slowly for good SEO (#{duration}s)'
    end
  end

  describe 'SEO Quick Wins' do
    # These are easy fixes that would improve SEO significantly
    
    it 'TIP: Add meta descriptions to all pages' do
      skip 'Quick win: Add unique meta descriptions to each page type'
    end

    it 'TIP: Add Open Graph tags for social sharing' do
      skip 'Quick win: Add OG tags - improves how links look on Facebook/Twitter'
    end

    it 'TIP: Add structured data for schools' do
      skip 'Quick win: Add School schema.org markup for rich snippets'
    end

    it 'TIP: Generate XML sitemap' do
      skip 'Quick win: Use sitemap_generator gem to create sitemap.xml'
    end

    it 'TIP: Add breadcrumbs for better navigation' do
      skip 'Quick win: Add breadcrumb navigation with schema markup'
    end
  end
end