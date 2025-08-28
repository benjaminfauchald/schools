# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_08_28_101305) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "postgis"

  create_table "admin_users", force: :cascade do |t|
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "auditable_type", null: false
    t.bigint "auditable_id", null: false
    t.bigint "user_id"
    t.string "action", null: false
    t.jsonb "changed_fields", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["changed_fields"], name: "index_audit_logs_on_changed_fields", using: :gin
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "events", force: :cascade do |t|
    t.bigint "place_id", null: false
    t.string "title", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at"
    t.string "location"
    t.string "url"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["place_id", "starts_at"], name: "index_events_on_place_id_and_starts_at"
    t.index ["place_id"], name: "index_events_on_place_id"
    t.index ["starts_at"], name: "index_events_on_starts_at"
  end

  create_table "media_items", force: :cascade do |t|
    t.bigint "place_id", null: false
    t.string "kind", null: false
    t.string "url", null: false
    t.string "alt_text"
    t.integer "sort_order", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["place_id", "kind"], name: "index_media_items_on_place_id_and_kind"
    t.index ["place_id", "sort_order"], name: "index_media_items_on_place_id_and_sort_order"
    t.index ["place_id"], name: "index_media_items_on_place_id"
  end

  create_table "places", force: :cascade do |t|
    t.bigint "point_id"
    t.string "place_id", null: false
    t.string "google_place_id"
    t.string "name"
    t.text "formatted_address"
    t.string "vicinity"
    t.string "business_status"
    t.decimal "rating", precision: 2, scale: 1
    t.integer "user_ratings_total"
    t.integer "price_level"
    t.decimal "lat", precision: 10, scale: 6
    t.decimal "lng", precision: 10, scale: 6
    t.geography "location", limit: {:srid=>4326, :type=>"geometry", :geographic=>true}
    t.string "formatted_phone_number"
    t.string "international_phone_number"
    t.string "website"
    t.string "url"
    t.json "opening_hours"
    t.json "current_opening_hours"
    t.json "secondary_opening_hours"
    t.json "types"
    t.string "icon"
    t.string "icon_background_color"
    t.string "icon_mask_base_uri"
    t.json "address_components"
    t.string "plus_code_compound_code"
    t.string "plus_code_global_code"
    t.json "reviews"
    t.json "photos"
    t.text "editorial_summary"
    t.json "geometry_data"
    t.boolean "permanently_closed"
    t.string "reference"
    t.string "scope"
    t.integer "utc_offset"
    t.boolean "wheelchair_accessible_entrance"
    t.json "amenities"
    t.json "raw_api_response"
    t.datetime "last_fetched_at"
    t.string "api_status"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "website_crawled_at", precision: nil
    t.string "website_crawling_status"
    t.string "website_crawl_job_id"
    t.integer "website_pages_found"
    t.json "website_crawl_data"
    t.json "website_structured_data"
    t.text "website_crawling_error"
    t.index ["api_status"], name: "index_places_on_api_status"
    t.index ["business_status"], name: "index_places_on_business_status"
    t.index ["id", "lat", "lng"], name: "index_places_on_id_lat_lng"
    t.index ["last_fetched_at"], name: "index_places_on_last_fetched_at"
    t.index ["lat", "lng"], name: "index_places_on_lat_and_lng"
    t.index ["name"], name: "index_places_on_name"
    t.index ["place_id"], name: "index_places_on_place_id", unique: true
    t.index ["point_id"], name: "index_places_on_point_id"
    t.index ["rating"], name: "index_places_on_rating"
    t.index ["website_crawled_at"], name: "index_places_on_website_crawled_at"
    t.index ["website_crawling_status"], name: "index_places_on_website_crawling_status"
  end

  create_table "points", force: :cascade do |t|
    t.bigint "osm_id", null: false
    t.string "name"
    t.string "amenity"
    t.decimal "lat", precision: 15, scale: 10, null: false
    t.decimal "lon", precision: 15, scale: 10, null: false
    t.geometry "way", limit: {:srid=>0, :type=>"geometry"}, null: false
    t.json "tags"
    t.string "school_type"
    t.string "operator"
    t.string "operator_type"
    t.string "denomination"
    t.string "religion"
    t.integer "capacity"
    t.string "website"
    t.string "phone"
    t.string "email"
    t.string "grade_range"
    t.string "address"
    t.string "addr_housenumber"
    t.string "addr_street"
    t.string "addr_district"
    t.string "addr_subdistrict"
    t.string "addr_city"
    t.string "addr_province"
    t.string "addr_postcode"
    t.string "addr_country"
    t.string "language"
    t.string "language_of_instruction"
    t.boolean "fee", default: false
    t.string "access"
    t.integer "levels"
    t.boolean "wheelchair", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "shop"
    t.string "tourism"
    t.string "leisure"
    t.string "office"
    t.string "craft"
    t.string "healthcare"
    t.string "emergency"
    t.string "public_transport"
    t.string "name_en"
    t.string "name_th"
    t.string "alt_name"
    t.string "official_name"
    t.text "opening_hours"
    t.string "highway"
    t.string "railway"
    t.string "aeroway"
    t.string "waterway"
    t.string "natural"
    t.string "landuse"
    t.string "building"
    t.integer "building_levels"
    t.string "cuisine"
    t.string "brand"
    t.string "network"
    t.integer "ele"
    t.index ["addr_city"], name: "index_points_on_addr_city"
    t.index ["addr_district"], name: "index_points_on_addr_district"
    t.index ["amenity"], name: "index_points_on_amenity"
    t.index ["brand"], name: "index_points_on_brand"
    t.index ["building"], name: "index_points_on_building"
    t.index ["cuisine"], name: "index_points_on_cuisine"
    t.index ["highway"], name: "index_points_on_highway"
    t.index ["lat", "lon"], name: "index_points_on_lat_and_lon"
    t.index ["leisure"], name: "index_points_on_leisure"
    t.index ["name_en"], name: "index_points_on_name_en"
    t.index ["name_th"], name: "index_points_on_name_th"
    t.index ["natural"], name: "index_points_on_natural"
    t.index ["operator_type"], name: "index_points_on_operator_type"
    t.index ["osm_id"], name: "index_points_on_osm_id", unique: true
    t.index ["school_type"], name: "index_points_on_school_type"
    t.index ["shop"], name: "index_points_on_shop"
    t.index ["tourism"], name: "index_points_on_tourism"
    t.index ["way"], name: "index_points_on_way", using: :gist
  end

  create_table "school_claims", force: :cascade do |t|
    t.bigint "school_id", null: false
    t.bigint "user_id", null: false
    t.string "status", default: "pending", null: false
    t.string "evidence_url"
    t.text "admin_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["school_id", "user_id"], name: "index_school_claims_on_school_id_and_user_id", unique: true
    t.index ["school_id"], name: "index_school_claims_on_school_id"
    t.index ["status"], name: "index_school_claims_on_status"
    t.index ["user_id"], name: "index_school_claims_on_user_id"
  end

  create_table "school_fee_bands", force: :cascade do |t|
    t.bigint "school_fee_schedule_id", null: false
    t.integer "grade_from", null: false
    t.integer "grade_to", null: false
    t.decimal "annual_tuition", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["school_fee_schedule_id", "grade_from", "grade_to"], name: "index_school_fee_bands_on_schedule_and_grades", unique: true
    t.index ["school_fee_schedule_id"], name: "index_school_fee_bands_on_school_fee_schedule_id"
  end

  create_table "school_fee_schedules", force: :cascade do |t|
    t.bigint "school_id", null: false
    t.string "academic_year", null: false
    t.string "currency", default: "THB", null: false
    t.decimal "application_fee", precision: 10, scale: 2
    t.decimal "enrollment_fee", precision: 10, scale: 2
    t.decimal "capital_levy", precision: 10, scale: 2
    t.decimal "min_tuition", precision: 10, scale: 2
    t.decimal "max_tuition", precision: 10, scale: 2
    t.decimal "boarding_fee_annual", precision: 10, scale: 2
    t.decimal "transport_fee_annual", precision: 10, scale: 2
    t.text "notes"
    t.boolean "is_published", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_published"], name: "index_school_fee_schedules_on_is_published"
    t.index ["school_id", "academic_year"], name: "index_school_fee_schedules_on_school_id_and_academic_year", unique: true
    t.index ["school_id"], name: "index_school_fee_schedules_on_school_id"
  end

  create_table "school_grade_offerings", force: :cascade do |t|
    t.bigint "school_id", null: false
    t.decimal "min_age", precision: 3, scale: 1
    t.decimal "max_age", precision: 3, scale: 1
    t.string "grades"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["min_age", "max_age"], name: "index_school_grade_offerings_on_min_age_and_max_age"
    t.index ["school_id"], name: "index_school_grade_offerings_on_school_id", unique: true
  end

  create_table "schools", force: :cascade do |t|
    t.bigint "place_id"
    t.string "name", null: false
    t.string "slug", null: false
    t.text "about"
    t.integer "founded_year"
    t.string "ownership"
    t.string "phone"
    t.citext "email"
    t.string "website_url"
    t.string "admissions_url"
    t.string "address_line_1"
    t.string "address_line_2"
    t.string "district"
    t.string "province"
    t.string "postcode"
    t.string "country_code", default: "TH"
    t.decimal "lat", precision: 10, scale: 6
    t.decimal "lng", precision: 10, scale: 6
    t.decimal "student_teacher_ratio", precision: 4, scale: 2
    t.integer "avg_class_size"
    t.boolean "boarding", default: false
    t.boolean "school_bus", default: false
    t.text "language_support_notes"
    t.string "status", default: "draft"
    t.datetime "last_verification_at"
    t.tsvector "tsv"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.geometry "geog", limit: {:srid=>4326, :type=>"st_point"}
    t.datetime "website_crawled_at"
    t.string "website_crawling_status"
    t.integer "website_pages_found"
    t.json "website_crawl_data"
    t.json "website_structured_data"
    t.text "website_crawling_error"
    t.string "facebook_url"
    t.string "line_id"
    t.string "whatsapp_number"
    t.index ["district"], name: "index_schools_on_district"
    t.index ["geog"], name: "index_schools_on_geog", using: :gist
    t.index ["name"], name: "index_schools_on_name", opclass: :gin_trgm_ops, using: :gin
    t.index ["place_id"], name: "index_schools_on_place_id"
    t.index ["province"], name: "index_schools_on_province"
    t.index ["slug"], name: "index_schools_on_slug", unique: true
    t.index ["status", "place_id"], name: "index_schools_on_status_and_place_id"
    t.index ["status"], name: "index_schools_on_status"
    t.index ["tsv"], name: "index_schools_on_tsv", using: :gin
  end

  create_table "taggings", force: :cascade do |t|
    t.bigint "term_id", null: false
    t.string "taggable_type", null: false
    t.bigint "taggable_id", null: false
    t.string "context", null: false
    t.text "notes"
    t.date "valid_from"
    t.date "valid_to"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["context"], name: "index_taggings_on_context"
    t.index ["taggable_type", "taggable_id", "context"], name: "index_taggings_on_taggable_and_context"
    t.index ["taggable_type", "taggable_id"], name: "index_taggings_on_taggable_type_and_taggable_id"
    t.index ["term_id", "taggable_type", "taggable_id", "context"], name: "index_taggings_unique_term_per_context", unique: true
    t.index ["term_id"], name: "index_taggings_on_term_id"
    t.index ["valid_from", "valid_to"], name: "index_taggings_on_valid_from_and_valid_to"
  end

  create_table "terms", force: :cascade do |t|
    t.bigint "vocabulary_id", null: false
    t.string "slug", null: false
    t.string "label", null: false
    t.text "description"
    t.jsonb "metadata", default: {}
    t.bigint "parent_id"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_terms_on_is_active"
    t.index ["label"], name: "index_terms_on_label", opclass: :gin_trgm_ops, using: :gin
    t.index ["metadata"], name: "index_terms_on_metadata", using: :gin
    t.index ["parent_id"], name: "index_terms_on_parent_id"
    t.index ["slug"], name: "index_terms_on_slug", opclass: :gin_trgm_ops, using: :gin
    t.index ["vocabulary_id", "slug"], name: "index_terms_on_vocabulary_id_and_slug", unique: true
    t.index ["vocabulary_id"], name: "index_terms_on_vocabulary_id"
  end

  create_table "travel_times", force: :cascade do |t|
    t.bigint "place_id", null: false
    t.string "origin_hash", null: false
    t.string "mode", default: "driving", null: false
    t.integer "minutes"
    t.datetime "computed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["computed_at"], name: "index_travel_times_on_computed_at"
    t.index ["place_id", "origin_hash", "mode"], name: "index_travel_times_on_place_id_and_origin_hash_and_mode", unique: true
    t.index ["place_id"], name: "index_travel_times_on_place_id"
  end

  create_table "vocabularies", force: :cascade do |t|
    t.string "code", null: false
    t.string "label", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_vocabularies_on_code", unique: true
  end

  add_foreign_key "events", "places"
  add_foreign_key "media_items", "places"
  add_foreign_key "places", "points"
  add_foreign_key "school_claims", "schools"
  add_foreign_key "school_fee_bands", "school_fee_schedules"
  add_foreign_key "school_fee_schedules", "schools"
  add_foreign_key "school_grade_offerings", "schools"
  add_foreign_key "schools", "places"
  add_foreign_key "taggings", "terms"
  add_foreign_key "terms", "terms", column: "parent_id"
  add_foreign_key "terms", "vocabularies"
  add_foreign_key "travel_times", "places"
end
