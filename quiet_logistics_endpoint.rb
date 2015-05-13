Dir['./lib/**/*.rb'].each { |f| require f }

class QuietLogisticsEndpoint < EndpointBase::Sinatra::Base

  set :logging, true

  before do
    AWS.config(access_key_id: @config['amazon_access_key'],
               secret_access_key: @config['amazon_secret_key']) if request.request_method == 'POST'
  end

  get '/raise' do
    @payload = {}
    raise 'just testing'
  end

  post '/get_messages' do
    begin
      queue = @config['ql_incoming_queue']

      receiver = Receiver.new(queue)
      receiver.receive_messages { |msg| add_object :message, msg }

      result 200, "received #{receiver.count} messages"
    rescue => e
      handle_error(e, queue: queue)
    end
  end

  post '/get_data' do
    begin
      bucket = @config['ql_incoming_bucket']
      msg    = @payload['message']
      processor = Processor.new(bucket)

      begin
        processed = processor.process_doc(msg)
      rescue Processor::UnknownDocType => e
        Rollbar.error("Cannot handle document type: #{e.inspect}", payload: @payload, bucket: bucket)
        # TODO: Have this return a 4xx/5xx code?
        result 200, "Cannot handle document of type #{msg['document_type']}"
        return
      end

      processed.to_h.each do |data_type, objects|
        objects.each do |object|
          add_object(data_type, object)
        end
      end

      result 200, "Got Data for #{msg['document_name']}"
    rescue => e
      handle_error(e, bucket: bucket)
      return
    end
  end

  post '/add_shipment' do
    begin
      shipment = @payload['shipment']
      message  = Api.send_document('ShipmentOrder', shipment, outgoing_bucket, outgoing_queue, @config)
      result 200, message
    rescue => e
      handle_error(e)
    end
  end

  post '/add_purchase_order' do
    begin
      order   = @payload['purchase_order']
      message = Api.send_document('PurchaseOrder', order, outgoing_bucket, outgoing_queue, @config)
      result 200, message
    rescue => e
      handle_error(e)
    end
  end

  post '/add_product' do
    begin
      item    = @payload['product']
      message = Api.send_document('ItemProfile', item, outgoing_bucket, outgoing_queue, @config)
      result 200, message
    rescue => e
      handle_error(e)
    end
  end

  post '/add_rma' do
    begin
      rma = @payload['rma']
      message  = Api.send_document('RMADocument', rma, outgoing_bucket, outgoing_queue, @config)
      result 200, message
    rescue => e
      handle_error(e)
    end
  end

  private

  def handle_error(error, extra_params={})
    Rollbar.error(error, extra_params.merge(payload: @payload))
    result 500, error.message
  end

  def outgoing_queue
    @config['ql_outgoing_queue']
  end

  def outgoing_bucket
    @config['ql_outgoing_bucket']
  end
end
