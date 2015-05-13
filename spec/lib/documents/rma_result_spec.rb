require 'spec_helper'

module Documents
  describe RMAResult do

    let(:xml) do
      <<-XML
        <?xml version="1.0" encoding="utf-8"?>
        <RMAResultDocument
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xmlns:xsd="http://www.w3.org/2001/XMLSchema"
            xmlns="http://schemas.quietlogistics.com/V2/RMAResultDocument.xsd">
          <RMAResult
              ClientID="BONOBOS"
              BusinessUnit="BONOBOS"
              RMANumber="H11111111111"
              ReceiptDate="2015-03-16T13:02:08.667Z"
              Warehouse="DVN">
            <Line
                LineNo="1"
                ItemNumber="1111111"
                ReturnUOM="EA"
                Quantity="2"
                ProductStatus="GOOD"
                Notes=""
                OrderNumber="H11111111111"
                Reason="01" />
            <Line
                LineNo="2"
                ItemNumber="222222"
                ReturnUOM="EA"
                Quantity="1"
                ProductStatus="DAMAGED"
                Notes=""
                OrderNumber="H11111111111"
                Reason="02" />
          </RMAResult>
        </RMAResultDocument>
      XML
    end

    describe '#to_h' do
      let(:result) { RMAResult.new(xml, 'some-message-id') }

      describe 'rmas' do
        let(:rmas) { result.to_h[:rmas] }
        before do
          expect_any_instance_of(Time).to receive("strftime").and_return("20140722132344642")
        end

        specify do
          expect(rmas).to be_a Array
          expect(rmas.size).to eq 1

          rma = rmas.first

          expect(rma[:id]).to eq "H11111111111-20140722132344642"

          expect(rma[:message_id]).to eq 'some-message-id'

          expect(rma[:rma_number]).to eq 'H11111111111'
          expect(rma[:business_unit]).to eq 'BONOBOS'
          expect(rma[:receipt_date]).to eq '2015-03-16T13:02:08.667Z'
          expect(rma[:warehouse]).to eq 'DVN'

          expect(rma[:items]).to be_a Array
          expect(rma[:items].size).to eq 2

          item1 = rma[:items].first
          item2 = rma[:items].second

          expect(item1[:line_number]).to eq '1'
          expect(item1[:sku]).to eq '1111111'
          expect(item1[:quantity]).to eq '2'
          expect(item1[:product_status]).to eq 'GOOD'
          expect(item1[:order_number]).to eq 'H11111111111'

          expect(item2[:line_number]).to eq '2'
          expect(item2[:sku]).to eq '222222'
          expect(item2[:quantity]).to eq '1'
          expect(item2[:product_status]).to eq 'DAMAGED'
          expect(item2[:order_number]).to eq 'H11111111111'
        end
      end
    end
  end
end