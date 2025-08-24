require "administrate/base_dashboard"

class PointDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    access: Field::String,
    addr_city: Field::String,
    addr_country: Field::String,
    addr_district: Field::String,
    addr_housenumber: Field::String,
    addr_postcode: Field::String,
    addr_province: Field::String,
    addr_street: Field::String,
    addr_subdistrict: Field::String,
    address: Field::String,
    amenity: Field::String,
    capacity: Field::Number,
    denomination: Field::String,
    email: Field::String,
    fee: Field::Boolean,
    grade_range: Field::String,
    language: Field::String,
    language_of_instruction: Field::String,
    lat: Field::String.with_options(searchable: false),
    levels: Field::Number,
    lon: Field::String.with_options(searchable: false),
    name: Field::String,
    operator: Field::String,
    operator_type: Field::String,
    osm_id: Field::Number,
    phone: Field::String,
    places: Field::HasMany,
    primary_place: Field::HasOne,
    religion: Field::String,
    school_type: Field::String,
    tags: Field::String.with_options(searchable: false),
    way: Field::String.with_options(searchable: false),
    website: Field::String,
    wheelchair: Field::Boolean,
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
    id
    access
    addr_city
    addr_country
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    access
    addr_city
    addr_country
    addr_district
    addr_housenumber
    addr_postcode
    addr_province
    addr_street
    addr_subdistrict
    address
    amenity
    capacity
    denomination
    email
    fee
    grade_range
    language
    language_of_instruction
    lat
    levels
    lon
    name
    operator
    operator_type
    osm_id
    phone
    places
    primary_place
    religion
    school_type
    tags
    way
    website
    wheelchair
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    access
    addr_city
    addr_country
    addr_district
    addr_housenumber
    addr_postcode
    addr_province
    addr_street
    addr_subdistrict
    address
    amenity
    capacity
    denomination
    email
    fee
    grade_range
    language
    language_of_instruction
    lat
    levels
    lon
    name
    operator
    operator_type
    osm_id
    phone
    places
    primary_place
    religion
    school_type
    tags
    way
    website
    wheelchair
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

  # Overwrite this method to customize how points are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(point)
  #   "Point ##{point.id}"
  # end
end
