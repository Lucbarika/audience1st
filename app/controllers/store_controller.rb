class StoreController < ApplicationController
  include ActiveMerchant::Billing
  include Enumerable

  require "money.rb"

  before_filter :is_logged_in, :only => %w[edit_billing_address]

  verify(:method => :post,
         :only => %w[add_tickets_to_cart add_donation_to_cart
                        add_subscriptions_to_cart place_order],
         :add_to_flash => {:warning => "SYSTEM ERROR: action only callable as POST"},
         :redirect_to => {:action => 'index'})

  # this should be the last declarative spec since it will append another
  # before_filter
  if RAILS_ENV == 'production'
    ssl_required(:checkout, :place_order, 
                 :index, :subscribe,
                 :show_changed, :showdate_changed,
                 :shipping_address, :set_shipping_address,
                 :comment_changed,
                 :not_me, :edit_billing_address,
                 :enter_promo_code, :add_tickets_to_cart, :add_donation_to_cart,
                :remove_from_cart,
                :process_swipe)
  end

  def index
    reset_shopping
    @customer = store_customer
    @is_admin = current_admin.is_boxoffice
    set_return_to :controller => 'store', :action => 'index'
    # if this is initial visit to page, reset ticket choice info
    reset_current_show_and_showdate
    if (id = params[:showdate_id].to_i) > 0 && (s = Showdate.find_by_id(id))
      set_current_showdate(s)
    elsif (id = params[:show_id].to_i) > 0 && (s = Show.find_by_id(id))
      set_current_show(s)
    else                        # neither: pick earliest show
      s = get_all_showdates(@is_admin)
      unless (s.nil? || s.empty?)
        #set_current_showdate(s.sort.detect { |sd| sd.thedate >= Time.now } || s.first)
        set_current_show((s.sort.detect { |sd| sd.thedate >= Time.now } || s.first).show)
      end
    end
    @subscriber = @customer.is_subscriber?
    @next_season_subscriber = @customer.is_next_season_subscriber?
    @promo_code = session[:promo_code] || nil
    setup_ticket_menus
  end

  def subscribe
    reset_shopping
    session[:redirect_to] = :subscribe
    @customer = store_customer
    @subscriber = @customer.is_subscriber?
    @next_season_subscriber = @customer.is_next_season_subscriber?
    @cart = find_cart
    # this uses the temporary hack of adding bundle sales start/end
    #   to bundle voucher record directly...ugh
    @subs_to_offer = Vouchertype.find_products(:type => :subscription, :for_purchase_by => (@subscriber ? :subscribers : :nonsubscribers), :ignore_cutoff => @gAdmin.is_boxoffice)
    if @subs_to_offer.empty?
      flash[:warning] = "There are no subscriptions on sale at this time."
      redirect_to :action => :index
      return
    end
    if (v = params[:vouchertype_id]).to_i > 0 && # default selected subscription
        vt = Vouchertype.find_by_id(v) &&
        # note! must use grep (uses ===) rather than include (uses ==)
        @subs_to_offer.grep(vt)
      @selected_sub = v.to_i
    end
  end

  def shipping_address
    # if this is a post, add items to cart first (since we're coming from
    #  ticket selection page).  If a get, buyer just wants to modify
    #  gift recipient info.
    # add items to cart
    @cart = find_cart
    @redirect_to = params[:redirect_to] == 'subscribe' ? :subscribe : :index
    if request.post?
      @redirect_to == :subscribe ? process_subscription_request : process_ticket_request
      # did anything go wrong?
      redirect_to :action => :index and return unless flash[:warning].blank?
      if params[:donation].to_i > 0
        @cart.add(Donation.online_donation(params[:donation].to_i, store_customer.id,logged_in_id))
      end
    end
    # make sure something actually got added.
    if @cart.is_empty?
      flash[:warning] = "Please select some tickets."
      redirect_to :action => (params[:redirect_to] || :index)
      return
    end
    # all is well. if this is a gift order, fall through to get Recipient info.
    # if NOT a gift, set recipient to same as current customer, and
    # continue to checkout.
    # in case it's a gift, customer should know donation is made in their name.
    @includes_donation = @cart.items.detect { |v| v.kind_of?(Donation) }
    set_checkout_in_progress
    if params[:gift]
      @recipient = session[:recipient_id] ? Customer.find_by_id(session[:recipient_id]) : Customer.new
    else
      redirect_to :action => :checkout
    end
  end

  def set_shipping_address
    @cart = find_cart
    # if we can find a unique match for the customer AND our existing DB record
    #  has enough contact info, great.  OR, if the new record was already created but
    #  the buyer needs to modify it, great.
    #  Otherwise... create a NEW record based
    #  on the gift receipient information provided.
    if session[:recipient_id]
      @recipient = Customer.find_by_id(session[:recipient_id])
      @recipient.update_attributes(params[:customer])
    elsif ((@recipient = Customer.find_unique(params[:customer])) && # exact match
           @recipient.valid_as_gift_recipient?)                    # valid contact info
      # we're good; unique match, and already valid contact info.
    else
      # assume we'll have to create a new customer record.
      @recipient = Customer.new(params[:customer])
    end
    # make sure minimal info for gift receipient was specified.
    unless  @recipient.valid_as_gift_recipient?
      flash[:warning] = @recipient.errors.full_messages.join "<br/>"
      render :action => :shipping_address
      return
    end
    # try to match customer in DB, or create.
    if @recipient.new_record?
      unless @recipient.save
        flash[:warning] = @recipient.errors.full_messages
        render :action => :shipping_address
        return
      end
    end
    session[:recipient_id] = @recipient.id
    redirect_to :action => :checkout
  end

  def show_changed
    if (id = params[:show_id].to_i) > 0 && (s = Show.find_by_id(id))
      set_current_show(s)
      sd = s.future_showdates
      # set_current_showdate(sd.empty? ? nil : sd.first)
      set_current_showdate(nil)
    end
    setup_ticket_menus
    render :partial => 'ticket_menus'
  end

  def showdate_changed
    if (id = params[:showdate_id].to_i) > 0 && (s = Showdate.find_by_id(id))
      set_current_showdate(s)
    end
    setup_ticket_menus
    render :partial => 'ticket_menus'
  end

  def comment_changed
    cart = find_cart
    cart.comments = params[:comments]
    render :nothing => true
  end

  def enter_promo_code
    code = (params[:promo_code] || '').upcase
    if !code.empty?
      session[:promo_code] = code
    end
    redirect_to :action => 'index'
  end

  def checkout
    @cust = store_customer
    @is_admin = current_admin.is_boxoffice
    if session[:recipient_id]
      @recipient = Customer.find( session[:recipient_id] )
    else
      @recipient = @cust
    end
    @cart = find_cart
    @sales_final_acknowledged = (params[:sales_final].to_i > 0) || current_admin.is_boxoffice
    if @cart.is_empty?
      logger.warn "Cart empty, redirecting from checkout back to store"
      redirect_to(:action => 'index', :id => params[:id])
      return
    end
    @credit_card = ActiveMerchant::Billing::CreditCard.new
    set_return_to :controller => 'store', :action => 'checkout'
    # if this is a "walkup web" sale (not logged in), nil out the
    # customer to avoid modifing the Walkup customer.
    redirect_to :action => 'not_me' and return if nobody_really_logged_in
  end

  def not_me
    @cust = Customer.new
    set_return_to :controller => 'store', :action => 'checkout'
    flash[:warning] = "Please sign in, or if you don't have an account, please enter your credit card billing address."
    redirect_to :controller => 'customers', :action => 'login'
  end

  def edit_billing_address
    set_return_to :controller => 'store', :action => 'checkout'
    flash[:notice] = "Please update your credit card billing address below. Click 'Save Changes' when done to continue with your order."
    redirect_to :controller => 'customers', :action => 'edit'
  end

  def place_order
    @cart = find_cart_not_empty or return
    @customer = verify_valid_customer or return
    @is_admin = current_admin.is_boxoffice
    sales_final = verify_sales_final or return
    @recipient = verify_valid_recipient or return
    @cart.gift_from(@customer) unless @recipient == @customer
    # OK, we have a customer record to tie the transaction to
    if (params[:commit] =~ /credit/i || !@is_admin)
      args = collect_credit_card_info or return
      args.merge({:order_number => @cart.order_number,
                   :method => :credit})
      @payment="credit card #{args[:credit_card].display_number}"
    elsif params[:commit] =~ /check/i
      args = {:method => :check, :check_number => params[:check_number]}
      @payment = "check number #{params[:check_number]}"
    elsif params[:commit] =~ /cash/i
      args = {:method => :cash}
      @payment = "cash"
    end
    howpurchased = (@customer.id == logged_in_id ? 'cust_ph' : 'cust_web')
    resp = Store.purchase!(@cart.total_price, args) do
      # add non-donation items to recipient's account
      @recipient.add_items(@cart.nondonations_only, logged_in_id, howpurchased)
      @recipient.save!
      # add donation items to payer's account
      @customer.add_items(@cart.donations_only, logged_in_id, howpurchased)
      @amount = @cart.total_price
      @order_summary = @cart.to_s
      @special_instructions = @cart.comments
    end
    if resp.success?
      @payment << " (transaction ID: #{resp.params[:transaction_id]})" if
        @payment =~ /credit/i
      email_confirmation(:confirm_order, @customer,@recipient,@order_summary,
                         @amount, @payment,
                         @special_instructions)
      reset_shopping
      set_return_to
      return
    end
    # failure....
    flash[:checkout_error] = resp.message
    logger.info("FAILED purchase for #{@customer.id} [#{@customer.full_name}] by #{@payment}:\n #{resp.message}") rescue nil
    redirect_to :action => 'checkout', :sales_final => sales_final
  end

  private

  def setup_ticket_menus
    @customer = store_customer
    @cart = find_cart
    is_admin = current_admin.is_boxoffice
    # will set the following instance variables:
    # @all_shows - choice for Shows menu
    # @sh - selected show; nil means none selected
    # @all_showdates - choices for Showdates menu
    # @sd - selected showdate; nil means none selected
    # @vouchertypes - array of AvailableSeat objects indicating vouchertypes
    #   to offer, which includes how many are available
    #   empty array means must choose showdate first
    @all_shows = get_all_shows(get_all_showdates(is_admin))
    if @sd = current_showdate   # everything keys off of selected showdate
      @sh = @sd.show
      @all_showdates = (is_admin ? @sh.showdates :
                        @sh.future_showdates)
