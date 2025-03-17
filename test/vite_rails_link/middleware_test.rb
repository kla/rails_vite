# frozen_string_literal: true

require "test_helper"
require "rack/test"

module ViteRailsLink
  class MiddlewareTest < Minitest::Test
    include Rack::Test::Methods

    def setup
      @app = lambda { |env| [200, {}, ["Hello, World!"]] }

      # Create a fully stubbed middleware to avoid loading the actual Vite config
      DevServer.stubs(:new).returns(mock_dev_server)
      WebSocketProxy.stubs(:new).returns(mock_web_socket_proxy)
      HttpProxy.stubs(:new).returns(mock_http_proxy)

      @middleware = Middleware.new(@app)
    end

    def app
      @middleware
    end

    def mock_dev_server
      @mock_dev_server ||= begin
        dev_server = mock("DevServer")
        config = mock("DevServerConfig")
        config.stubs(:server_host).returns("localhost")
        config.stubs(:server_port).returns(5173)
        config.stubs(:base).returns("/vite")
        dev_server.stubs(:config).returns(config)
        dev_server.stubs(:ensure_running).returns(nil)
        dev_server
      end
    end

    def mock_web_socket_proxy
      @mock_web_socket_proxy ||= mock("WebSocketProxy")
    end

    def mock_http_proxy
      @mock_http_proxy ||= mock("HttpProxy")
    end

    def test_pass_through_for_non_vite_paths
      mock_web_socket_proxy.expects(:call).never
      mock_http_proxy.expects(:call).never

      get "/non-vite-path"

      assert_equal 200, last_response.status
      assert_equal "Hello, World!", last_response.body
    end

    def test_http_proxy_for_vite_paths
      mock_dev_server.expects(:ensure_running).once
      Faye::WebSocket.expects(:websocket?).returns(false)
      mock_http_proxy.expects(:call).once.returns([200, {}, ["Proxied Content"]])
      mock_web_socket_proxy.expects(:call).never

      get "/vite/some-asset.js"

      assert_equal 200, last_response.status
      assert_equal "Proxied Content", last_response.body
    end

    def test_websocket_proxy_for_websocket_requests
      mock_dev_server.expects(:ensure_running).once
      Faye::WebSocket.expects(:websocket?).returns(true)
      mock_web_socket_proxy.expects(:call).once.returns([101, {}, ["WebSocket Handshake"]])
      mock_http_proxy.expects(:call).never

      # Create a WebSocket request env
      ws_env = Rack::MockRequest.env_for("/vite/@vite/client", {"HTTP_UPGRADE" => "websocket"})

      # Call the middleware directly since Rack::Test doesn't support WebSockets
      status, _headers, body = @middleware.call(ws_env)

      assert_equal 101, status
      assert_equal "WebSocket Handshake", body.first
    end
  end
end
