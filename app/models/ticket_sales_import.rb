class TicketSalesImport < Import

  belongs_to :show
  validates_associated :show
  validate :show_exists?

  class TicketSalesImport::ShowNotFound < Exception ; end
  class TicketSalesImport::PreviewOnly  < Exception ; end
  class TicketSalesImport::ImportError < Exception ; end

  attr_accessor :show, :vouchers, :existing_vouchers
  attr_accessor :created_customers, :matched_customers
  attr_accessor :created_showdates, :created_vouchertypes

  public

  def show_exists?
    errors.add_to_base('You must specify an existing show.') unless
      self.show_id && Show.find_by_id(show_id)
  end
  
  def preview
    Customer.disable_email_sync
    do_import(false)
    Customer.enable_email_sync
    []
  end

  def import! ;  [do_import(true), []] ;   end

  def valid_records ; number_of_records ; end
  def invalid_records ; 0 ; end

  protected

  def after_initialize          # called after AR::Base makes a new obj
    self.messages ||= []
    self.messages << "Show: #{show.name}" if show
    self.vouchers = []
    self.created_customers = []
    self.matched_customers = []
    self.created_showdates = []
    self.created_vouchertypes = []
    self.existing_vouchers = 0
  end

  def do_import(really_import=false)
    begin
      transaction do
        get_ticket_orders
        if show.adjust_opening_and_closing_from_showdates
          self.messages <<
            "Show info may be adjusted: house capacity #{show.house_capacity}, run dates #{show.opening_date.to_formatted_s(:month_day_only)} - #{show.closing_date.to_formatted_s(:month_day_only)}"
        end
        # all is well!  Roll back the transaction and report results.
        raise TicketSalesImport::PreviewOnly unless really_import
        # finalize other changes
        @created_customers.each { |customer| customer.save! }
        show.save!             # saves new showdates too
      end
    rescue CSV::IllegalFormatError
      self.errors.add_to_base("Format error in .CSV file.  If you created this file on a Mac, be sure it's saved as Windows CSV.")
    rescue TicketSalesImport::PreviewOnly
      ;
    rescue TicketSalesImport::ShowNotFound
      self.errors.add_to_base("Couldn't find production name in uploaded file")
    rescue TicketSalesImport::ImportError => e
      self.errors.add_to_base(e.message)
    rescue Exception => e
      self.errors.add_to_base("Unexpected error: #{e.message} - #{e.backtrace}")
      RAILS_DEFAULT_LOGGER.info "Importing id #{self.id}: #{e.message}"
    end
    @vouchers
  end
  
  def import_customer(row,args)
    attribs = {}
    [:first_name, :last_name, :street, :city, :state, :zip, :day_phone, :email].each do |attr|
      attribs[attr] = row[args[attr]].to_s if args.has_key?(attr)
    end
    customer = Customer.new(attribs)
    customer.force_valid = customer.created_by_admin = true
    if (existing = Customer.find_unique(customer))
      customer = Customer.find_or_create!(customer) # to update other attribs
      self.matched_customers << customer unless
        (self.matched_customers.include?(customer) ||
        self.created_customers.include?(customer))
    else
      customer = Customer.find_or_create!(customer)
      self.created_customers << customer
    end
    customer
  end

  def import_showdate(row,pos)
    event_date = Time.parse(row[pos].to_s)
    unless (self.show.showdates &&
        sd = self.show.showdates.detect { |sd| sd.thedate == event_date })
      sd = Showdate.placeholder(event_date)
      self.created_showdates << sd
      self.show.showdates << sd
    end
    sd
  end

  def already_entered?(order_id)
    return nil unless (v = Voucher.find_by_external_key(order_id))
    # this voucher's already been entered.  make sure show name matches!!
    raise(TicketSalesImport::ImportError,
      "Existing order #{order_id} was already entered, but for a different show (#{v.show.name}, show ID #{v.show.id})") if v.show != self.show
    true
  end

end
