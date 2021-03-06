Given /subscription vouchers for seasons? (.*)/ do |seasons|
  seasons.split(/\s*,\s*/).each do |season|
    create(:bundle, :name => season, :subscription => true, :season => season)
  end
end

Given /the following subscribers exist:/ do |subscribers|
  subscribers.hashes.each do |customer|
    cust = create(:customer, :first_name => customer['customer'])
    customer['subscriptions'].split(/\s*,\s*/).each do |season|
      buy!(cust, Vouchertype.find_by(:name => season), 1)
    end
  end
end

Given /(?:an? )?"([^\"]+)" subscription available to (.*) for \$?([0-9.]+)/ do |name, to_whom, price| # "
  @sub = Vouchertype.create!(
    :name => name,
    :category => 'bundle',
    :subscription => true,
    :price => price,
    :walkup_sale_allowed => false,
    :offer_public => case to_whom
                 when /anyone/ ;     Vouchertype::ANYONE ;
                 when /subscriber/ ; Vouchertype::SUBSCRIBERS ;
                 when /external/ ;   Vouchertype::EXTERNAL ;
                 when /box ?office/ ;Vouchertype::BOXOFFICE ;
                 else raise "Subscription available to whom?"
                 end,
    :account_code => AccountCode.default_account_code,
    :season => Time.current.at_beginning_of_season.year
    )
  @sub.valid_vouchers.first.update_attributes!(
    :start_sales => Time.current.at_beginning_of_season,
    :end_sales   => Time.current.at_end_of_season,
    :max_sales_for_type => nil
    )
end

Given /^the "(.*)" subscription includes the following vouchers:/ do |name, vouchers|
  sub =
    Vouchertype.find_by_category_and_name('bundle', name) ||
    create(:bundle, :name => name, :subscription => true)
  sub.included_vouchers ||= {}
  vouchers.hashes.each do |voucher|
    vt = create(:vouchertype_included_in_bundle, :name => "#{voucher[:name]} (subscriber)")
    sub.included_vouchers[vt.id] = voucher[:quantity].to_i
  end
  sub.save!
end
