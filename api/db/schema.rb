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

ActiveRecord::Schema[8.1].define(version: 2026_02_15_152920) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "currencies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "iso3"
    t.string "name"
    t.integer "unit"
    t.datetime "updated_at", null: false
    t.index ["iso3"], name: "index_currencies_on_iso3", unique: true
  end

  create_table "exchange_rates", force: :cascade do |t|
    t.decimal "buy", precision: 18, scale: 6
    t.decimal "buy_raw", precision: 18, scale: 6
    t.datetime "created_at", null: false
    t.bigint "currency_id", null: false
    t.date "date"
    t.decimal "mid", precision: 18, scale: 6
    t.datetime "modified_on"
    t.datetime "published_on"
    t.decimal "sell", precision: 18, scale: 6
    t.decimal "sell_raw", precision: 18, scale: 6
    t.string "source"
    t.datetime "updated_at", null: false
    t.index ["currency_id", "date"], name: "idx_exchange_rates_currency_date", unique: true
    t.index ["currency_id"], name: "index_exchange_rates_on_currency_id"
  end

  create_table "ml_models", force: :cascade do |t|
    t.string "artifact_path"
    t.datetime "created_at", null: false
    t.string "framework"
    t.integer "horizons"
    t.jsonb "metrics"
    t.string "scaler_path"
    t.date "trained_until"
    t.datetime "updated_at", null: false
    t.string "version"
    t.integer "window_size"
    t.index ["version"], name: "ml_models_version_key", unique: true
  end

  create_table "predictions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "currency_id", null: false
    t.integer "horizon"
    t.string "model_version"
    t.date "predicted_for"
    t.date "prediction_date"
    t.string "target"
    t.datetime "updated_at", null: false
    t.decimal "yhat", precision: 18, scale: 6
    t.decimal "yhat_lower", precision: 18, scale: 6
    t.decimal "yhat_upper", precision: 18, scale: 6
    t.index ["currency_id", "target", "horizon", "predicted_for", "model_version"], name: "idx_pred_unique", unique: true
    t.index ["currency_id"], name: "index_predictions_on_currency_id"
  end

  add_foreign_key "exchange_rates", "currencies"
  add_foreign_key "predictions", "currencies"
end
