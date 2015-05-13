class Processor
  class UnknownDocType < StandardError; end

  def initialize(bucket)
    @bucket = bucket
  end

  def process_doc(msg)
    name = msg['document_name']
    type = msg['document_type']
    message_id = msg['id']

    downloader = Downloader.new(@bucket)
    data = downloader.download(name)

    # downloader.delete_file(name)

    parse_doc(type, data, message_id)
  end

  private

  def parse_doc(type, data, message_id)
    case type
    when 'ShipmentOrderResult'
      Documents::ShipmentOrderResult.new(data, message_id)
    when 'ShipmentOrderCancelReady'
      Documents::ShipmentOrderCancelReady.new(data, message_id)
    when 'PurchaseOrderReceipt'
      # Temporarily track whether we are actually processing these
      Rollbar.info("Proceesing #{type.inspect}")
      Documents::PurchaseOrderReceipt.new(data, message_id)
    when 'RMAResultDocument'
      Documents::RMAResult.new(data, message_id)
    else
      raise UnknownDocType, type.inspect
    end
  end
end