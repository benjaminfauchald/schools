require "administrate/base_dashboard"

class SchoolDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    about: Field::Text,
    address_line_1: Field::String,
    address_line_2: Field::String,
    admissions_url: Field::String,
    audit_logs: Field::HasMany,
    avg_class_size: Field::Number,
    boarding: Field::Boolean,
    country_code: Field::String,
    current_taggings: Field::HasMany,
    current_terms: Field::HasMany,
    district: Field::String,
    email: Field::String.with_options(searchable: false),
    events: Field::HasMany,
    founded_year: Field::Number,
    geog: Field::String.with_options(searchable: false),
    language_support_notes: Field::Text,
    last_verification_at: Field::DateTime,
    lat: Field::String.with_options(searchable: false),
    lng: Field::String.with_options(searchable: false),
    media_items: Field::HasMany,
    name: Field::String,
    ownership: Field::Select.with_options(searchable: false, collection: ->(field) { field.resource.class.send(field.attribute.to_s.pluralize).keys }),
    phone: Field::String,
    place: Field::BelongsTo,
    postcode: Field::String,
    province: Field::String,
    school_bus: Field::Boolean,
    school_claims: Field::HasMany,
    school_fee_schedules: Field::HasMany,
    school_grade_offering: Field::HasOne,
    slug: Field::String,
    status: Field::Select.with_options(searchable: false, collection: ->(field) { field.resource.class.send(field.attribute.to_s.pluralize).keys }),
    student_teacher_ratio: Field::String.with_options(searchable: false),
    taggings: Field::HasMany,
    terms: Field::HasMany,
    travel_times: Field::HasMany,
    tsv: Field::String.with_options(searchable: false),
    website_url: Field::String,
    facebook_url: Field::String,
    line_id: Field::String,
    whatsapp_number: Field::String,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
    name
    place
    ownership
    status
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    about
    address_line_1
    address_line_2
    admissions_url
    audit_logs
    avg_class_size
    boarding
    country_code
    current_taggings
    current_terms
    district
    email
    events
    founded_year
    geog
    language_support_notes
    last_verification_at
    lat
    lng
    media_items
    name
    ownership
    phone
    place
    postcode
    province
    school_bus
    school_claims
    school_fee_schedules
    school_grade_offering
    slug
    status
    student_teacher_ratio
    taggings
    terms
    travel_times
    tsv
    website_url
    facebook_url
    line_id
    whatsapp_number
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    name
    slug
    about
    place
    ownership
    status
    address_line_1
    address_line_2
    district
    province
    postcode
    country_code
    phone
    email
    website_url
    facebook_url
    line_id
    whatsapp_number
    admissions_url
    founded_year
    avg_class_size
    student_teacher_ratio
    boarding
    school_bus
    language_support_notes
  ].freeze

  # COLLECTION_FILTERS
  # a hash that defines filters that can be used while searching via the search
  # field of the dashboard.
  #
  # For example to add an option to search for open resources by typing "open:"
  # in the search field:
  #
  #   COLLECTION_FILTERS = {
  #     open: ->(resources) { resources.where(open: true) }
  #   }.freeze
  COLLECTION_FILTERS = {}.freeze

  # Overwrite this method to customize how schools are displayed
  # across all pages of the admin dashboard.
  def display_resource(school)
    school.name || "School ##{school.id}"
  end
end
