module Documents
  class InventoryAdjustment

    def initialize(data)
      @data = data
    end

    def to_h
      {
        inventories: [inventory],
      }
    end

    private

    def inventory
      {
        id: @data['reference_number'],
        business_unit: @data['business_unit'],
        inventory_transaction_quantity: @data['inventory_transaction_quantity'],
        event_type: @data['event_type'],
        item_number: @data['item_number'],
        inventory_transaction_reason: @data['inventory_transaction_reason'],
        reference_number: @data['reference_number'],
        inventory_transaction_date: @data['inventory_transaction_date']
      }
    end
  end
end