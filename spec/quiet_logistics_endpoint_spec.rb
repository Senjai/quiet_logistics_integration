require 'spec_helper'

describe QuietLogisticsEndpoint do
  include Rack::Test::Methods

  before do
    ENV['ENDPOINT_KEY'] = 'x123'
  end

  def auth
    { 'HTTP_X_AUGURY_TOKEN' => 'x123', "CONTENT_TYPE" => "application/json" }
  end

  def app
    QuietLogisticsEndpoint
  end

  def json_response
    JSON.parse(last_response.body)
  end

  let(:config) do
    {
      'amazon_access_key' => '123',
      'amazon_secret_key' => '123',
    }
  end

  describe 'error handling' do
    context "when an exception occurs" do
      before do
        expect(Processor).to receive(:new).and_raise('crash')
        post '/get_data', {}.to_json, auth
      end

      describe 'response' do
        specify do
          expect(last_response.status).to eq 500

          expect(json_response['summary']).to eq 'crash'
        end
      end
    end
  end

  describe '/raise' do
    before do
      get '/raise', auth
    end

    if ENV['CIRCLECI']
      xspecify('BROKEN IN CIRCLECI')
      # TODO: Figure out why this fails in CircleCI like this:
      #   1) QuietLogisticsEndpoint /raise
      #      Failure/Error: get '/raise', auth
      #      RuntimeError:
      #        just testing
      #      # ./quiet_logistics_endpoint.rb:14:in `block in <class:QuietLogisticsEndpoint>'
      #      # ./spec/quiet_logistics_endpoint_spec.rb:48:in `block (3 levels) in <top (required)>'
    else
      specify do
        expect(last_response.status).to eq 500
        expect(json_response['summary']).to eq 'just testing'
      end
    end
  end

  describe '/get_messages' do
    let(:config) do
      super().merge(
        'ql_incoming_queue' => 'some-ql-queue',
      )
    end

    def make_request
      post '/get_messages', post_data, auth
    end

    def post_data
      {
        'request_id' => '123',
        'parameters' => config,
      }.to_json
    end

    let(:message) do
      {
        "id" => "c76dfc90-96ba-4239-a2b3-0f0ff800e502",
        "document_type" => "ShipmentOrderResult",
        "document_name" => "SoResultV2_BONOBOS_H47763445062_20150316_164132538.xml",
        "business_unit" => "BONOBOS",
      }
    end

    describe 'response' do
      before do
        expect_any_instance_of(Receiver).to receive(:receive_messages).and_yield(message)
        expect_any_instance_of(Receiver).to receive(:count).and_return(1)
        make_request
      end

      specify do
        expect(last_response.status).to eq 200

        expect(json_response['summary']).to eq 'received 1 messages'

        expect(json_response['messages']).to be_a Array
        expect(json_response['messages'].size).to eq 1

        received_message = json_response['messages'].first

        expect(received_message).to eq message
      end
    end
  end

  describe '/get_data' do
    let(:config) do
      super().merge(
        'ql_incoming_bucket' => 'some-ql-bucket',
      )
    end

    def make_request(document_type:)
      post '/get_data', post_data(document_type: document_type), auth
    end

    def stub_s3_response(response)
      stub_request(
        :get, "https://some-ql-bucket.s3.amazonaws.com/filename.xml"
      ).to_return(response)
    end

    def post_data(document_type:)
      {
        'request_id' => '123',
        'parameters' => config,
        'message' => {
          'id' => '5128fb15-b1cb-f466-7b9d-49ded61c6817',
          'document_type' => document_type,
          'document_name' => 'filename.xml',
          'business_unit' => 'MYBIZ',
        },
      }.to_json
    end

    context 'with an unhandled document type' do
      before do
        stub_s3_response(status: 200, body: "doesn't matter")
        make_request(document_type: 'FooBar')
      end

      describe 'response' do
        specify do
          expect(last_response.status).to eq 200

          expect(json_response['summary']).to eq "Cannot handle document of type FooBar"
        end
      end
    end

    context 'with a ShipmentOrderResult' do
      before do
        stub_s3_response(status: 200, body: s3_response_body)
        make_request(document_type: 'ShipmentOrderResult')
      end

      let(:s3_response_body) do
        <<-XML
          <?xml version="1.0" encoding="utf-8"?>
          <SOResult
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xmlns:xsd="http://www.w3.org/2001/XMLSchema"
              ClientID="BONOBOS"
              BusinessUnit="BONOBOS" OrderNumber="H13088556647"
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

      describe 'response' do
        specify do
          expect(last_response.status).to eq 200

          expect(json_response['summary']).to eq "Got Data for filename.xml"

          expect(json_response['shipments'].size).to eq 1
          expect(json_response['shipments'][0]['id']).to eq 'H13088556647'

          expect(json_response['quiet_logistics_cartons'].size).to eq 1
          expect(json_response['quiet_logistics_cartons'][0]['id']).to eq 'S11111111'
        end
      end
    end

    context 'with an RMAResultDocument' do
      before do
        stub_s3_response(status: 200, body: s3_response_body)
        make_request(document_type: 'RMAResultDocument')
      end

      let(:s3_response_body) do
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
                  Quantity="1"
                  ProductStatus="GOOD"
                  Notes=""
                  OrderNumber="H11111111111"
                  Reason="01" />
            </RMAResult>
          </RMAResultDocument>
        XML
      end

      describe 'response' do
        specify do
          expect(last_response.status).to eq 200

          expect(json_response['summary']).to eq "Got Data for filename.xml"

          expect(json_response['rmas'].size).to eq 1
          expect(json_response['rmas'][0]['id']).to match /^H11111111111-\d+/
        end
      end
    end
  end

  describe '/add_rma' do
    let(:config) do
      super().merge(
        'ql_outgoing_queue' => 'some-outgoing-queue',
        'ql_outgoing_bucket' => 'some-outgoing-bucket',
        'client_id' => 'BONOBOS',
        'business_unit' => 'BONOBOS',
      )
    end

    def make_request(rma:)
      post '/add_rma', post_data(rma: rma), auth
    end

    def post_data(rma:)
      {
        'request_id' => '123',
        'parameters' => config,
        'rma' => rma,
      }.to_json
    end

    def rma
      {
        "id" => "H11111111111",
        "order_id" => "311111111",
        "email" => "fredsmith@example.com",
        "cost" => 0,
        "status" => "ready",
        "stock_location" => "QLAYR",
        "shipping_method" => "UPS Ground",
        "tracking" => nil,
        "updated_at" => "2015-03-20T11:51:13Z",
        "shipped_at" => nil,
        "channel" => "spree",
        "address" => {
          "id" => 1111111,
          "firstname" => "Fred",
          "lastname" => "Smith",
          "address1" => "1234 Way",
          "address2" => "",
          "city" => "Somecity",
          "zipcode" => "12345",
          "phone" => "1111111111",
          "state_name" => nil,
          "alternative_phone" => nil,
          "company" => nil,
          "state_id" => 23,
          "country_id" => 49,
          "created_at" => "2015-03-20T11:50:52.700Z",
          "updated_at" => "2015-03-20T11:50:52.700Z",
          "user_id" => nil,
        },
        "store_code" => "BNBS",
        "shipping_address" => {
          "firstname" => "Fred",
          "lastname" => "Smith",
          "address1" => "1234 Way",
          "address2" => "",
          "zipcode" => "12345",
          "city" => "Somecity",
          "state" => "NY",
          "country" => "US",
          "phone" => "1111111111",
        },
        "items" => [
          {
            "product_id" => "15041-BK264-35",
            "name" => "Washed Chino Shorts",
            "quantity" => 1,
            "price" => 68,
            "ql_item_number" => 8888888,
            "item_number" => 1,
            "sku" => 8888888,
          },
        ],
        "line_items" => [
          {
            "product_id" => "15041-BK264-35",
            "name" => "Washed Chino Shorts",
            "quantity" => 1,
            "price" => 68,
            "ql_item_number" => 8888888,
            "item_number" => 1,
            "sku" => 8888888,
          },
        ],
        "note_value" => "XXXXX",
        "note_type" => "RETURNLABEL",
      }
    end

    describe 'response' do
      around do |example|
        Timecop.freeze { example.run }
      end

      before do
        expect_any_instance_of(Uploader).to receive(:process).and_return("some-s3-url")
        allow(SecureRandom).to receive(:uuid).and_return('some-uuid')
      end

      specify do
        expect_any_instance_of(Sender).to receive(:send_message) do |event_message|
          doc = Nokogiri::XML(event_message.to_xml)

          expect(doc.children.size).to eq 1
          event_message_element = doc.children.first

          expect(event_message_element.name).to eq 'EventMessage'

          expect(event_message_element.to_h).to eq(
            "ClientId" => "BONOBOS",
            "BusinessUnit" => "BONOBOS",
            "DocumentName" => "RMA_H11111111111_#{Time.now.strftime('%Y%m%d_%H%M%3N')}.xml",
            "DocumentType" => "RMADocument",
            "MessageId" => "some-uuid",
            "Warehouse" => "DVN",
            "MessageDate" => Time.now.utc.iso8601,
          )
        end

        make_request(rma: rma)

        expect(last_response.status).to eq 200
      end
    end
  end
end
