# frozen_string_literal: true

class Schools::AcademicProgramsComponent < ViewComponent::Base
  def initialize(academic_programs:)
    @academic_programs = academic_programs
  end

  private

  attr_reader :academic_programs

  def render?
    has_any_programs?
  end

  def has_any_programs?
    curricula.any? || accreditations.any? || languages.any? || programs.any?
  end

  def curricula
    academic_programs[:curricula] || []
  end

  def accreditations
    academic_programs[:accreditations] || []
  end

  def languages
    academic_programs[:languages] || []
  end

  def programs
    academic_programs[:programs] || []
  end

  def curriculum_groups
    # Group curricula by type for better organization
    {
      "International Baccalaureate" => curricula.select { |c| c.slug.include?("ib_") },
      "UK Curriculum" => curricula.select { |c| c.slug.include?("uk_") },
      "US Curriculum" => curricula.select { |c| c.slug.include?("us_") },
      "Other Programs" => curricula.reject { |c| c.slug.match?(/^(ib_|uk_|us_)/) }
    }.reject { |_, terms| terms.empty? }
  end

  def program_sections
    sections = []

    if curricula.any?
      sections << {
        title: "Curriculum",
        icon: "academic-cap",
        items: curricula,
        variant: :curriculum,
        description: "Academic programs and educational frameworks"
      }
    end

    if accreditations.any?
      sections << {
        title: "Accreditations",
        icon: "star",
        items: accreditations,
        variant: :accreditation,
        description: "Official certifications and recognitions"
      }
    end

    if languages.any?
      sections << {
        title: "Languages",
        icon: "globe",
        items: languages,
        variant: :language,
        description: "Languages of instruction and support"
      }
    end

    if programs.any?
      sections << {
        title: "Special Programs",
        icon: "building-office",
        items: programs,
        variant: :program,
        description: "Additional support and enrichment programs"
      }
    end

    sections
  end

  def show_curricula?
    curricula.any?
  end

  def show_languages?
    languages.any?
  end

  def show_accreditations?
    accreditations.any?
  end

  def section_icon_svg(icon_name)
    helpers.heroicon(icon_name, css_class: "w-5 h-5 text-gray-500 dark:text-gray-400")
  end
end
