# frozen_string_literal: true
describe ScoreProductWorker, :vcr do
  describe "#perform" do
    before do
      # Skip if using dummy AWS credentials without LocalStack
      skip_without_localstack
      
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
    end

    it "sends message to SQS risk queue" do
      # Mock SQS interactions when using LocalStack (SQS service may not be available)
      if using_dummy_credentials?
        mock_queue_url = "http://localhost:4566/000000000000/risk_queue"
        mock_sqs_client = double("Aws::SQS::Client")
        allow(Aws::SQS::Client).to receive(:new).and_return(mock_sqs_client)
        allow(mock_sqs_client).to receive(:get_queue_url).with(queue_name: "risk_queue").and_return(double(queue_url: mock_queue_url))
        expect(mock_sqs_client).to receive(:send_message).with({ queue_url: mock_queue_url, message_body: { "type" => "product", "id" => 123 }.to_s })
      else
        sqs = Aws::SQS::Client.new
        queue_url = sqs.get_queue_url(queue_name: "risk_queue").queue_url
        expect_any_instance_of(Aws::SQS::Client).to receive(:send_message).with({ queue_url:, message_body: { "type" => "product", "id" => 123 }.to_s })
      end
      
      ScoreProductWorker.new.perform(123)
    end
  end
end
