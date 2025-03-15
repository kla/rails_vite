# frozen_string_literal: true

require "test_helper"
require "rack/test"
require "ostruct"
require "tempfile"
require "pathname"
require "json"

# Define Faye::WebSocket::API constants if not defined
unless defined?(Faye::WebSocket::API::OPEN)
  module Faye
    module WebSocket
      module API
        OPEN = 1
        CLOSED = 3
      end
    end
  end
end

# Create a custom middleware class for testing
module ViteRailsLink
  class TestMiddleware < Middleware
    def handle_websocket(env)
      ws_client = Faye::WebSocket.new(env, ["vite-hmr"], {ping: KEEPALIVE_TIMEOUT})
      query_string = env["QUERY_STRING"].empty? ? "" : "?#{env["QUERY_STRING"]}"
      path = env["PATH_INFO"]
      target_url = "ws://localhost:#{dev_server.config.server_port}#{path}#{query_string}"

      begin
        ws_server = Faye::WebSocket::Client.new(target_url, ["vite-hmr"])

        # Use client_id if available, otherwise use object_id
        client_id = ws_client.respond_to?(:client_id) ? ws_client.client_id : ws_client.object_id
        @clients[client_id] = {
          client: ws_client,
          server: ws_server
        }

        ws_client.on :message do |event|
          if ws_server && ws_server.ready_state == Faye::WebSocket::API::OPEN
            ws_server.send(event.data)
          end
        end

        ws_server.on :message do |event|
          if ws_client && ws_client.ready_state == Faye::WebSocket::API::OPEN
            ws_client.send(event.data)
          end
        end

        ws_client.on :close do |event|
          pair = @clients.delete(client_id)
          if pair && pair[:server]
            pair[:server].close if pair[:server].ready_state != Faye::WebSocket::API::CLOSED
          end
        end

        ws_server.on :close do |event|
          pair = @clients.find { |_, v| v[:server] == ws_server }
          if pair && pair[1][:client]
            client = pair[1][:client]
            client.close if client.ready_state != Faye::WebSocket::API::CLOSED
            @clients.delete(pair[0])
          end
        end

        ws_client.rack_response
      rescue => e
        [500, {"Content-Type" => "text/plain"}, ["Failed to connect to Vite server: #{e.message}"]]
      end
    end
  end
end

