require 'spec_helper'

module Documents
  describe ShipmentOrderResult do
    let(:xml) do
      <<-XML
        <?xml version="1.0" encoding="utf-8"?>
        <SOResult
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
            xmlns:xsd="http://www.w3.org/2001/XMLSchema"
            ClientID="BONOBOS"
            BusinessUnit="BONOBOS"
            OrderNumber="H13088556647"
            DateShipped="2015-02-24T15:51:31.0953088Z"
            FreightCost="0"
            CartonCount="1"
            Warehouse="DVN"
            xmlns="http://schemas.quiettechnology.com/V2/SOResultDocument.xsd">
          <Line Line="1" ItemNumber="1111111" Quantity="1" ExceptionCode="" Tax="0" Total="0" SubstitutedItem="" />
          <Line Line="2" ItemNumber="2222222" Quantity="1" ExceptionCode="" Tax="0" Total="0" SubstitutedItem="" />
          <Line Line="3" ItemNumber="3333333" Quantity="1" ExceptionCode="" Tax="0" Total="0" SubstitutedItem="" />
          <Line Line="4" ItemNumber="4444444" Quantity="0" ExceptionCode="" Tax="0" Total="0" SubstitutedItem="" />
          <Carton
              CartonId="S11111111"
              TrackingId="1Z1111111111111111"
              Carrier="UPS"
              CartonNumber="1"
              ServiceLevel="GROUND"
              Weight="1.11"
              FreightCost="11.11"
              HandlingFee="0"
              Surcharge="0"
              PackageType="SINGLE">
            <Content Line="1" ItemNumber="1111111" Quantity="1" />
            <Content Line="2" ItemNumber="2222222" Quantity="1" />
          </Carton>
          <Carton
              CartonId="S22222222"
              TrackingId="1Z2222222222222222"
              Carrier="UPS"
              CartonNumber="1"
              ServiceLevel="GROUND"
              Weight="2.22"
              FreightCost="22.22"
              HandlingFee="0"
              Surcharge="0"
              PackageType="LARGE1">
            <Content Line="3" ItemNumber="3333333" Quantity="1" />
          </Carton>
          <Extension />
        </SOResult>
      XML
    end

    describe '#to_h' do
      let(:result) { ShipmentOrderResult.new(xml) }

      describe 'quiet_logistics_cartons' do
        let(:cartons) { result.to_h[:quiet_logistics_cartons] }

        it 'should have the expected properties' do
          expect(cartons).to be_a Array
          expect(cartons.size).to eq 2

          carton1 = cartons.first
          carton2 = cartons.second

          expect(carton1).to eq(
            {
              id: "S11111111",
              shipment_id: 'H13088556647',
              tracking: "1Z1111111111111111",
              warehouse: 'DVN',
              business_unit: 'BONOBOS',
              shipped_at: '2015-02-24T15:51:31.0953088Z',
              ql_line_items: [
                {
                  ql_item_number: "1111111",
                  quantity: 1,
                },
                {
                  ql_item_number: "2222222",
                  quantity: 1,
                },
              ],
            },
          )

          expect(carton2).to eq(
            {
              id: "S22222222",
              shipment_id: 'H13088556647',
              tracking: "1Z2222222222222222",
              warehouse: 'DVN',
              business_unit: 'BONOBOS',
              shipped_at: '2015-02-24T15:51:31.0953088Z',
              ql_line_items: [
                {
                  ql_item_number: "3333333",
                  quantity: 1,
                },
              ],
            },
          )
        end
      end

      describe 'quiet_logistics_partial_shorts' do
        let(:partial_shorts) { result.to_h[:quiet_logistics_partial_shorts] }

        context "when there is a partial short" do
          specify do
            expect(partial_shorts).to be_a(Array)
            expect(partial_shorts.size).to eq(1)

            partial_short = partial_shorts.first

            expect(partial_short).to eq(
              {
                id: 'H13088556647',
                shipment_id: 'H13088556647',
                warehouse: 'DVN',
                business_unit: 'BONOBOS',
                shorted_at: '2015-02-24T15:51:31.0953088Z',
                items: [
                  {
                    ql_item_number: '4444444',
                  }
                ]
              }
            )
          end
        end

        context 'when there is not a partial short' do
          let(:xml) do
            <<-XML
              <?xml version="1.0" encoding="utf-8"?>
              <SOResult
                  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                  xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                  ClientID="BONOBOS"
                  BusinessUnit="BONOBOS"
                  OrderNumber="H13088556647"
                  DateShipped="2015-02-24T15:51:31.0953088Z"
                  FreightCost="0"
                  CartonCount="1"
                  Warehouse="DVN"
                  xmlns="http://schemas.quiettechnology.com/V2/SOResultDocument.xsd">
                <Line Line="1" ItemNumber="1111111" Quantity="1" ExceptionCode="" Tax="0" Total="0" SubstitutedItem="" />
                <Carton
                    CartonId="S11111111"
                    TrackingId="1Z1111111111111111"
                    Carrier="UPS"
                    CartonNumber="1"
                    ServiceLevel="GROUND"
                    Weight="1.11"
                    FreightCost="11.11"
                    HandlingFee="0"
                    Surcharge="0"
                    PackageType="SINGLE">
                  <Content Line="1" ItemNumber="1111111" Quantity="1" />
                </Carton>
                <Extension />
              </SOResult>
            XML
          end

          specify do
            expect(partial_shorts).to be_a(Array)
            expect(partial_shorts.size).to eq(0)
          end
        end
      end

      describe 'quantity guard' do
        context 'if a quantity greater than one is detected' do
          let(:xml) do
            <<-XML
              <?xml version="1.0" encoding="utf-8"?>
              <SOResult
                  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                  xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                  ClientID="BONOBOS"
                  BusinessUnit="BONOBOS"
                  OrderNumber="H13088556647"
                  DateShipped="2015-02-24T15:51:31.0953088Z"
                  FreightCost="0"
                  CartonCount="1"
                  Warehouse="DVN"
                  xmlns="http://schemas.quiettechnology.com/V2/SOResultDocument.xsd">
                <Line Line="1" ItemNumber="1111111" Quantity="2" ExceptionCode="" Tax="0" Total="0" SubstitutedItem="" />
                <Carton
                    CartonId="S11111111"
                    TrackingId="1Z1111111111111111"
                    Carrier="UPS"
                    CartonNumber="1"
                    ServiceLevel="GROUND"
                    Weight="1.11"
                    FreightCost="11.11"
                    HandlingFee="0"
                    Surcharge="0"
                    PackageType="SINGLE">
                  <Content Line="1" ItemNumber="1111111" Quantity="2" />
                </Carton>
                <Extension />
              </SOResult>
            XML
          end

          it 'alerts us' do
            expect(Rollbar).to receive(:error).with(/QL quantity greater than 1/)
            ShipmentOrderResult.new(xml).to_h
          end
        end
      end
    end
  end
end
