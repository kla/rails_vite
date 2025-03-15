# frozen_string_literal: true

require "test_helper"
require "pathname"
require "json"

class DevServerConfigTest < Minitest::Test
  def setup
    # Use the fixture vite.config.ts file instead of mocking
    fixture_path = File.expand_path("../fixtures/vite.config.ts", __dir__)

    # Set up Rails.root to point to our test directory for proper path resolution
    Rails.stubs(:root).returns(Pathname.new(File.expand_path("../", __dir__)))

    # Create a Vite config that matches our fixture file
    vite_config = {
      "base" => "/vite",
      "server" => {
        "host" => "0.0.0.0",
        "port" => 5173,
        "allowedHosts" => ["localhost"],
        "watch" => {
          "ignored" => ["**/vite.config.ts"]
        }
      }
    }

    # Mock the config_file method to return our fixture path
    ViteRailsLink::DevServerConfig.any_instance.stubs(:config_file).returns(Pathname.new(fixture_path))

    # Mock the read_config method to return our fixture data
    ViteRailsLink::DevServerConfig.any_instance.stubs(:read_config).returns(vite_config)

    @config = ViteRailsLink::DevServerConfig.new
  end

  def test_server_host
    assert_equal "0.0.0.0", @config.server_host
  end

  def test_server_port
    assert_equal 5173, @config.server_port
  end

  def test_base
    assert_equal "/vite", @config.base
  end

  def test_server_host_default
    config_without_host = {
      "server" => {
        "port" => 5173
      },
      "base" => "/vite"
    }

    ViteRailsLink::DevServerConfig.any_instance.stubs(:read_config).returns(config_without_host)
    config = ViteRailsLink::DevServerConfig.new

    assert_equal "localhost", config.server_host
  end

  def test_server_port_default
    config_without_port = {
      "server" => {
        "host" => "0.0.0.0"
      },
      "base" => "/vite"
    }

    ViteRailsLink::DevServerConfig.any_instance.stubs(:read_config).returns(config_without_port)
    config = ViteRailsLink::DevServerConfig.new

    assert_equal 5173, config.server_port
  end

  def test_base_raises_error
    config_without_base = {
      "server" => {
        "host" => "0.0.0.0",
        "port" => 5173
      }
    }

    ViteRailsLink::DevServerConfig.any_instance.stubs(:read_config).returns(config_without_base)
    config = ViteRailsLink::DevServerConfig.new

    assert_raises(RuntimeError) do
      config.base
    end
  end
end
