require "administrate/base_dashboard"

class PlaceDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    address_components: Field::Text.with_options(searchable: false),
    amenities: Field::Text.with_options(searchable: false),
    api_status: Field::String,
    business_status: Field::String,
    current_opening_hours: Field::Text.with_options(searchable: false),
    editorial_summary: Field::Text,
    error_message: Field::Text,
    formatted_address: Field::Text,
    formatted_phone_number: Field::String,
    geometry_data: Field::Text.with_options(searchable: false),
    google_place_id: Field::String,
    icon: Field::String,
    icon_background_color: Field::String,
    icon_mask_base_uri: Field::String,
    international_phone_number: Field::String,
    last_fetched_at: Field::DateTime,
    lat: Field::Number.with_options(decimals: 6),
    lng: Field::Number.with_options(decimals: 6),
    location: Field::String.with_options(searchable: false),
    name: Field::String,
    opening_hours: Field::Text.with_options(searchable: false),
    permanently_closed: Field::Boolean,
    photos: Field::Text.with_options(searchable: false),
    place_id: Field::String,
    plus_code_compound_code: Field::String,
    plus_code_global_code: Field::String,
    point: Field::BelongsTo,
    price_level: Field::Number,
    rating: Field::Number.with_options(decimals: 1),
    raw_api_response: Field::Text.with_options(searchable: false),
    reference: Field::String,
    reviews: Field::Text.with_options(searchable: false),
    scope: Field::String,
    secondary_opening_hours: Field::Text.with_options(searchable: false),
    types: Field::Text.with_options(searchable: false),
    url: Field::String,
    user_ratings_total: Field::Number,
    utc_offset: Field::Number,
    vicinity: Field::String,
    website: Field::String,
    wheelchair_accessible_entrance: Field::Boolean,
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
    name
    formatted_address
    rating
    business_status
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    address_components
    amenities
    api_status
    business_status
    current_opening_hours
    editorial_summary
    error_message
    formatted_address
    formatted_phone_number
    geometry_data
    google_place_id
    icon
    icon_background_color
    icon_mask_base_uri
    international_phone_number
    last_fetched_at
    lat
    lng
    location
    name
    opening_hours
    permanently_closed
    photos
    place_id
    plus_code_compound_code
    plus_code_global_code
    point
    price_level
    rating
    raw_api_response
    reference
    reviews
    scope
    secondary_opening_hours
    types
    url
    user_ratings_total
    utc_offset
    vicinity
    website
    wheelchair_accessible_entrance
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    name
    business_status
    api_status
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

  # Overwrite this method to customize how places are displayed
  # across all pages of the admin dashboard.
  def display_resource(place)
    place.name || "Place ##{place.id}"
  end
end
