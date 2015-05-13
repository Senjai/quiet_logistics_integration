require 'spec_helper'

module Documents
  describe PurchaseOrderReceipt do
    let(:xml) do
      <<-XML
        <?xml version="1.0" encoding="utf-8"?>
        <POReceiptDocument
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xmlns:xsd="http://www.w3.org/2001/XMLSchema"
            xmlns="http://schemas.quietlogistics.com/V2/POReceiptDocument.xsd">
          <POReceipt
              ClientId="BONOBOS"
              BusinessUnit="BONOBOS"
              PONumber="12735_AI-48069"
              AltPONumber="12735">
            <PoLine
                Line="1"
                ItemNumber="1111111"
                ReceiveQuantity="5"
                ReceiveDate="2015-05-12T14:12:43.473125Z"
                Status="RECD"
                Warehouse="DVN"
                CartonId="">
              <Extension />
            </PoLine>
            <PoLine
                Line="2"
                ItemNumber="2222222"
                ReceiveQuantity="10"
                ReceiveDate="2015-05-12T14:12:43.473125Z"
                Status="RECD"
                Warehouse="DVN"
                CartonId="">
              <Extension />
            </PoLine>
          </POReceipt>
        </POReceiptDocument>
      XML
    end

    describe '#to_h' do
      let(:result) { PurchaseOrderReceipt.new(xml) }

      describe 'purchase_orders' do
        let(:purchase_orders) { result.to_h[:purchase_orders] }

        specify do
          expect(purchase_orders).to be_a Array
          expect(purchase_orders.size).to eq 1

          purchase_order = purchase_orders.first

          expect(purchase_order).to eq(
            id: "12735_AI-48069",
            status: 'received',
            business_unit: 'BONOBOS',
            line_items: [
              {
                line_number: '1',
                itemno: '1111111',
                quantity: '5',
                receivedate: '2015-05-12T14:12:43.473125Z',
              },
              {
                line_number: '2',
                itemno: '2222222',
                quantity: '10',
                receivedate: '2015-05-12T14:12:43.473125Z',
              },
            ],
          )
        end
      end
    end
  end

end
