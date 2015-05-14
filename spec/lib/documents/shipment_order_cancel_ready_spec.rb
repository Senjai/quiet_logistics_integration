require 'spec_helper'

module Documents
  describe ShipmentOrderResult do
    let(:xml) do
      <<-XML
        <?xml version="1.0" encoding="utf-8"?>
        <SOCancelResult
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xmlns:xsd="http://www.w3.org/2001/XMLSchema"
            ClientId="BONOBOS"
            BusinessUnit="BONOBOS"
            OrderNumber="H11111111111"
            DateCancelled="2015-05-13T02:49:53.763125Z"
            Status="SUCCESS"
            Reason="INVENTORY"
            Warehouse="DVN"
            xmlns="http://schemas.quietlogistics.com/V2/SOCancelResultDocument.xsd">
          <OrderDetails
              Line="1"
              ItemNumber="2222222"
              QuantityOrdered="1"
              QuantityAvailable="0" />
        </SOCancelResult>
      XML
    end

    describe '#to_h' do
      let(:result) { ShipmentOrderCancelReady.new(xml, 'some-message-id') }

      context 'inventory short' do
        describe 'quiet_logistics_order_cancels' do
          let(:order_cancels) { result.to_h[:quiet_logistics_order_cancels] }

          it 'should have the expected properties' do
            expect(order_cancels).to eq(
              [
                {
                  id: 'H11111111111',
                  message_id: 'some-message-id',
                  shipment_id: 'H11111111111',
                  status: 'SUCCESS',
                  reason: 'INVENTORY',
                  warehouse: 'DVN',
                  business_unit: 'BONOBOS',
                  canceled_at: '2015-05-13T02:49:53.763125Z',
                  items: [
                    {
                      ql_item_number: '2222222',
                      ordered: 1,
                      available: 0,
                    },
                  ],
                },
              ]
            )
          end
        end
      end

      context 'customer short' do
        let(:xml) do
          <<-XML
            <?xml version="1.0" encoding="utf-8"?>
            <SOCancelResult
                xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                ClientId="BONOBOS"
                BusinessUnit="BONOBOS"
                OrderNumber="H11111111111"
                DateCancelled="2015-05-13T02:49:53.763125Z"
                Status="SUCCESS"
                Reason="CUSTOMER"
                Warehouse="DVN"
                xmlns="http://schemas.quietlogistics.com/V2/SOCancelResultDocument.xsd">
              <OrderDetails
                  Line="1"
                  ItemNumber="2222222"
                  QuantityOrdered="1"
                  QuantityAvailable="1" />
              <OrderDetails
                  Line="2"
                  ItemNumber="3333333"
                  QuantityOrdered="1"
                  QuantityAvailable="1" />
            </SOCancelResult>
          XML
        end

        describe 'quiet_logistics_order_cancels' do
          let(:order_cancels) { result.to_h[:quiet_logistics_order_cancels] }

          it 'should have the expected properties' do
            expect(order_cancels).to eq(
              [
                {
                  id: 'H11111111111',
                  message_id: 'some-message-id',
                  shipment_id: 'H11111111111',
                  status: 'SUCCESS',
                  reason: 'CUSTOMER',
                  warehouse: 'DVN',
                  business_unit: 'BONOBOS',
                  canceled_at: '2015-05-13T02:49:53.763125Z',
                  items: [
                    {
                      ql_item_number: '2222222',
                      ordered: 1,
                      available: 1,
                    },
                    {
                      ql_item_number: '3333333',
                      ordered: 1,
                      available: 1,
                    },
                  ],
                },
              ]
            )
          end
        end
      end
    end

  end
end
