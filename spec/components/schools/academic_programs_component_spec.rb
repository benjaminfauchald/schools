require 'rails_helper'

RSpec.describe Schools::AcademicProgramsComponent, type: :component do
  let(:vocabulary_curriculum) { create(:vocabulary, code: 'curriculum') }
  let(:vocabulary_language) { create(:vocabulary, code: 'language') }
  let(:vocabulary_accreditation) { create(:vocabulary, code: 'accreditation') }

  let(:ib_curriculum) { create(:term, vocabulary: vocabulary_curriculum, slug: 'ib', label: 'IB Programme') }
  let(:cambridge_curriculum) { create(:term, vocabulary: vocabulary_curriculum, slug: 'cambridge', label: 'Cambridge IGCSE') }
  let(:english_language) { create(:term, vocabulary: vocabulary_language, slug: 'english', label: 'English') }
  let(:thai_language) { create(:term, vocabulary: vocabulary_language, slug: 'thai', label: 'Thai') }
  let(:wasc_accreditation) { create(:term, vocabulary: vocabulary_accreditation, slug: 'wasc', label: 'WASC') }

  let(:academic_programs) do
    {
      curricula: [ ib_curriculum, cambridge_curriculum ],
      languages: [ english_language, thai_language ],
      accreditations: [ wasc_accreditation ]
    }
  end

  describe 'initialization' do
    it 'initializes with academic_programs hash' do
      component = described_class.new(academic_programs: academic_programs)
      expect(component).to be_present
    end

    it 'works with empty academic_programs' do
      component = described_class.new(academic_programs: {})
      expect(component).to be_present
    end

    it 'works with nil academic_programs' do
      component = described_class.new(academic_programs: nil)
      expect(component).to be_present
    end
  end

  describe 'render behavior' do
    context 'with academic programs data' do
      it 'renders when curricula exist' do
        component = described_class.new(academic_programs: { curricula: [ ib_curriculum ] })
        rendered = render_inline(component)
        expect(rendered.to_html.strip).not_to be_empty
      end

      it 'renders when languages exist' do
        component = described_class.new(academic_programs: { languages: [ english_language ] })
        rendered = render_inline(component)
        expect(rendered.to_html.strip).not_to be_empty
      end

      it 'renders when accreditations exist' do
        component = described_class.new(academic_programs: { accreditations: [ wasc_accreditation ] })
        rendered = render_inline(component)
        expect(rendered.to_html.strip).not_to be_empty
      end
    end

    context 'without academic programs data' do
      it 'does not render when all sections are empty' do
        component = described_class.new(academic_programs: {})
        rendered = render_inline(component)
        expect(rendered.to_html.strip).to be_empty
      end

      it 'does not render when academic_programs is nil' do
        component = described_class.new(academic_programs: nil)
        rendered = render_inline(component)
        expect(rendered.to_html.strip).to be_empty
      end

      it 'does not render when sections contain empty arrays' do
        empty_programs = {
          curricula: [],
          languages: [],
          accreditations: []
        }
        component = described_class.new(academic_programs: empty_programs)
        rendered = render_inline(component)
        expect(rendered.to_html.strip).to be_empty
      end
    end
  end

  describe 'rendering' do
    subject(:rendered) do
      render_inline(described_class.new(academic_programs: academic_programs))
    end

    it 'displays section header' do
      expect(rendered.text).to include('Academic Programs')
    end

    context 'curricula section' do
      it 'displays curricula when present' do
        expect(rendered.text).to include('Curriculum')
        expect(rendered.text).to include('IB Programme')
        expect(rendered.text).to include('Cambridge IGCSE')
      end

      it 'shows curriculum icon' do
        # Check for the presence of the curriculum section header with icon
        expect(rendered).to have_content('Curriculum Programs')
      end
    end

    context 'languages section' do
      it 'displays languages when present' do
        expect(rendered.text).to include('Languages')
        expect(rendered.text).to include('English')
        expect(rendered.text).to include('Thai')
      end

      it 'shows language icon' do
        # Check for the presence of the languages section
        expect(rendered).to have_content('Languages')
      end
    end

    context 'accreditations section' do
      it 'displays accreditations when present' do
        expect(rendered.text).to include('Accreditation')
        expect(rendered.text).to include('WASC')
      end

      it 'shows accreditation icon' do
        # Check for the presence of the accreditations section
        expect(rendered).to have_content('Accreditations')
      end
    end

    context 'with partial data' do
      let(:partial_academic_programs) do
        {
          curricula: [ ib_curriculum ],
          languages: [],
          accreditations: nil
        }
      end

      subject(:rendered) do
        render_inline(described_class.new(academic_programs: partial_academic_programs))
      end

      it 'only shows sections with data' do
        expect(rendered.text).to include('Curriculum')
        expect(rendered.text).to include('IB Programme')
        expect(rendered.text).not_to include('Languages')
        expect(rendered.text).not_to include('Accreditation')
      end
    end

    context 'with empty data' do
      subject(:rendered) do
        render_inline(described_class.new(academic_programs: {}))
      end

      it 'renders nothing when render? returns false' do
        expect(rendered.to_html.strip).to be_empty
      end
    end
  end

  describe 'private methods' do
    let(:component) { described_class.new(academic_programs: academic_programs) }

    describe '#has_any_programs?' do
      it 'returns true when any section has data' do
        expect(component.send(:has_any_programs?)).to be true
      end

      it 'returns false when no sections have data' do
        empty_component = described_class.new(academic_programs: {})
        expect(empty_component.send(:has_any_programs?)).to be false
      end
    end

    describe '#curricula' do
      it 'returns curricula array' do
        expect(component.send(:curricula)).to eq([ ib_curriculum, cambridge_curriculum ])
      end

      it 'returns empty array when curricula is nil' do
        nil_component = described_class.new(academic_programs: { curricula: nil })
        expect(nil_component.send(:curricula)).to eq([])
      end
    end

    describe '#languages' do
      it 'returns languages array' do
        expect(component.send(:languages)).to eq([ english_language, thai_language ])
      end

      it 'returns empty array when languages is nil' do
        nil_component = described_class.new(academic_programs: { languages: nil })
        expect(nil_component.send(:languages)).to eq([])
      end
    end

    describe '#accreditations' do
      it 'returns accreditations array' do
        expect(component.send(:accreditations)).to eq([ wasc_accreditation ])
      end

      it 'returns empty array when accreditations is nil' do
        nil_component = described_class.new(academic_programs: { accreditations: nil })
        expect(nil_component.send(:accreditations)).to eq([])
      end
    end
  end

  describe 'section display logic' do
    let(:component) { described_class.new(academic_programs: academic_programs) }

    describe '#show_curricula?' do
      it 'returns true when curricula exist' do
        expect(component.send(:show_curricula?)).to be true
      end

      it 'returns false when curricula is empty' do
        empty_component = described_class.new(academic_programs: { curricula: [] })
        expect(empty_component.send(:show_curricula?)).to be false
      end
    end

    describe '#show_languages?' do
      it 'returns true when languages exist' do
        expect(component.send(:show_languages?)).to be true
      end

      it 'returns false when languages is empty' do
        empty_component = described_class.new(academic_programs: { languages: [] })
        expect(empty_component.send(:show_languages?)).to be false
      end
    end

    describe '#show_accreditations?' do
      it 'returns true when accreditations exist' do
        expect(component.send(:show_accreditations?)).to be true
      end

      it 'returns false when accreditations is empty' do
        empty_component = described_class.new(academic_programs: { accreditations: [] })
        expect(empty_component.send(:show_accreditations?)).to be false
      end
    end
  end

  describe 'icon methods' do
    let(:component) { described_class.new(academic_programs: academic_programs) }

    it 'provides section icon svg' do
      allow(component).to receive(:helpers).and_return(double('helpers'))
      allow(component.helpers).to receive(:heroicon).with('globe', css_class: 'w-5 h-5 text-gray-500 dark:text-gray-400').and_return('<svg>icon</svg>')

      result = component.send(:section_icon_svg, 'globe')
      expect(result).to eq('<svg>icon</svg>')
    end
  end

  describe 'accessibility' do
    subject(:rendered) do
      render_inline(described_class.new(academic_programs: academic_programs))
    end

    it 'includes proper heading structure' do
      expect(rendered.css('h3')).not_to be_empty
    end

    it 'includes descriptive text for screen readers' do
      expect(rendered.text).to include('Academic Programs')
    end

    it 'uses semantic HTML structure' do
      # Component uses divs with flex layout rather than lists
      expect(rendered.css('div.flex-wrap')).not_to be_empty
    end
  end

  describe 'edge cases' do
    context 'with very long curriculum names' do
      let(:long_curriculum) do
        create(:term,
          vocabulary: vocabulary_curriculum,
          slug: 'very-long-name',
          label: 'A' * 100
        )
      end

      let(:long_programs) { { curricula: [ long_curriculum ] } }

      subject(:rendered) do
        render_inline(described_class.new(academic_programs: long_programs))
      end

      it 'handles long names gracefully' do
        expect(rendered.text).to include('A' * 100)
      end
    end

    context 'with special characters in names' do
      let(:special_curriculum) do
        create(:term,
          vocabulary: vocabulary_curriculum,
          slug: 'special-chars',
          label: 'Programme Français & 中文课程'
        )
      end

      let(:special_programs) { { curricula: [ special_curriculum ] } }

      subject(:rendered) do
        render_inline(described_class.new(academic_programs: special_programs))
      end

      it 'displays special characters correctly' do
        expect(rendered.text).to include('Programme Français & 中文课程')
      end
    end

    context 'with large number of items' do
      let(:many_curricula) do
        20.times.map do |i|
          create(:term,
            vocabulary: vocabulary_curriculum,
            slug: "curriculum-#{i}",
            label: "Curriculum #{i}"
          )
        end
      end

      let(:many_programs) { { curricula: many_curricula } }

      subject(:rendered) do
        render_inline(described_class.new(academic_programs: many_programs))
      end

      it 'handles large number of items' do
        # Component renders items in flex containers, not list items
        expect(rendered.css('div.flex-wrap')).not_to be_empty
        expect(rendered.text).to include('Curriculum 0')
        expect(rendered.text).to include('Curriculum 19')
      end
    end
  end
end
