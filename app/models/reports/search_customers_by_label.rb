class SearchCustomersByLabel < Report

  def generate(params={})
    Customer.include('labels').where('labels.id in ?', params[:labels].keys)
  end

end
