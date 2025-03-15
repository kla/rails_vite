# frozen_string_literal: true

require "test_helper"
require "uri"
require "ostruct"
require "tempfile"
require "pathname"
require "json"

class DevServerTest < Minitest::Test
  def setup
    # Create temporary files for testing
    @lock_file = Tempfile.new("vite_rails_link_test_lock").path
    @pid_file = Tempfile.new("vite_rails_link_test_pid").path
    @log_file = Tempfile.new("vite_rails_link_test_log").path

    # Set up a real configuration with test values
    @config = {
      debug: false,
      auto_run_dev_server: true,
      lock_file: @lock_file,
      pid_file: @pid_file,
      log_file: @log_file,
      dev_server_command: "npm run dev"
    }

    # Only mock the Rails configuration
    Rails.stubs(:configuration).returns(OpenStruct.new(
      x: OpenStruct.new(
        vite_rails_link: OpenStruct.new(@config)
      )
    ))

    # Set up Rails.root to point to our test directory for proper path resolution
    Rails.stubs(:root).returns(Pathname.new(File.expand_path("../", __dir__)))

    # Create a Vite config that matches our fixture file - using string keys
    vite_config = {
      "base" => "/vite",
      "server" => {
        "host" => "0.0.0.0",
        "port" => 5173,
        "allowedHosts" => ["localhost"]
      }
    }

    # Use the fixture vite.config.ts file
    fixture_path = File.expand_path("../fixtures/vite.config.ts", __dir__)

    # Mock the config_file method to return our fixture path
    ViteRailsLink::DevServerConfig.any_instance.stubs(:config_file).returns(Pathname.new(fixture_path))

    # Mock the read_config method to return our fixture data
    ViteRailsLink::DevServerConfig.any_instance.stubs(:read_config).returns(vite_config)

    @dev_server = ViteRailsLink::DevServer.new
  end

  def teardown
    # Clean up temporary files
    File.unlink(@lock_file) if File.exist?(@lock_file)
    File.unlink(@pid_file) if File.exist?(@pid_file)
    File.unlink(@log_file) if File.exist?(@log_file)
  end

  def test_initialize
    assert_instance_of ViteRailsLink::DevServerConfig, @dev_server.config
    assert_equal "0.0.0.0", @dev_server.config.server_host
    assert_equal 5173, @dev_server.config.server_port
    assert_equal "/vite", @dev_server.config.base
  end

  def test_target_uri_without_query
    uri = @dev_server.target_uri("/assets/main.js", "")

    assert_equal "0.0.0.0", uri.host
    assert_equal 5173, uri.port
    assert_equal "/assets/main.js", uri.path
    assert_equal "", uri.query
  end

  def test_target_uri_with_query
    uri = @dev_server.target_uri("/assets/main.js", "v=123")

    assert_equal "0.0.0.0", uri.host
    assert_equal 5173, uri.port
    assert_equal "/assets/main.js", uri.path
    assert_equal "v=123", uri.query.sub("?", "")
  end

  def test_ensure_running_when_auto_run_disabled
    Rails.configuration.x.vite_rails_link.stubs(:auto_run_dev_server).returns(false)

    # We shouldn't check the port when auto_run is disabled
    @dev_server.stubs(:port_open?).never

    @dev_server.ensure_running
  end

  def test_ensure_running_when_port_already_open
    @dev_server.stubs(:port_open?).with("0.0.0.0", 5173).returns(true)

    # We shouldn't start the server when the port is already open
    @dev_server.expects(:start).never

    @dev_server.ensure_running
  end
end
