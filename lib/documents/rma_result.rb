module Documents
  class RMAResult

    def initialize(xml, message_id)
      @message_id = message_id
      @doc  = Nokogiri::XML(xml).remove_namespaces!
      @number = @doc.xpath("//@RMANumber").first.text
      @receipt_date = @doc.xpath("//@ReceiptDate").first.text
      @warehouse = @doc.xpath("//@Warehouse").first.text
      @business_unit = @doc.xpath('//@BusinessUnit').first.value
      @doc.xpath("//@BusinessUnit").first.text
    end

    def to_h
      {
        rmas: [rma],
      }
    end

    private

    def rma
      {
        id: "#{@number}-#{Time.now.strftime('%Y%m%d%H%M%S%L')}",
        message_id: @message_id,
        rma_number: @number,
        business_unit: @business_unit,
        receipt_date: @receipt_date,
        warehouse: @warehouse,
        items: items_hash
      }
    end

    def items_hash
      @doc.xpath("//Line").collect do |item|
        {
          line_number:    item['LineNo'],
          sku:            item['ItemNumber'],
          quantity:       item['Quantity'],
          product_status: item['ProductStatus'],
          order_number:   item['OrderNumber']
        }
      end
    end
  end
end