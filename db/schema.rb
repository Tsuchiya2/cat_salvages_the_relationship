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

ActiveRecord::Schema[8.1].define(version: 2025_11_29_105920) do
  create_table "alarm_contents", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "body", null: false
    t.integer "category", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["body"], name: "index_alarm_contents_on_body", unique: true
  end

  create_table "client_logs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.json "context"
    t.timestamp "created_at", null: false
    t.string "level", null: false
    t.text "message", null: false
    t.string "trace_id"
    t.text "url"
    t.text "user_agent"
    t.index ["created_at"], name: "index_client_logs_on_created_at"
    t.index ["level", "created_at"], name: "index_client_logs_on_level_and_created_at"
    t.index ["level"], name: "index_client_logs_on_level"
    t.index ["trace_id"], name: "index_client_logs_on_trace_id"
  end

  create_table "contents", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "body", null: false
    t.integer "category", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["body"], name: "index_contents_on_body", unique: true
  end

  create_table "feedbacks", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "text", null: false
    t.datetime "updated_at", null: false
  end

  create_table "line_groups", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "line_group_id", null: false
    t.integer "member_count", default: 0, null: false
    t.integer "post_count", default: 0, null: false
    t.date "remind_at", null: false
    t.integer "set_span", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["line_group_id"], name: "index_line_groups_on_line_group_id", unique: true
  end

  create_table "metrics", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.timestamp "created_at", null: false
    t.string "name", null: false
    t.json "tags"
    t.string "trace_id"
    t.string "unit"
    t.decimal "value", precision: 15, scale: 4, null: false
    t.index ["created_at"], name: "index_metrics_on_created_at"
    t.index ["name", "created_at"], name: "index_metrics_on_name_and_created_at"
    t.index ["name"], name: "index_metrics_on_name"
    t.index ["trace_id"], name: "index_metrics_on_trace_id"
  end

  create_table "operators", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.integer "failed_logins_count", default: 0
    t.datetime "lock_expires_at"
    t.string "name", null: false
    t.string "password_digest"
    t.integer "role", default: 1, null: false
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_operators_on_email", unique: true
    t.index ["password_digest"], name: "index_operators_on_password_digest"
    t.index ["unlock_token"], name: "index_operators_on_unlock_token"
  end
end
