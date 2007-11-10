# This file is autogenerated. Instead of editing this file, please use the
# migrations feature of ActiveRecord to incrementally modify your database, and
# then regenerate this schema definition.

ActiveRecord::Schema.define(:version => 15) do

  create_table "config_params", :force => true do |t|
    t.column "param_name", :string, :default => "", :null => false
    t.column "param_value", :string, :default => "", :null => false
    t.column "param_desc", :string, :default => "", :null => false
    t.column "updated_at", :datetime
  end

  create_table "contacts", :force => true do |t|
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
    t.column "customer_id", :integer
    t.column "referred_by_id", :integer
    t.column "referred_by_other", :string
    t.column "formal_relationship", :enum, :limit => [:None, :"Board Member", :"Former Board Member", :"Board President", :"Former Board President", :"Honorary Board Member", :"Emeritus Board Member"]
    t.column "member_type", :enum, :limit => [:None, :Regular, :Sustaining, :Life, :"Honorary Life"]
    t.column "company", :string
    t.column "title", :string
    t.column "address_line_1", :string
    t.column "address_line_2", :string
    t.column "city", :string
    t.column "state", :string
    t.column "zip", :string
    t.column "work_phone", :string
    t.column "cell_phone", :string
    t.column "work_fax", :string
    t.column "url", :string
  end

  create_table "customers", :force => true do |t|
    t.column "first_name", :string, :limit => 64, :default => "", :null => false
    t.column "last_name", :string, :limit => 64, :default => "", :null => false
    t.column "street", :string, :limit => 80, :default => "", :null => false
    t.column "city", :string, :limit => 64, :default => "", :null => false
    t.column "state", :string, :limit => 8, :default => "CA", :null => false
    t.column "zip", :string, :limit => 12, :default => "", :null => false
    t.column "day_phone", :string, :limit => 50, :default => "", :null => false
    t.column "eve_phone", :string, :limit => 50, :default => "", :null => false
    t.column "phplist_user_id", :integer, :default => 0, :null => false
    t.column "login", :string, :null => true, :default => nil
    t.column "hashed_password", :string, :default => "", :null => false
    t.column "salt", :string, :limit => 12, :default => "", :null => false
    t.column "role", :integer, :limit => 4, :default => 0, :null => false
    t.column "created_on", :datetime, :null => false
    t.column "updated_on", :datetime, :null => false
    t.column "comments", :text, :default => "", :null => false
    t.column "oldid", :integer, :limit => 15, :default => 0, :null => false
    t.column "blacklist", :boolean, :default => false
    t.column "validation_level", :integer, :default => 0
    t.column "last_login", :datetime, :default => Fri Apr 06 15:40:20 -0700 2007, :null => false
    t.column "e_blacklist", :boolean, :default => false
    t.column "e_newsletter", :boolean, :default => true
    t.column "e_kids", :boolean, :default => false
    t.column "e_volunteer", :boolean, :default => false
    t.column "e_audition", :boolean, :default => false
  end

  create_table "donation_funds", :force => true do |t|
    t.column "name", :string, :limit => 40, :default => "", :null => false
  end

  create_table "donation_types", :force => true do |t|
    t.column "name", :string, :limit => 40, :default => "", :null => false
  end

  create_table "donations", :force => true do |t|
    t.column "date", :date, :null => false
    t.column "amount", :float, :default => 0.0, :null => false
    t.column "donation_type_id", :integer, :default => 0, :null => false
    t.column "donation_fund_id", :integer, :default => 0, :null => false
    t.column "comment", :string, :default => "", :null => false
    t.column "customer_id", :integer, :default => 0, :null => false
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
    t.column "letter_sent", :datetime
    t.column "processed_by", :integer, :default => 2146722771, :null => false
  end

  create_table "orders", :force => true do |t|
    t.column "customer_id", :integer, :default => 1, :null => false
    t.column "show_id", :integer
    t.column "showdate_id", :integer
    t.column "transaction_date", :datetime
    t.column "purchasemethod_id", :integer
    t.column "comments", :string
    t.column "txn_type", :integer, :limit => 10, :default => 0, :null => false
  end

  create_table "purchasemethods", :force => true do |t|
    t.column "description", :string, :default => "", :null => false
    t.column "offer_public", :boolean, :default => false, :null => false
    t.column "shortdesc", :string, :limit => 10, :default => "?purch?", :null => false
  end

  create_table "sessions", :force => true do |t|
    t.column "session_id", :string
    t.column "data", :text
    t.column "updated_at", :datetime
  end

  add_index "sessions", ["session_id"], :name => "sessions_session_id_index"

  create_table "showdates", :force => true do |t|
    t.column "thedate", :datetime
    t.column "end_advance_sales", :datetime
    t.column "max_sales", :integer, :default => 0, :null => false
    t.column "show_id", :integer, :default => 0, :null => false
  end

  create_table "shows", :force => true do |t|
    t.column "name", :string
    t.column "opening_date", :date
    t.column "closing_date", :date
    t.column "house_capacity", :integer, :limit => 5, :default => 0, :null => false
    t.column "created_on", :datetime, :null => false
  end

  create_table "txn_types", :force => true do |t|
    t.column "desc", :string, :limit => 100, :default => "Other"
    t.column "shortdesc", :string, :limit => 10, :default => "???", :null => false
  end

  create_table "txns", :force => true do |t|
    t.column "customer_id", :integer, :default => 1, :null => false
    t.column "entered_by_id", :integer, :default => 1, :null => false
    t.column "txn_date", :datetime
    t.column "txn_type_id", :integer, :limit => 10, :default => 0, :null => false
    t.column "show_id", :integer
    t.column "showdate_id", :integer
    t.column "purchasemethod_id", :integer
    t.column "voucher_id", :integer, :default => 0, :null => false
    t.column "dollar_amount", :float, :default => 0.0, :null => false
    t.column "comments", :string
  end

  create_table "valid_vouchers", :force => true do |t|
    t.column "showdate_id", :integer
    t.column "vouchertype_id", :integer
    t.column "password", :string
    t.column "start_sales", :datetime
    t.column "end_sales", :datetime
    t.column "max_sales_for_type", :integer, :limit => 6, :default => 0, :null => false
  end

  create_table "visits", :force => true do |t|
    t.column "created_at", :datetime
    t.column "updated_at", :datetime
    t.column "visited_by_id", :integer, :default => 0, :null => false
    t.column "contact_method", :enum, :limit => [:Phone, :Email, :"Letter/Fax", :"In person"]
    t.column "location", :string
    t.column "purpose", :enum, :limit => [:Preliminary, :Followup, :Presentation, :"Further Discussion", :Close, :Recognition, :Other]
    t.column "result", :enum, :limit => [:"No interest", :"Further cultivation", :"Arrange for Gift", :"Gift Received"]
    t.column "additional_notes", :string
    t.column "followup_date", :date
    t.column "followup_action", :string
    t.column "next_ask_target", :integer, :default => 0, :null => false
    t.column "followup_assigned_to_id", :integer, :default => 0, :null => false
    t.column "contact_id", :integer
  end

  create_table "vouchers", :force => true do |t|
    t.column "vouchertype_id", :integer, :limit => 10, :default => 0, :null => false
    t.column "customer_id", :integer, :limit => 12, :default => 0, :null => false
    t.column "showdate_id", :integer, :default => 0, :null => false
    t.column "expiration_date", :datetime
    t.column "purchasemethod_id", :integer, :limit => 10, :default => 0, :null => false
    t.column "comments", :string
    t.column "created_on", :datetime
    t.column "updated_on", :datetime
    t.column "changeable", :boolean, :default => true
    t.column "fulfillment_needed", :boolean, :default => false
    t.column "external_key", :integer, :default => 0
    t.column "no_show", :boolean, :default => false, :null => false
    t.column "promo_code", :string
    t.column "processed_by", :integer, :default => 2146722771, :null => false
  end

  create_table "vouchertypes", :force => true do |t|
    t.column "name", :string
    t.column "price", :float, :default => 0.0
    t.column "created_on", :datetime
    t.column "comments", :text
    t.column "offer_public", :integer, :default => 0, :null => false
    t.column "is_bundle", :boolean, :default => false
    t.column "is_subscription", :boolean, :default => false, :null => false
    t.column "included_vouchers", :string, :default => "", :null => false
    t.column "promo_code", :string, :limit => 20, :default => "", :null => false
    t.column "walkup_sale_allowed", :boolean, :default => true
  end

end
