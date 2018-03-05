# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2018_03_04_025611) do

  create_table "bots", force: :cascade do |t|
    t.integer "user_id"
    t.string "name"
    t.string "token"
    t.string "auth_route"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_bots_on_user_id"
  end

  create_table "commands", force: :cascade do |t|
    t.integer "bot_id"
    t.string "name"
    t.integer "type"
    t.string "data"
    t.boolean "reply"
    t.boolean "privileged"
    t.integer "min"
    t.integer "max"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bot_id"], name: "index_commands_on_bot_id"
  end

  create_table "feedback_types", force: :cascade do |t|
    t.integer "bot_id"
    t.string "name"
    t.integer "type"
    t.string "icon"
    t.boolean "blacklist"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bot_id"], name: "index_feedback_types_on_bot_id"
  end

  create_table "post_types", force: :cascade do |t|
    t.string "name"
    t.string "ws"
    t.string "route"
    t.integer "allocation"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sites", force: :cascade do |t|
    t.string "name"
    t.integer "last_scanned"
    t.integer "se_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "subscriptions", force: :cascade do |t|
    t.integer "bot_id"
    t.integer "post_type_id"
    t.integer "site_id"
    t.boolean "all_sites"
    t.string "route"
    t.integer "request_method"
    t.string "spam_key"
    t.integer "key_type"
    t.string "answer_key"
    t.integer "min_score"
    t.string "chat_template"
    t.string "web_template"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bot_id"], name: "index_subscriptions_on_bot_id"
    t.index ["post_type_id"], name: "index_subscriptions_on_post_type_id"
    t.index ["site_id"], name: "index_subscriptions_on_site_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

end
