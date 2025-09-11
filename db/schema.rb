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

ActiveRecord::Schema[8.0].define(version: 2025_09_05_103504) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "postgis"
  enable_extension "vector"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

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

  create_table "ai_conversations", force: :cascade do |t|
    t.bigint "school_id", null: false
    t.bigint "user_id", null: false
    t.string "title"
    t.string "status", default: "active"
    t.json "metadata"
    t.datetime "last_message_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["last_message_at"], name: "index_ai_conversations_on_last_message_at"
    t.index ["school_id", "user_id"], name: "index_ai_conversations_on_school_id_and_user_id"
    t.index ["school_id"], name: "index_ai_conversations_on_school_id"
    t.index ["status"], name: "index_ai_conversations_on_status"
    t.index ["user_id"], name: "index_ai_conversations_on_user_id"
  end

  create_table "ai_messages", force: :cascade do |t|
    t.bigint "ai_conversation_id", null: false
    t.string "role", null: false
    t.text "content", null: false
    t.json "source_references"
    t.json "metadata"
    t.string "message_type", default: "text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_conversation_id"], name: "index_ai_messages_on_ai_conversation_id"
    t.index ["created_at"], name: "index_ai_messages_on_created_at"
    t.index ["message_type"], name: "index_ai_messages_on_message_type"
    t.index ["role"], name: "index_ai_messages_on_role"
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

# Could not dump table "document_contents" because of following StandardError
#   Unknown type 'vector(1536)' for column 'embedding'


# Could not dump table "documents" because of following StandardError
#   Unknown type 'vector(1536)' for column 'embedding'


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

  create_table "magic_link_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token", null: false
    t.string "purpose", null: false
    t.datetime "expires_at", null: false
    t.datetime "used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_magic_link_tokens_on_expires_at"
    t.index ["token"], name: "index_magic_link_tokens_on_token", unique: true
    t.index ["user_id", "purpose"], name: "index_magic_link_tokens_on_user_id_and_purpose"
    t.index ["user_id"], name: "index_magic_link_tokens_on_user_id"
  end

  create_table "media_items", force: :cascade do |t|
    t.bigint "place_id", null: false
    t.string "kind", null: false
    t.string "url", null: false
    t.string "alt_text"
    t.integer "sort_order", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source", default: "admin_upload"
    t.index ["place_id", "kind", "source"], name: "index_media_items_on_place_id_and_kind_and_source"
    t.index ["place_id", "kind"], name: "index_media_items_on_place_id_and_kind"
    t.index ["place_id", "sort_order"], name: "index_media_items_on_place_id_and_sort_order"
    t.index ["place_id"], name: "index_media_items_on_place_id"
  end

  create_table "pages", force: :cascade do |t|
    t.bigint "school_id", null: false
    t.string "title", null: false
    t.string "slug", null: false
    t.string "page_type", default: "blog", null: false
    t.string "status", default: "draft", null: false
    t.string "author"
    t.datetime "published_at"
    t.text "meta_description"
    t.string "featured_image_url"
    t.integer "sort_order", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["published_at"], name: "index_pages_on_published_at"
    t.index ["school_id", "page_type"], name: "index_pages_on_school_id_and_page_type"
    t.index ["school_id", "slug"], name: "index_pages_on_school_id_and_slug", unique: true
    t.index ["school_id", "status"], name: "index_pages_on_school_id_and_status"
    t.index ["school_id"], name: "index_pages_on_school_id"
    t.index ["sort_order"], name: "index_pages_on_sort_order"
    t.index ["status", "published_at"], name: "index_pages_on_status_and_published_at"
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
    t.string "youtube_url"
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
    t.datetime "revoked_at"
    t.bigint "revoked_by_id"
    t.text "revocation_reason"
    t.text "notes"
    t.index ["revoked_at"], name: "index_school_claims_on_revoked_at"
    t.index ["revoked_by_id"], name: "index_school_claims_on_revoked_by_id"
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

  create_table "school_inquiries", force: :cascade do |t|
    t.bigint "school_id", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.string "phone"
    t.text "message", null: false
    t.integer "children_count", null: false
    t.string "status", default: "new", null: false
    t.datetime "read_at"
    t.string "ip_address"
    t.text "admin_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["email"], name: "index_school_inquiries_on_email"
    t.index ["school_id", "created_at"], name: "index_school_inquiries_on_school_id_and_created_at"
    t.index ["school_id"], name: "index_school_inquiries_on_school_id"
    t.index ["status"], name: "index_school_inquiries_on_status"
    t.index ["user_id"], name: "index_school_inquiries_on_user_id"
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
    t.jsonb "facebook_content"
    t.datetime "facebook_last_fetched"
    t.string "facebook_profile_picture_url"
    t.string "facebook_cover_photo_url"
    t.text "tone_of_voice"
    t.jsonb "photo_visibility_settings", default: {}
    t.jsonb "preferences", default: {}, null: false
    t.string "youtube_url"
    t.string "linkedin_url"
    t.string "twitter_url"
    t.string "instagram_url"
    t.jsonb "video_visibility_settings", default: {}
    t.index ["district"], name: "index_schools_on_district"
    t.index ["facebook_content"], name: "index_schools_on_facebook_content", using: :gin
    t.index ["geog"], name: "index_schools_on_geog", using: :gist
    t.index ["name"], name: "index_schools_on_name", opclass: :gin_trgm_ops, using: :gin
    t.index ["photo_visibility_settings"], name: "index_schools_on_photo_visibility_settings", using: :gin
    t.index ["place_id"], name: "index_schools_on_place_id"
    t.index ["preferences"], name: "index_schools_on_preferences", using: :gin
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

  create_table "temp_claims", force: :cascade do |t|
    t.bigint "school_id", null: false
    t.string "token", null: false
    t.string "email", null: false
    t.string "evidence_url"
    t.text "notes"
    t.string "ip_address"
    t.datetime "expires_at", null: false
    t.string "status", default: "pending_registration"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_temp_claims_on_email"
    t.index ["expires_at"], name: "index_temp_claims_on_expires_at"
    t.index ["school_id"], name: "index_temp_claims_on_school_id"
    t.index ["status"], name: "index_temp_claims_on_status"
    t.index ["token"], name: "index_temp_claims_on_token", unique: true
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

