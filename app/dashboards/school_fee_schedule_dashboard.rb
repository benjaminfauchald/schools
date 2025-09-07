require "administrate/base_dashboard"

class SchoolFeeScheduleDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    academic_year: Field::String,
    application_fee: Field::String.with_options(searchable: false),
    boarding_fee_annual: Field::String.with_options(searchable: false),
    capital_levy: Field::String.with_options(searchable: false),
    currency: Field::String,
    enrollment_fee: Field::String.with_options(searchable: false),
    is_published: Field::Boolean,
    max_tuition: Field::String.with_options(searchable: false),
    min_tuition: Field::String.with_options(searchable: false),
    notes: Field::Text,
    school: Field::BelongsTo,
    school_fee_bands: Field::HasMany,
    transport_fee_annual: Field::String.with_options(searchable: false),
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
    id
    academic_year
    application_fee
    boarding_fee_annual
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    academic_year
    application_fee
    boarding_fee_annual
    capital_levy
    currency
    enrollment_fee
    is_published
    max_tuition
    min_tuition
    notes
    school
    school_fee_bands
    transport_fee_annual
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    academic_year
    application_fee
    boarding_fee_annual
    capital_levy
    currency
    enrollment_fee
    is_published
    max_tuition
    min_tuition
    notes
    school
    school_fee_bands
    transport_fee_annual
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

  # Overwrite this method to customize how school fee schedules are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(school_fee_schedule)
  #   "SchoolFeeSchedule ##{school_fee_schedule.id}"
  # end
end
