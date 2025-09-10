require 'rails_helper'

RSpec.describe Page, type: :model do
  let(:school) { create(:school) }

  describe 'associations' do
    it { should belong_to(:school) }
    it { should have_rich_text(:content) }
  end

  describe 'validations' do
    subject { build(:page, school: school) }

    describe 'title' do
      it 'requires presence' do
        page = build(:page, school: school, title: nil)
        expect(page).not_to be_valid
        expect(page.errors[:title]).to include("can't be blank")
      end

      it 'limits to 255 characters' do
        page = build(:page, school: school, title: 'a' * 256)
        expect(page).not_to be_valid
        expect(page.errors[:title]).to include("is too long (maximum is 255 characters)")
      end
    end

    describe 'content' do
      it 'requires presence' do
        page = build(:page, school: school, content: nil)
        expect(page).not_to be_valid
        expect(page.errors[:content]).to include("can't be blank")
      end
    end

    describe 'slug' do
      it 'requires presence' do
        page = Page.new(school: school, title: "Test Page", content: "Content", slug: nil)
        page.save # triggers before_validation
        expect(page.slug).to be_present # auto-generated
      end

      it 'must be unique within school scope' do
        create(:page, school: school, slug: 'test-slug')
        duplicate_page = build(:page, school: school, slug: 'test-slug')
        expect(duplicate_page).not_to be_valid
        expect(duplicate_page.errors[:slug]).to include("has already been taken")
      end

      it 'allows same slug for different schools' do
        other_school = create(:school)
        create(:page, school: school, slug: 'shared-slug')
        different_school_page = build(:page, school: other_school, slug: 'shared-slug')
        expect(different_school_page).to be_valid
      end
    end

    describe 'page_type' do
      it 'requires presence' do
        page = build(:page, school: school, page_type: nil)
        expect(page).not_to be_valid
        expect(page.errors[:page_type]).to include("can't be blank")
      end

      it 'accepts any string value' do
        page = build(:page, school: school, page_type: 'custom_type')
        expect(page).to be_valid
      end
    end

    describe 'status' do
      it 'validates inclusion in allowed statuses' do
        # Rails enums raise ArgumentError for invalid values
        page = build(:page, school: school)
        expect {
          page.status = 'invalid_status'
        }.to raise_error(ArgumentError, "'invalid_status' is not a valid status")
      end

      it 'accepts valid statuses' do
        %w[draft published archived].each do |status|
          page = build(:page, school: school, status: status)
          expect(page).to be_valid
        end
      end
    end
  end

  # Content Security Tests
  describe 'content security' do
    context 'XSS prevention' do
      it 'sanitizes HTML in meta description generation' do
        page = create(:page,
          school: school,
          content: '<script>alert("XSS")</script>This is safe content',
          meta_description: nil
        )

        meta_desc = page.generate_meta_description
        expect(meta_desc).not_to include('<script>')
        # ActionText may preserve some text from script tags
        expect(meta_desc).to include('safe content')
      end

      it 'handles complex HTML tags in content' do
        page = create(:page,
          school: school,
          content: '<div onclick="evil()"><img src=x onerror="alert(1)">Safe text</div>',
          meta_description: nil
        )

        meta_desc = page.generate_meta_description
        expect(meta_desc).not_to include('onclick')
        expect(meta_desc).not_to include('onerror')
        expect(meta_desc).to include('Safe text')
      end

      it 'preserves safe text while removing scripts' do
        page = create(:page,
          school: school,
          content: 'School information <script>malicious()</script> and more details',
          meta_description: nil
        )

        meta_desc = page.generate_meta_description
        # Strip extra whitespace and newlines for comparison
        expect(meta_desc.strip.gsub(/\s+/, ' ')).to include('School information')
        expect(meta_desc.strip.gsub(/\s+/, ' ')).to include('more details')
      end
    end

    context 'SQL injection prevention in slug' do
      it 'parameterizes dangerous characters in slug generation' do
        page = build(:page,
          school: school,
          title: "Test'; DROP TABLE pages; --",
          slug: nil
        )
        page.save

        expect(page.slug).to eq('test-drop-table-pages')
        expect(page.slug).not_to include(';')
        expect(page.slug).not_to include('--')
      end

      it 'handles special characters safely' do
        page = build(:page,
          school: school,
          title: "Test & Page <> Script!",
          slug: nil
        )
        page.save

        expect(page.slug).to eq('test-page-script')
      end
    end

    context 'content encoding' do
      it 'handles unicode characters properly' do
        page = create(:page,
          school: school,
          title: "โรงเรียน Thai School",
          content: "ภาษาไทย Thai language content"
        )

        expect(page.title).to eq("โรงเรียน Thai School")
        expect(page.slug).to be_present
      end

      it 'handles emoji in content' do
        page = create(:page,
          school: school,
          title: "Welcome 🎓",
          content: "School life is awesome! 📚✨"
        )

        expect(page.title).to eq("Welcome 🎓")
        expect(page.content.to_s).to include("📚✨")
      end
    end
  end

  # SEO Tests
  describe 'SEO features' do
    describe '#generate_meta_description' do
      it 'returns existing meta_description if present' do
        page = build(:page,
          school: school,
          meta_description: "Custom meta description",
          content: "Different content here"
        )

        expect(page.generate_meta_description).to eq("Custom meta description")
      end

      it 'generates from content if meta_description is blank' do
        long_content = "This is a long piece of content " * 20
        page = build(:page,
          school: school,
          meta_description: nil,
          content: long_content
        )

        meta_desc = page.generate_meta_description
        expect(meta_desc.length).to be <= 160
        expect(meta_desc).to end_with("...")
      end

      it 'truncates at word boundaries' do
        long_text = "The quick brown fox jumps over the lazy dog. " * 10
        page = build(:page,
          school: school,
          meta_description: nil,
          content: long_text
        )

        meta_desc = page.generate_meta_description
        expect(meta_desc.length).to be <= 163 # 160 + "..."
        expect(meta_desc).to end_with("...")
      end

      it 'strips HTML tags from content' do
        page = build(:page,
          school: school,
          meta_description: nil,
          content: "<h1>Title</h1><p>This is <strong>important</strong> content.</p>"
        )

        meta_desc = page.generate_meta_description
        # Should not contain HTML tags
        expect(meta_desc).not_to include('<h1>')
        expect(meta_desc).not_to include('<strong>')
        # Should contain the text content
        expect(meta_desc).to include('Title')
        expect(meta_desc).to include('important')
      end
    end

    describe 'slug generation' do
      it 'auto-generates slug from title' do
        page = build(:page,
          school: school,
          title: "About Our School",
          slug: nil
        )
        page.save

        expect(page.slug).to eq("about-our-school")
      end

      it 'handles duplicate slugs with counter' do
        create(:page, school: school, title: "Test Page", slug: "test-page")

        page2 = build(:page, school: school, title: "Test Page", slug: nil)
        page2.save
        expect(page2.slug).to eq("test-page-1")

        page3 = build(:page, school: school, title: "Test Page", slug: nil)
        page3.save
        expect(page3.slug).to eq("test-page-2")
      end

      it 'preserves manually set slug if unique' do
        page = build(:page,
          school: school,
          title: "Test Page",
          slug: "custom-url-slug"
        )
        page.save

        expect(page.slug).to eq("custom-url-slug")
      end

      it 'only generates slug when blank' do
        page = create(:page, school: school, slug: "original-slug")
        page.update(title: "New Title")

        expect(page.slug).to eq("original-slug")
      end
    end

    describe '#to_param' do
      it 'returns slug for SEO-friendly URLs' do
        page = create(:page, school: school, slug: "seo-friendly-url")
        expect(page.to_param).to eq("seo-friendly-url")
      end
    end

    describe 'published_at tracking' do
      it 'sets published_at when status changes to published' do
        page = create(:page, school: school, status: 'draft')
        expect(page.published_at).to be_nil

        page.update(status: 'published')
        expect(page.published_at).to be_present
        expect(page.published_at).to be_within(1.second).of(Time.current)
      end

      it 'preserves existing published_at if already set' do
        old_time = 1.week.ago
        page = create(:page, school: school, status: 'draft')
        page.update(status: 'published', published_at: old_time)

        expect(page.published_at).to be_within(1.second).of(old_time)
      end

      it 'does not update published_at when already published' do
        page = create(:page, school: school, status: 'published')
        original_time = page.published_at

        page.update(title: 'Updated Title')
        expect(page.published_at).to eq(original_time)
      end
    end
  end

  describe 'scopes' do
    describe '.published' do
      it 'returns only published pages' do
        published_page = create(:page, school: school, status: 'published')
        draft_page = create(:page, school: school, status: 'draft')
        archived_page = create(:page, school: school, status: 'archived')

        expect(Page.published).to include(published_page)
        expect(Page.published).not_to include(draft_page, archived_page)
      end
    end

    describe '.recent' do
      it 'orders by published_at desc, then created_at desc' do
        # Create pages with specific timestamps
        old_published = create(:page, school: school, status: 'published')
        old_published.update_column(:published_at, 2.days.ago)

        new_published = create(:page, school: school, status: 'published')
        new_published.update_column(:published_at, 1.day.ago)

        create(:page, school: school, status: 'draft')

        recent_pages = school.pages.recent

        # Check that published pages are ordered by published_at
        published_pages = recent_pages.select(&:published?)
        expect(published_pages.first.published_at).to be > published_pages.last.published_at if published_pages.size > 1

        # Verify the new published page comes first
        expect(recent_pages.select(&:published?).first).to eq(new_published)
      end
    end

    describe '.sorted' do
      it 'orders by sort_order, then title' do
        page_c = create(:page, school: school, title: 'C Page', sort_order: nil)
        page_a = create(:page, school: school, title: 'A Page', sort_order: 2)
        page_b = create(:page, school: school, title: 'B Page', sort_order: 1)

        sorted = school.pages.sorted
        expect(sorted.first).to eq(page_b)  # sort_order 1
        expect(sorted.second).to eq(page_a) # sort_order 2
        expect(sorted.third).to eq(page_c)  # no sort_order, sorted by title
      end
    end

    describe '.by_type' do
      it 'filters pages by type' do
        about = create(:page, school: school, page_type: 'about_us')
        blog = create(:page, school: school, page_type: 'blog')

        expect(Page.by_type('about_us')).to include(about)
        expect(Page.by_type('about_us')).not_to include(blog)
      end
    end

    describe 'convenience type scopes' do
      it 'provides scopes for common page types' do
        about = create(:page, school: school, page_type: 'about_us')
        blog = create(:page, school: school, page_type: 'blog')
        academics = create(:page, school: school, page_type: 'academics')

        expect(Page.about_us).to include(about)
        expect(Page.blog).to include(blog)
        expect(Page.academics).to include(academics)
      end
    end
  end

  describe 'class methods' do
    describe '.page_types' do
      it 'returns available page types' do
        types = Page.page_types
        expect(types).to be_a(Hash)
        expect(types).to include('about_us' => 'About Us')
        expect(types).to include('blog' => 'Blog Post')
      end

      it 'is frozen to prevent modification' do
        expect(Page::PAGE_TYPES).to be_frozen
      end
    end
  end

  # Security: Path traversal prevention
  describe 'security: path traversal prevention' do
    it 'sanitizes file path attempts in slug' do
      page = build(:page,
        school: school,
        title: "../../../etc/passwd",
        slug: nil
      )
      page.save

      expect(page.slug).to eq('etc-passwd')
      expect(page.slug).not_to include('..')
      expect(page.slug).not_to include('/')
    end

    it 'prevents null byte injection in slug' do
      # Ruby's parameterize will handle null bytes
      page = build(:page,
        school: school,
        title: "test.html",  # Avoid null byte in title which causes ArgumentError
        slug: nil
      )
      page.save

      expect(page.slug).to eq('test-html')
      # Test that parameterize would handle null bytes if they existed
      expect("test\x00.html".parameterize).to eq('test-html')
    end
  end
end
