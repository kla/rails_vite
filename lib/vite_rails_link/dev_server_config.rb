# frozen_string_literal: true

require "json"

module ViteRailsLink
  class DevServerConfig
    def initialize
      @config = read_config
    end

    def read_config
      @read_config ||= JSON.parse(`bun run #{__dir__}/dev_server_config_loader.js`)
    rescue => e
      raise "Failed to read Vite config: #{e.message}"
    end

    def server_host
      @config.dig("server", "host") || "localhost"
    end

    def server_port
      @config.dig("server", "port") || raise("Please set the `server.port` in your vite.config.ts file")
    end

    def base
      @config.dig("base") || raise("Please set the `base` path in your vite.config.ts file")
    end
  end
end
