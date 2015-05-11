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

    def initialize(xml)
      @doc = Nokogiri::XML(xml)
      @shipment_number = @doc.xpath("//@OrderNumber").first.text
      @date_shipped = @doc.xpath("//@DateShipped").first.text
      @tracking_number = @doc.xpath('//@TrackingId').first.value
      @business_unit = @doc.xpath('//@BusinessUnit').first.value
      @warehouse = @doc.xpath("//@Warehouse").first.text
    end

    def to_h
      {
        quiet_logistics_cartons: cartons,
      }
    end

    private

    def cartons
      cartons = @doc.xpath('ql:SOResult/ql:Carton', 'ql' => NAMESPACE)
      cartons.map do |carton|
        {
          :id => carton['CartonId'],
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
        {
          :ql_item_number => content['ItemNumber'],
          :quantity => Integer(content['Quantity']),
        }
      end
    end

  end
end

