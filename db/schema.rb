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

ActiveRecord::Schema[8.0].define(version: 2026_07_16_192400) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "benefit_coverage_rules", force: :cascade do |t|
    t.bigint "benefit_plan_id", null: false
    t.integer "level_of_service", null: false
    t.boolean "covered", default: true, null: false
    t.integer "trip_limit"
    t.boolean "prior_auth_required", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["benefit_plan_id", "level_of_service"], name: "index_coverage_rules_on_plan_and_service", unique: true
    t.index ["benefit_plan_id"], name: "index_benefit_coverage_rules_on_benefit_plan_id"
  end

  create_table "benefit_plans", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "care_organizations", force: :cascade do |t|
    t.string "name", null: false
    t.integer "org_type", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "coordinators", force: :cascade do |t|
    t.bigint "care_organization_id", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["care_organization_id"], name: "index_coordinators_on_care_organization_id"
    t.index ["email"], name: "index_coordinators_on_email", unique: true
  end

  create_table "patients", force: :cascade do |t|
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "phone", null: false
    t.string "home_address_line1", null: false
    t.string "home_address_line2"
    t.string "home_city", null: false
    t.string "home_state", null: false
    t.string "home_zip", null: false
    t.string "fhir_id"
    t.string "insurance_member_id"
    t.bigint "benefit_plan_id"
    t.integer "mobility_needs", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["benefit_plan_id"], name: "index_patients_on_benefit_plan_id"
    t.index ["fhir_id"], name: "index_patients_on_fhir_id", unique: true
  end

  create_table "ride_claims", force: :cascade do |t|
    t.bigint "ride_id", null: false
    t.bigint "transport_provider_id", null: false
    t.datetime "claimed_at", null: false
    t.datetime "released_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ride_id"], name: "index_ride_claims_on_active_claim", unique: true, where: "(released_at IS NULL)"
    t.index ["ride_id"], name: "index_ride_claims_on_ride_id"
    t.index ["transport_provider_id"], name: "index_ride_claims_on_transport_provider_id"
  end

  create_table "ride_status_events", force: :cascade do |t|
    t.bigint "ride_id", null: false
    t.string "actor_type"
    t.bigint "actor_id"
    t.integer "from_status"
    t.integer "to_status", null: false
    t.datetime "occurred_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_type", "actor_id"], name: "index_ride_status_events_on_actor"
    t.index ["occurred_at"], name: "index_ride_status_events_on_occurred_at"
    t.index ["ride_id"], name: "index_ride_status_events_on_ride_id"
  end

  create_table "rides", force: :cascade do |t|
    t.bigint "patient_id", null: false
    t.bigint "coordinator_id", null: false
    t.string "pickup_address_line1", null: false
    t.string "pickup_city", null: false
    t.string "pickup_state", null: false
    t.string "pickup_zip", null: false
    t.string "dropoff_address_line1", null: false
    t.string "dropoff_city", null: false
    t.string "dropoff_state", null: false
    t.string "dropoff_zip", null: false
    t.datetime "scheduled_at", null: false
    t.integer "level_of_service", null: false
    t.integer "status", default: 0, null: false
    t.boolean "needs_authorization", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["coordinator_id"], name: "index_rides_on_coordinator_id"
    t.index ["patient_id"], name: "index_rides_on_patient_id"
    t.index ["pickup_zip"], name: "index_rides_on_pickup_zip"
    t.index ["status"], name: "index_rides_on_status"
  end

  create_table "transport_provider_capabilities", force: :cascade do |t|
    t.bigint "transport_provider_id", null: false
    t.integer "capability", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["transport_provider_id", "capability"], name: "index_capabilities_on_provider_and_capability", unique: true
    t.index ["transport_provider_id"], name: "index_transport_provider_capabilities_on_transport_provider_id"
  end

  create_table "transport_providers", force: :cascade do |t|
    t.string "name", null: false
    t.string "phone", null: false
    t.string "service_area", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_area"], name: "index_transport_providers_on_service_area", using: :gin
  end

  create_table "webhook_events", force: :cascade do |t|
    t.string "event_id", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_webhook_events_on_event_id", unique: true
  end

  add_foreign_key "benefit_coverage_rules", "benefit_plans"
  add_foreign_key "coordinators", "care_organizations"
  add_foreign_key "patients", "benefit_plans"
  add_foreign_key "ride_claims", "rides"
  add_foreign_key "ride_claims", "transport_providers"
  add_foreign_key "ride_status_events", "rides"
  add_foreign_key "rides", "coordinators"
  add_foreign_key "rides", "patients"
  add_foreign_key "transport_provider_capabilities", "transport_providers"
end