class MiddlewareTest < Minitest::Test
  include Rack::Test::Methods

  class DummyApp
    def call(env)
      [200, {"Content-Type" => "text/plain"}, ["Dummy App Response"]]
    end
  end

  # Custom WebSocket client class for testing
  class MockWebSocketClient
    attr_reader :client_id

    def initialize(client_id)
      @client_id = client_id
    end
  end

  def setup
    # Create temporary files for testing
    @lock_file = Tempfile.new("vite_rails_link_test_lock").path
    @pid_file = Tempfile.new("vite_rails_link_test_pid").path
    @log_file = Tempfile.new("vite_rails_link_test_log").path

    # Set up a real configuration with test values
    @config = {
      debug: true,
      auto_run_dev_server: false, # Disable auto-run for tests
      lock_file: @lock_file,
      pid_file: @pid_file,
      log_file: @log_file,
      dev_server_command: "npm run dev"
    }

    # Mock the Rails configuration
    Rails.stubs(:configuration).returns(OpenStruct.new(
      x: OpenStruct.new(
        vite_rails_link: OpenStruct.new(@config)
      )
    ))

    # Mock Rails.logger
    @logger = mock()
    Rails.stubs(:logger).returns(@logger)
    @logger.stubs(:debug)

    # Set up Rails.root to point to our test directory for proper path resolution
    Rails.stubs(:root).returns(Pathname.new(File.expand_path("../", __dir__)))

    # Create a Vite config that matches our fixture file - using string keys
    vite_config = {
      "base" => "/vite",
      "server" => {
        "host" => "localhost",
        "port" => 5173
      }
    }

    # Mock the DevServerConfig
    ViteRailsLink::DevServerConfig.any_instance.stubs(:read_config).returns(vite_config)

    # Create the middleware with a dummy app
    @app = DummyApp.new
    @middleware = ViteRailsLink::TestMiddleware.new(@app)

    # Default mock for ensure_running to avoid actual server checks
    @middleware.dev_server.stubs(:ensure_running)
  end

  def teardown
    # Clean up temporary files
    File.unlink(@lock_file) if File.exist?(@lock_file)
    File.unlink(@pid_file) if File.exist?(@pid_file)
    File.unlink(@log_file) if File.exist?(@log_file)
  end

  def app
    @middleware
  end

  def test_initialization
    assert_equal @app, @middleware.instance_variable_get(:@app)
    assert_kind_of Hash, @middleware.instance_variable_get(:@clients)
    assert_empty @middleware.instance_variable_get(:@clients)
    assert_kind_of ViteRailsLink::DevServer, @middleware.dev_server
  end

  def test_passes_through_non_vite_requests
    # Request to a non-vite path
    get "/some/other/path"

    assert_equal 200, last_response.status
    assert_equal "Dummy App Response", last_response.body
  end

  def test_handles_vite_http_requests
    # Mock the HTTP request to Vite server
    mock_response = Net::HTTPResponse.new(1.1, 200, "OK")
    mock_response.stubs(:code).returns("200")
    mock_response.stubs(:body).returns("Vite Response")
    mock_response.stubs(:each_header).yields("Content-Type", "text/html")

    Net::HTTP.any_instance.stubs(:request).returns(mock_response)

    # Request to a vite path
    get "/vite/some/asset.js"

    assert_equal 200, last_response.status
    assert_equal "Vite Response", last_response.body
    assert_equal "text/html", last_response.headers["Content-Type"]
  end

  def test_handles_vite_http_request_error
    # Mock the HTTP request to Vite server to raise an error
    Net::HTTP.any_instance.stubs(:request).raises(StandardError.new("Connection error"))

    # Request to a vite path
    get "/vite/some/asset.js"

    assert_equal 500, last_response.status
    assert_match(/Error communicating with Vite server/, last_response.body)
  end

  def test_handles_post_requests_with_body
    # Mock the HTTP request to Vite server
    mock_response = Net::HTTPResponse.new(1.1, 201, "Created")
    mock_response.stubs(:code).returns("201")
    mock_response.stubs(:body).returns("Created")
    mock_response.stubs(:each_header).yields("Content-Type", "text/plain")

    # Expect the request to include the body
    Net::HTTP.any_instance.expects(:request).with do |request|
      request.body == "test=data" && request["Content-Type"] == "application/x-www-form-urlencoded"
    end.returns(mock_response)

    # POST request to a vite path with body
    post "/vite/api/endpoint", "test=data", {"CONTENT_TYPE" => "application/x-www-form-urlencoded"}

    assert_equal 201, last_response.status
    assert_equal "Created", last_response.body
  end

  def test_copies_headers_from_original_request
    # Mock the HTTP request to Vite server
    mock_response = Net::HTTPResponse.new(1.1, 200, "OK")
    mock_response.stubs(:code).returns("200")
    mock_response.stubs(:body).returns("Vite Response")
    mock_response.stubs(:each_header).yields("Content-Type", "text/html")

    # Expect the request to include the custom header
    Net::HTTP.any_instance.expects(:request).with do |request|
      request["X-Custom-Header"] == "test-value"
    end.returns(mock_response)

    # Request to a vite path with custom header
    get "/vite/some/asset.js", {}, {"HTTP_X_CUSTOM_HEADER" => "test-value"}

    assert_equal 200, last_response.status
  end

  def test_websocket_detection
    # Mock Faye::WebSocket.websocket? to return true
    Faye::WebSocket.stubs(:websocket?).returns(true)

    # Mock the WebSocket creation and response
    mock_ws = mock()
    mock_ws.stubs(:on)
    mock_ws.stubs(:rack_response).returns([101, {}, []])
    Faye::WebSocket.stubs(:new).returns(mock_ws)

    # Mock the server WebSocket creation
    mock_server_ws = mock()
    mock_server_ws.stubs(:on)
    Faye::WebSocket::Client.stubs(:new).returns(mock_server_ws)

    # Request to a vite WebSocket path
    get "/vite/__vite_hmr"

    assert_equal 101, last_response.status
  end

  def test_websocket_connection_error
    # Mock Faye::WebSocket.websocket? to return true
    Faye::WebSocket.stubs(:websocket?).returns(true)

    # Mock the WebSocket creation
    mock_ws = mock()
    mock_ws.stubs(:on)
    Faye::WebSocket.stubs(:new).returns(mock_ws)

    # Mock the server WebSocket creation to raise an error
    Faye::WebSocket::Client.stubs(:new).raises(StandardError.new("WebSocket connection error"))

    # Request to a vite WebSocket path
    get "/vite/__vite_hmr"

    assert_equal 500, last_response.status
    assert_match(/Failed to connect to Vite server/, last_response.body)
  end

  def test_websocket_message_forwarding
    # Mock Faye::WebSocket.websocket? to return true
    Faye::WebSocket.stubs(:websocket?).returns(true)

    # Create mock event objects
    client_message_event = OpenStruct.new(data: "client message")
    server_message_event = OpenStruct.new(data: "server message")
    close_event = OpenStruct.new(code: 1000, reason: "normal")

    # Create a client ID
    client_id = 12345

    # Create a mock client with our custom class
    mock_client_ws = MockWebSocketClient.new(client_id)

    # Add the necessary stubs and expectations
    mock_client_ws.stubs(:ready_state).returns(Faye::WebSocket::API::OPEN)
    mock_client_ws.expects(:send).with("server message").at_least_once
    mock_client_ws.expects(:rack_response).returns([101, {}, []])
    mock_client_ws.expects(:on).with(:message).at_least_once.yields(client_message_event)
    mock_client_ws.expects(:on).with(:close).at_least_once.yields(close_event)

    # Mock server WebSocket
    mock_server_ws = mock()
    mock_server_ws.stubs(:ready_state).returns(Faye::WebSocket::API::OPEN)
    mock_server_ws.expects(:send).with("client message").at_least_once
    mock_server_ws.expects(:on).with(:message).at_least_once.yields(server_message_event)
    mock_server_ws.expects(:on).with(:close).at_least_once
    mock_server_ws.expects(:close).at_least_once

    # Set up the mocks
    Faye::WebSocket.stubs(:new).returns(mock_client_ws)
    Faye::WebSocket::Client.stubs(:new).returns(mock_server_ws)

    # Request to a vite WebSocket path
    get "/vite/__vite_hmr"

    assert_equal 101, last_response.status
  end

  def test_debug_log_when_debug_enabled
    # Expect debug log to be called
    @logger.expects(:debug).with("[ViteRailsLink::TestMiddleware] [Test] Test message")

    # Call the private debug_log method
    @middleware.send(:debug_log, "Test", "Test message")
  end

  def test_debug_log_when_debug_disabled
    # Change the configuration to disable debug
    Rails.configuration.x.vite_rails_link.stubs(:debug).returns(false)

    # Expect debug log to NOT be called
    @logger.expects(:debug).never

    # Call the private debug_log method
    @middleware.send(:debug_log, "Test", "Test message")
  end

  def test_ensure_running_called_for_vite_requests
    # Expect ensure_running to be called
    @middleware.dev_server.expects(:ensure_running).once

    # Mock the HTTP request to Vite server
    mock_response = Net::HTTPResponse.new(1.1, 200, "OK")
    mock_response.stubs(:code).returns("200")
    mock_response.stubs(:body).returns("Vite Response")
    mock_response.stubs(:each_header)
    Net::HTTP.any_instance.stubs(:request).returns(mock_response)

    # Request to a vite path
    get "/vite/some/asset.js"
  end

  def test_ensure_running_not_called_for_non_vite_requests
    # Expect ensure_running to NOT be called
    @middleware.dev_server.expects(:ensure_running).never

    # Request to a non-vite path
    get "/some/other/path"
  end

  def test_handles_different_http_methods
    http_methods = {
      "GET" => Net::HTTP::Get,
      "POST" => Net::HTTP::Post,
      "PUT" => Net::HTTP::Put,
      "DELETE" => Net::HTTP::Delete,
      "HEAD" => Net::HTTP::Head,
      "OPTIONS" => Net::HTTP::Options,
      "PATCH" => Net::HTTP::Patch
    }

    http_methods.each do |method_name, request_class|
      # Mock the HTTP request to Vite server
      mock_response = Net::HTTPResponse.new(1.1, 200, "OK")
      mock_response.stubs(:code).returns("200")
      mock_response.stubs(:body).returns("Vite Response")
      mock_response.stubs(:each_header)

      # Expect the correct request class to be used
      Net::HTTP.any_instance.expects(:request).with do |request|
        request.is_a?(request_class)
      end.returns(mock_response)

      # Make the request with the current method
      case method_name
      when "GET"
        get "/vite/some/asset.js"
      when "POST"
        post "/vite/some/endpoint"
      when "PUT"
        put "/vite/some/endpoint"
      when "DELETE"
        delete "/vite/some/endpoint"
      when "HEAD"
        head "/vite/some/asset.js"
      when "OPTIONS"
        options "/vite/some/asset.js"
      when "PATCH"
        patch "/vite/some/endpoint"
      end

      assert_equal 200, last_response.status
    end
  end

  def test_websocket_client_cleanup_on_client_close
    # Mock Faye::WebSocket.websocket? to return true
    Faye::WebSocket.stubs(:websocket?).returns(true)

    # Create mock event objects
    close_event = OpenStruct.new(code: 1000, reason: "normal")

    # Set up client ID
    client_id = 12345

    # Create a mock client with our custom class
    mock_client_ws = MockWebSocketClient.new(client_id)

    # Add the necessary stubs and expectations
    mock_client_ws.stubs(:ready_state).returns(Faye::WebSocket::API::OPEN)
    mock_client_ws.expects(:rack_response).returns([101, {}, []])
    mock_client_ws.expects(:on).with(:message)
    mock_client_ws.expects(:on).with(:close).yields(close_event)

    # Mock server WebSocket
    mock_server_ws = mock()
    mock_server_ws.stubs(:ready_state).returns(Faye::WebSocket::API::OPEN)
    mock_server_ws.expects(:close).once
    mock_server_ws.expects(:on).with(:message)
    mock_server_ws.expects(:on).with(:close)

    # Set up the mocks
    Faye::WebSocket.stubs(:new).returns(mock_client_ws)
    Faye::WebSocket::Client.stubs(:new).returns(mock_server_ws)

    # Request to a vite WebSocket path
    get "/vite/__vite_hmr"

    # Verify the client was removed from the clients hash
    clients = @middleware.instance_variable_get(:@clients)
    assert_empty clients
  end

  def test_websocket_client_cleanup_on_server_close
    # Mock Faye::WebSocket.websocket? to return true
    Faye::WebSocket.stubs(:websocket?).returns(true)

    # Create mock event objects
    close_event = OpenStruct.new(code: 1000, reason: "normal")

    # Set up client ID
    client_id = 12345

    # Create a mock client with our custom class
    mock_client_ws = MockWebSocketClient.new(client_id)

    # Add the necessary stubs and expectations
    mock_client_ws.stubs(:ready_state).returns(Faye::WebSocket::API::OPEN)
    mock_client_ws.expects(:rack_response).returns([101, {}, []])
    mock_client_ws.expects(:close).once
    mock_client_ws.expects(:on).with(:message)
    mock_client_ws.expects(:on).with(:close)

    # Mock server WebSocket
    mock_server_ws = mock()
    mock_server_ws.stubs(:ready_state).returns(Faye::WebSocket::API::OPEN)
    mock_server_ws.expects(:on).with(:message)
    mock_server_ws.expects(:on).with(:close).yields(close_event)

    # Set up the mocks
    Faye::WebSocket.stubs(:new).returns(mock_client_ws)
    Faye::WebSocket::Client.stubs(:new).returns(mock_server_ws)

    # Manually add the client-server pair to the clients hash
    @middleware.instance_variable_set(:@clients, {
      client_id => {
        client: mock_client_ws,
        server: mock_server_ws
      }
    })

    # Request to a vite WebSocket path
    get "/vite/__vite_hmr"

    # Verify the client was removed from the clients hash
    clients = @middleware.instance_variable_get(:@clients)
    assert_empty clients
  end
end