#       @all_showdates = (is_admin ? @sh.showdates :
#                         @sh.future_showdates.select { |s| s.total_seats_left > 0 })
      # make sure originally-selected showdate is included among those
      #  to be displayed.
      unless @all_showdates.include?(@sd)
        @sd = @all_showdates.first
      end
      @vouchertypes = (@sd ?
                       ValidVoucher.numseats_for_showdate(@sd.id,@customer,:ignore_cutoff => is_admin) :
                       [] )
    elsif @sh = current_show    # show selected, but not showdate
      @all_showdates = (is_admin ? @sh.showdates :
                        @sh.future_showdates)
#       @all_showdates = (is_admin ? @sh.showdates :
#                         @sh.future_showdates.select { |s| s.total_seats_left > 0 })
      @vouchertypes = []
    else                      # not even show is selected
      @all_showdates = []
      @vouchertypes = []
    end
    # filtering:
    # remove any showdates that are sold out (which could cause showdate menu
    #   to become empty)
    # remove any vouchertypes tht customer should not even see the existence
    #  of (unless "customer" is actually an admin)
    @vouchertypes.reject! { |av| av.staff_only } unless is_admin
    @vouchertypes.reject! { |av| av.howmany.zero? }
    # BUG: must filter vouchertypes by promo code!!
    # @vouchertypes.reject!
  end

  # Customer on whose behalf the store displays are based (for special
  # ticket eligibility, etc.)  Current implementation: same as the active
  # customer, if any; otherwise, the walkup customer.
  # INVARIANT: this MUST return a valid Customer record.
  def store_customer
    current_customer || Customer.walkup_customer
  end

  def reset_current_show_and_showdate ;  session[:store] = {} ;  end
  def set_current_show(s) ; (session[:store] ||= {})[:show] = s ; end
  def set_current_showdate(sd) ; (session[:store] ||= {})[:showdate] = sd ; end
  def current_showdate ;  (session[:store] ||= {})[:showdate] ;  end
  def current_show ; (session[:store] ||= {})[:show] ;  end

  def encrypt_with(orig,pad)
    str = String.new(orig)
    for i in (0..str.length-1) do
      str[i] ^= pad[i]
    end
    str
  end

  def convert_swipe_to_cc_info(s)
    # trk1: '%B' accnum '^' last '/' first '^' YYMM svccode(3 chr)
    #   discretionary data (up to 8 chr)  '?'
    # '%B' is a format code for the standard credit card "open" format; format
    # code '%A' would indicate a proprietary encoding
    trk1 = Regexp.new('^%B(\d{1,19})\\^([^/]+)/?([^/]+)?\\^(\d\d)(\d\d)[^?]+\\?', :ignore_case => true)
    # trk2: ';' accnum '=' YY MM svccode(3 chr) discretionary(up to 8 chr) '?'
    trk2 = Regexp.new(';(\d{1,19})=(\d\d)(\d\d).{3,12}\?', :ignore_case => true)

    # if card has a track 1, we use that (even if trk 2 also present)
    # else if only has a track 2, try to use that, but doesn't include name
    # else error.

    if s.match(trk1)
      accnum = Regexp.last_match(1).to_s
      lastname = Regexp.last_match(2).to_s.upcase
      firstname = Regexp.last_match(3).to_s.upcase # may be nil if this field was absent
      expyear = 2000 + Regexp.last_match(4).to_i
      expmonth = Regexp.last_match(5).to_i
    elsif s.match(trk2)
      accnum = Regexp.last_match(1).to_s
      expyear = 2000 + Regexp.last_match(2).to_i
      expmonth = Regexp.last_match(3).to_i
      lastname = firstname = ''
    else
      accnum = lastname = firstname = 'ERROR'
      expyear = expmonth = 0
    end
    CreditCard.new(:first_name => firstname.strip,
                   :last_name => lastname.strip,
                   :month => expmonth.to_i,
                   :year => expyear.to_i,
                   :number => accnum.strip,
                   :type => CreditCard.type?(accnum.strip) || '')
  end

  # helpers for the AJAX handlers. These should probably be moved
  # to the respective models for shows and showdates, or called as
  # helpers from the views directly.

  def get_all_shows(showdates)
    showdates.map { |s| s.show }.uniq.sort_by { |s| s.opening_date }
  end

  def get_all_showdates(ignore_cutoff = false)
    if ignore_cutoff
      showdates = Showdate.find(:all, :conditions => ['thedate >= ?', Time.now.at_beginning_of_season])
    else
      showdates = Showdate.find(ValidVoucher.for_advance_sales.keys).sort_by(&:thedate)
    end
  end

  def get_all_subs(cust = Customer.generic_customer)
    return Vouchertype.find(:all, :conditions => ["bundle = 1 AND offer_public > ?", (cust.kind_of?(Customer) && cust.is_subscriber? ? 0 : 1)])
  end

  def process_ticket_request
    unless (showdate = Showdate.find_by_id(params[:showdate])) ||
        params[:donation].to_i > 0
      flash[:warning] = "Please select a show date and tickets, or enter a donation amount."
      return
    end
    msgs = []
    comments = params[:comments]
    (params[:vouchertype] ||= {}).each_pair do |vtype, qty|
      qty = qty.to_i
      unless qty.zero?
        av = ValidVoucher.numseats_for_showdate_by_vouchertype(showdate, store_customer, vtype, :ignore_cutoff => @gAdmin.is_boxoffice)
        if av.howmany.zero?
          msgs << "Sorry, no '#{Vouchertype.find_by_id(vtype.to_i).name}' tickets available for this performance."
        elsif av.howmany < qty
          msgs << "Only #{av.howmany} '#{Vouchertype.find_by_id(vtype.to_i).name}' tickets available for this performance (you requested #{qty})."
        else
          @cart.comments ||= comments
          qty.times  do
            @cart.add(Voucher.anonymous_voucher_for(showdate,vtype,nil,comments))
            comments = nil      # HACK - only add to first voucher
          end
        end
      end
    end
    flash[:warning] = msgs.join("<br/>") unless msgs.empty?
  end

  def process_subscription_request
    # subscription tickets
    # BUG should check eligibility here
    params[:vouchertype].each_pair do |vtype, qty|
      unless qty.to_i.zero?
        qty.to_i.times { @cart.add(Voucher.anonymous_bundle_for(vtype)) }
      end
    end
  end

  def verify_valid_recipient
    if session[:recipient_id]
      # buyer is different from recipient
      unless recipient = Customer.find_by_id(session[:recipient_id])
        flash[:warning] = 'Gift recipient is invalid'
        logger.error "Gift order, but invalid recipient; id=#{session[:recipient_id]}"
        redirect_to :action => 'index'
        return nil
      end
    else
      recipient = @customer
    end
    recipient
  end

  def verify_valid_customer
    @customer = current_customer
    unless @customer.kind_of?(Customer)
      flash[:warning] = "SYSTEM ERROR: Invalid purchaser (id=#{@customer.id})"
      logger.error "Reached place_order with invalid customer: #{@customer}"
      redirect_to :action => 'checkout'
      return nil
    end
    @customer
  end

  def collect_credit_card_info
    bill_to = Customer.new(params[:customer])
    cc_info = params[:credit_card].symbolize_keys
    cc_info[:first_name] = bill_to.first_name
    cc_info[:last_name] = bill_to.last_name
    # BUG: workaround bug in xmlbase.rb where to_int (nonexistent) is
    # called rather than to_i to convert month and year to ints.
    cc_info[:month] = cc_info[:month].to_i
    cc_info[:year] = cc_info[:year].to_i
    cc = CreditCard.new(cc_info)
    # prevalidations: CC# and address appear valid, amount >0,
    # billing address appears to be a well-formed address
    if ! cc.valid?              # format check on credit card number
      flash[:checkout_error] =
        "<p>Please provide valid credit card information:</p> <ul><li>" <<
        cc.errors.full_messages.join("</li><li>") <<
        "</li></ul>"
      redirect_to :action => 'checkout'
      return nil
    end
    return {:credit_card => cc, :bill_to => bill_to}
  end

  def find_cart_not_empty
    cart = find_cart
    if cart.total_price <= 0
      flash[:checkout_error] =
        "Your order appears to be empty. Please select some tickets."
      redirect_to :action => 'index'
      return nil
    end
    return cart
  end

  def verify_sales_final
    if (sales_final = params[:sales_final].to_i).zero?
      flash[:checkout_error] = "Please indicate your acceptance of our Sales Final policy by checking the box."
      redirect_to :action => 'checkout'
      return nil
    else
      return sales_final
    end
  end
end
