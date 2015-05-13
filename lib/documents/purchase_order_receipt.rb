module Documents
  class PurchaseOrderReceipt

    def initialize(xml, message_id)
      @message_id = message_id
      @doc = Nokogiri::XML(xml).remove_namespaces!
      @business_unit = @doc.xpath("//@BusinessUnit").first.text
      @po_number = @doc.xpath("//@PONumber").first.value
    end

    def to_h
      {
        purchase_orders: [purchase_order],
      }
    end

    private

    def purchase_order
      {
        id: @po_number,
        message_id: @message_id,
        status: 'received',
        business_unit: @business_unit,
        line_items: assemble_items,
      }
    end

    def assemble_items
      @doc.xpath('//PoLine').collect { |child|
          { line_number: child['Line'],
            itemno: child['ItemNumber'],
            quantity: child['ReceiveQuantity'],
            receivedate: child['ReceiveDate'] } }
    end
  end
end