# Could not dump table "transcript_segments" because of following StandardError
#   Unknown type 'vector(1536)' for column 'vector_embedding'


# Could not dump table "transcripts" because of following StandardError
#   Unknown type 'vector(1536)' for column 'vector_embedding'


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

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.string "role", default: "school_owner", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "provider"
    t.string "uid"
    t.string "facebook_name"
    t.string "facebook_profile_picture_url"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  create_table "vocabularies", force: :cascade do |t|
    t.string "code", null: false
    t.string "label", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_vocabularies_on_code", unique: true
  end

  create_table "webhook_audit_logs", force: :cascade do |t|
    t.string "webhook_type", null: false
    t.string "facebook_user_id", null: false
    t.bigint "user_id"
    t.jsonb "payload", null: false
    t.string "status", default: "processed"
    t.text "error_message"
    t.datetime "processed_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["facebook_user_id"], name: "index_webhook_audit_logs_on_facebook_user_id"
    t.index ["processed_at"], name: "index_webhook_audit_logs_on_processed_at"
    t.index ["user_id"], name: "index_webhook_audit_logs_on_user_id"
    t.index ["webhook_type", "facebook_user_id"], name: "idx_webhook_audit_type_fb_user"
    t.index ["webhook_type"], name: "index_webhook_audit_logs_on_webhook_type"
  end

  create_table "youtube_videos", force: :cascade do |t|
    t.string "video_id"
    t.text "title"
    t.text "description"
    t.string "thumbnail_url"
    t.string "duration"
    t.integer "view_count"
    t.datetime "published_at"
    t.json "video_data"
    t.boolean "visible"
    t.integer "sort_order"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "place_id", null: false
    t.index ["place_id", "sort_order"], name: "index_youtube_videos_on_place_id_and_sort_order"
    t.index ["place_id", "video_id"], name: "index_youtube_videos_on_place_id_and_video_id", unique: true
    t.index ["place_id", "visible"], name: "index_youtube_videos_on_place_id_and_visible"
    t.index ["place_id"], name: "index_youtube_videos_on_place_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_conversations", "schools"
  add_foreign_key "ai_conversations", "users"
  add_foreign_key "ai_messages", "ai_conversations"
  add_foreign_key "document_contents", "places"
  add_foreign_key "documents", "places", name: "documents_place_id_fkey"
  add_foreign_key "events", "places"
  add_foreign_key "magic_link_tokens", "users"
  add_foreign_key "media_items", "places"
  add_foreign_key "pages", "schools"
  add_foreign_key "places", "points"
  add_foreign_key "school_claims", "schools"
  add_foreign_key "school_claims", "users"
  add_foreign_key "school_fee_bands", "school_fee_schedules"
  add_foreign_key "school_fee_schedules", "schools"
  add_foreign_key "school_grade_offerings", "schools"
  add_foreign_key "school_inquiries", "schools"
  add_foreign_key "school_inquiries", "users"
  add_foreign_key "schools", "places"
  add_foreign_key "taggings", "terms"
  add_foreign_key "temp_claims", "schools"
  add_foreign_key "terms", "terms", column: "parent_id"
  add_foreign_key "terms", "vocabularies"
  add_foreign_key "transcript_segments", "transcripts"
  add_foreign_key "transcripts", "places"
  add_foreign_key "travel_times", "places"
  add_foreign_key "webhook_audit_logs", "users"
  add_foreign_key "youtube_videos", "places"
end
