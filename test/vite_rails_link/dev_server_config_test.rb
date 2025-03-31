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
    Rails.stubs(configuration: OpenStruct.new(x: OpenStruct.new(rails_vite: OpenStruct.new(js_command: "node"))))

    # Mock the config_file method to return our fixture path
    RailsVite::DevServerConfig.any_instance.stubs(:config_file).returns(Pathname.new(fixture_path))

    @config = RailsVite::DevServerConfig.new
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
    # For default value tests, we still need to stub the config
    config_without_host = {
      "server" => {
        "port" => 5173
      },
      "base" => "/vite"
    }

    RailsVite::DevServerConfig.any_instance.stubs(read_config: config_without_host, running_in_docker?: false)
    config = RailsVite::DevServerConfig.new

    assert_equal "localhost", config.server_host
  end


  def test_server_host_default_docker
    # For default value tests, we still need to stub the config
    config_without_host = {
      "server" => {
        "port" => 5173
      },
      "base" => "/vite"
    }

    RailsVite::DevServerConfig.any_instance.stubs(read_config: config_without_host, running_in_docker?: true)
    config = RailsVite::DevServerConfig.new

    assert_equal "0.0.0.0", config.server_host
  end
  def test_server_port_default
    config_without_port = {
      "server" => {
        "host" => "0.0.0.0"
      },
      "base" => "/vite"
    }

    RailsVite::DevServerConfig.any_instance.stubs(:read_config).returns(config_without_port)
    config = RailsVite::DevServerConfig.new

    assert_equal 5173, config.server_port
  end

  def test_base_raises_error
    config_without_base = {
      "server" => {
        "host" => "0.0.0.0",
        "port" => 5173
      }
    }

    RailsVite::DevServerConfig.any_instance.stubs(:read_config).returns(config_without_base)
    config = RailsVite::DevServerConfig.new

    assert_raises(RuntimeError) do
      config.base
    end
  end
end
