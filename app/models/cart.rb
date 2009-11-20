class Cart
  require 'set'
  attr_accessor :items
  attr_accessor :total_price
  attr_accessor :comments
  attr_reader :order_number

  # number of seconds from the epoch to 1/1/2008, used to offset order ID's
  TIMEBASE = 1230796800
  def self.generate_order_id
    sprintf("%02d%d%02d", Option.value(:venue_id), Time.now.to_i - TIMEBASE,
           Time.now.usec % 37).to_i
  end

  def initialize
    @items = []
    @total_price = 0.0
    @comments = ''
    @order_number = Cart.generate_order_id
  end

  def empty!
    @items = []
    @total_price = 0.0
    @comments = ''
  end

  def is_empty?
    self.items.empty?
  end

  def vouchers_only
    self.items.select { |i| i.kind_of?(Voucher) }
  end

  def donations_only
    self.items.select { |i| i.kind_of?(Donation) }
  end

  def nondonations_only
    self.items.reject { |i| i.kind_of?(Donation) }
  end

  def gift_from(buyer)
    # mark all Vouchers (but not Donations or other stuff in cart) as a gift
    # for the given customer.
    raise "Invalid gift recipient record" unless buyer.kind_of?(Customer)
    self.vouchers_only.map { |v|  v.gift_purchaser_id = buyer.id }
  end

  def to_s
    notes = {}
    txt = self.items.map do |i|
      case
      when i.kind_of?(Voucher)
        if i.showdate_id.to_i > 0
          s=sprintf("$%6.2f  %s\n         %s",
                    i.vouchertype.price,
                    i.showdate.printable_name,
                    i.vouchertype.name)
          s << "\n         Seating request: #{i.comments}" unless i.comments.to_s.empty?
          unless i.showdate.show.patron_notes.blank?
            notes[i.showdate.show.name] = i.showdate.show.patron_notes
          end
          s
        else
          sprintf("$%6.2f  %s",
                  i.vouchertype.price,
                  i.vouchertype.name)
        end
      when i.kind_of?(Donation)
        sprintf("$%6.2f  Donation to General Fund", i.amount)
      end
    end.join("\n")
    txt << "\n"
    # add per-show notes if there
    notes.each_pair do |showname,note|
      txt << "\nSPECIAL NOTE for #{showname}:\n#{note.wrap(60)}"
    end
    txt
  end

  def add(itm,qty=1)
    if itm.kind_of?(Voucher)
      price = itm.vouchertype.price
    elsif itm.kind_of?(Donation)
      price = itm.amount
    else
      raise "Invalid item added to cart!"
    end
    self.items << itm
    self.items.sort! do |a,b|
      if a.class != b.class
        b.class.to_s <=> a.class.to_s
      elsif a.kind_of?(Voucher) && a.showdate_id.to_i > 0 && b.showdate_id.to_i > 0
        (a.showdate.show.name <=> b.showdate.show.name ||
         a.showdate.thedate <=> b.showdate.thedate)
      elsif a.kind_of?(Voucher) # subscription voucher(s)
        (a.showdate_id.to_i <=> b.showdate_id.to_i)
      else
        a.donation_fund_id <=> b.donation_fund_id
      end
    end
    self.total_price += price
  end

  def donation
    self.items.detect { |i| i.kind_of?(Donation) }
  end
end
