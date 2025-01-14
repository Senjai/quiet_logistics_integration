#
# A ShipmentOrderResult lists items shipped, tracking number, carrier
# information, and packaging details.
#
# The structure of the XML document is:
#
=begin
  <SOResult ...>
    <Line ... />
    <Line ... />
    <Line ... />
    <Carton ... >
      <Content ... />
      <Content ... />
    </Carton>
    <Carton ... >
      <Content ... />
    </Carton>
    <Extension />
  </SOResult>
=end
#
# See the specs for a full example.

module Documents
  class ShipmentOrderResult
    NAMESPACE = 'http://schemas.quiettechnology.com/V2/SOResultDocument.xsd'

    def initialize(xml, message_id)
      @message_id = message_id
      @doc = Nokogiri::XML(xml)
      @shipment_number = @doc.xpath("//@OrderNumber").first.text
      @date_shipped = @doc.xpath("//@DateShipped").first.text
      @tracking_number = @doc.xpath('//@TrackingId').first.value
      @business_unit = @doc.xpath('//@BusinessUnit').first.value
      @warehouse = @doc.xpath("//@Warehouse").first.text
    end

    def to_h
      {
        shipments: [shipment],
        quiet_logistics_cartons: cartons,
        quiet_logistics_partial_shorts: partial_shorts,
      }
    end

    private

    def shipment
      {
        id: @shipment_number,
        # NOTE: There may multiple tracking numbers. This is just the first.
        tracking: @tracking_number,
        warehouse: @warehouse,
        status: 'shipped',
        business_unit: @business_unit,
        shipped_at: @date_shipped,
      }
    end

    def cartons
      cartons = @doc.xpath('ql:SOResult/ql:Carton', 'ql' => NAMESPACE)
      cartons.map do |carton|
        {
          :id => carton['CartonId'],
          :message_id => @message_id,
          :shipment_id => @shipment_number,
          :tracking => carton['TrackingId'],
          :warehouse => @warehouse,
          :business_unit => @business_unit,
          :shipped_at => @date_shipped,
          :ql_line_items => carton_line_items(carton),
        }
      end
    end

    def carton_line_items(carton)
      contents = carton.xpath('ql:Content', 'ql' => NAMESPACE)
      contents.map do |content|
        quantity = Integer(content['Quantity'])
        if is_spree_shipment? && quantity > 1
          # See the code comment on #partial_short_items
          message = "QL quantity greater than 1 detected. Short ship " +
            "detection may not work correctly."
          Rollbar.error(message, shipment: @shipment_number, carton: carton['CartonId'])
        end
        {
          :ql_item_number => content['ItemNumber'],
          :quantity => quantity,
        }
      end
    end

    def partial_shorts
      items = partial_short_items
      if items.any?
        [
          {
            id: @shipment_number,
            message_id: @message_id,
            shipment_id: @shipment_number,
            warehouse: @warehouse,
            business_unit: @business_unit,
            shorted_at: @date_shipped,
            items: partial_short_items,
          }
        ]
      else
        []
      end
    end

    # NOTE: This depends on us never sending anything with quantity > 1 to
    # QuietLogistics.  This is currently the case.  If it were not the case
    # this codebase would not currently be able to figure out what items were
    # shorted because it doesn't know how many were originally requested and
    # Quiet does not send that information.
    def partial_short_items
      lines = @doc.xpath('ql:SOResult/ql:Line', 'ql' => NAMESPACE)
      lines = lines.select { |l| Integer(l['Quantity']) == 0 }
      lines.map do |line|
        {
          ql_item_number: line['ItemNumber'],
        }
      end
    end

    def is_spree_shipment?
      !@shipment_number.start_with?('W', 'T')
    end
  end
end

