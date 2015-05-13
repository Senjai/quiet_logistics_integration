# ShipmentOrderCancelReady is the message we get when an entire order has been
# completely cancelled.
# Some reasons for cancellation, as per QL, include:
#   - ADDRESS - Address Verification Failed (unlikely)
#   - CUSTOMER - Customer Cancel (cancelled through the interface by Bonobos)
#   - DAMAGED - Inventory Damaged
#   - INVENTORY - Inventory Missing
#   - REQUESTED - Requested by Customer (initiated from warehouse due to request from Bonobos)
# Note that Sean Johnson of Quiet Logistics also told us:
#  "Please be aware that the order cancel reason is also only meant to be
#   informational.  In fact, a user chooses the reason when initiated at the
#   warehouse, so they can make a mistake."
# We are thinking we'll be OK with the occasional error there.
class Documents::ShipmentOrderCancelReady
  NAMESPACE = 'http://schemas.quietlogistics.com/V2/SOCancelResultDocument.xsd'

  def initialize(xml, message_id)
    @message_id = message_id
    @doc = Nokogiri::XML(xml)
    @shipment_number = @doc.xpath("//@OrderNumber").first.text
    @status = @doc.xpath("//@Status").first.text
    @reason = @doc.xpath("//@Reason").first.text
    @date_cancelled = @doc.xpath("//@DateCancelled").first.text
    @business_unit = @doc.xpath('//@BusinessUnit').first.value
    @warehouse = @doc.xpath("//@Warehouse").first.text
  end

  def to_h
    {
      quiet_logistics_order_cancels: [
        {
          id: @shipment_number,
          message_id: @message_id,
          shipment_id: @shipment_number,
          status: @status,
          reason: @reason,
          warehouse: @warehouse,
          business_unit: @business_unit,
          shorted_at: @date_cancelled,
          items: full_short_items,
        }
      ]
    }
  end

  private

  def full_short_items
    items = @doc.xpath('ql:SOCancelResult/ql:OrderDetails', 'ql' => NAMESPACE)
    items.map do |item|
      {
        ql_item_number: item['ItemNumber'],
        ordered: Integer(item['QuantityOrdered']),
        available: Integer(item['QuantityAvailable']),
      }
    end
  end

end
