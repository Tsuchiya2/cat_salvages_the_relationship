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

ActiveRecord::Schema.define(version: 2021_10_20_135448) do

  create_table "alarm_contents", charset: "utf8mb4", force: :cascade do |t|
    t.string "body", null: false
    t.integer "category", default: 0, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["body"], name: "index_alarm_contents_on_body", unique: true
  end

  create_table "contents", charset: "utf8mb4", force: :cascade do |t|
    t.string "body", null: false
    t.integer "category", default: 0, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["body"], name: "index_contents_on_body", unique: true
  end

  create_table "feedbacks", charset: "utf8mb4", force: :cascade do |t|
    t.text "text", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "line_groups", charset: "utf8mb4", force: :cascade do |t|
    t.string "line_group_id", null: false
    t.date "remind_at", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["line_group_id"], name: "index_line_groups_on_line_group_id", unique: true
  end

  create_table "operators", charset: "utf8mb4", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "crypted_password"
    t.string "salt"
    t.integer "role", default: 1, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.integer "failed_logins_count", default: 0
    t.datetime "lock_expires_at"
    t.string "unlock_token"
    t.index ["email"], name: "index_operators_on_email", unique: true
    t.index ["unlock_token"], name: "index_operators_on_unlock_token"
  end

end
