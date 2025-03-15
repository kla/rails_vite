# frozen_string_literal: true

require "test_helper"
require "pathname"

class DevServerConfigTest < Minitest::Test
  def setup
    # Mock the JSON response from the config loader
    @mock_config = {
      "server" => {
        "host" => "127.0.0.1",
        "port" => 5173
      },
      "base" => "/vite/"
    }

    ViteRailsLink::DevServerConfig.any_instance.stubs(:read_config).returns(@mock_config)
    @config = ViteRailsLink::DevServerConfig.new
  end

  def test_server_host
    assert_equal "127.0.0.1", @config.server_host
  end

  def test_server_port
    assert_equal 5173, @config.server_port
  end

  def test_base
    assert_equal "/vite/", @config.base
  end

  def test_server_host_default
    config_without_host = @mock_config.dup
    config_without_host["server"].delete("host")

    ViteRailsLink::DevServerConfig.any_instance.stubs(:read_config).returns(config_without_host)
    config = ViteRailsLink::DevServerConfig.new

    assert_equal "localhost", config.server_host
  end

  def test_server_port_raises_error
    config_without_port = @mock_config.dup
    config_without_port["server"].delete("port")

    ViteRailsLink::DevServerConfig.any_instance.stubs(:read_config).returns(config_without_port)
    config = ViteRailsLink::DevServerConfig.new

    assert_raises(RuntimeError) do
      config.server_port
    end
  end

  def test_base_raises_error
    config_without_base = @mock_config.dup
    config_without_base.delete("base")

    ViteRailsLink::DevServerConfig.any_instance.stubs(:read_config).returns(config_without_base)
    config = ViteRailsLink::DevServerConfig.new

    assert_raises(RuntimeError) do
      config.base
    end
  end
end
