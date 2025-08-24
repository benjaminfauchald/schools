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

ActiveRecord::Schema[8.0].define(version: 2025_08_24_064811) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
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
    t.index ["api_status"], name: "index_places_on_api_status"
    t.index ["business_status"], name: "index_places_on_business_status"
    t.index ["last_fetched_at"], name: "index_places_on_last_fetched_at"
    t.index ["lat", "lng"], name: "index_places_on_lat_and_lng"
    t.index ["name"], name: "index_places_on_name"
    t.index ["place_id"], name: "index_places_on_place_id", unique: true
    t.index ["point_id"], name: "index_places_on_point_id"
    t.index ["rating"], name: "index_places_on_rating"
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

  add_foreign_key "places", "points"
end
