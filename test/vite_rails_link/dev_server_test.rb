# frozen_string_literal: true

require "test_helper"
require "uri"

class DevServerTest < Minitest::Test
  def setup
    # Mock Rails configuration
    Rails.stubs(:configuration).returns(OpenStruct.new(
      x: OpenStruct.new(
        vite_rails_link: OpenStruct.new(
          debug: false,
          auto_run_dev_server: true,
          lock_file: "/tmp/vite_rails_link.lock",
          pid_file: "/tmp/vite_rails_link.pid",
          dev_server_command: "npm run dev"
        )
      )
    ))

    # Mock Rails logger
    Rails.stubs(:logger).returns(mock)
    Rails.logger.stubs(:debug)

    # Mock the config
    @mock_config = mock
    @mock_config.stubs(:server_host).returns("127.0.0.1")
    @mock_config.stubs(:server_port).returns(5173)
    @mock_config.stubs(:base).returns("/vite/")

    ViteRailsLink::DevServerConfig.stubs(:new).returns(@mock_config)

    @dev_server = ViteRailsLink::DevServer.new
  end

  def test_initialize
    assert_equal @mock_config, @dev_server.config
  end

  def test_target_uri_without_query
    uri = @dev_server.target_uri("/assets/main.js", "")

    assert_equal "127.0.0.1", uri.host
    assert_equal 5173, uri.port
    assert_equal "/assets/main.js", uri.path
    assert_equal "", uri.query
  end

  def test_target_uri_with_query
    uri = @dev_server.target_uri("/assets/main.js", "v=123")

    assert_equal "127.0.0.1", uri.host
    assert_equal 5173, uri.port
    assert_equal "/assets/main.js", uri.path
    assert_equal "?v=123", uri.query
  end

  def test_debug_log_when_debug_enabled
    Rails.configuration.x.vite_rails_link.stubs(:debug).returns(true)
    Rails.logger.expects(:debug).with("[ViteRailsLink::DevServer] [Test] Debug message")

    @dev_server.debug_log("Test", "Debug message")
  end

  def test_debug_log_when_debug_disabled
    Rails.configuration.x.vite_rails_link.stubs(:debug).returns(false)
    Rails.logger.expects(:debug).never

    @dev_server.debug_log("Test", "Debug message")
  end

  def test_ensure_running_when_auto_run_disabled
    Rails.configuration.x.vite_rails_link.stubs(:auto_run_dev_server).returns(false)
    @dev_server.expects(:port_open?).never

    @dev_server.ensure_running
  end

  def test_ensure_running_when_port_already_open
    @dev_server.stubs(:port_open?).with("127.0.0.1", 5173).returns(true)
    @dev_server.expects(:start).never

    @dev_server.ensure_running
  end
end
