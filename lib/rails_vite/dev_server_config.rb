# frozen_string_literal: true

require "json"

module RailsVite
  class DevServerConfig
    def initialize
      @config = read_config
    end

    def config_file
      Rails.root.join("vite.config.ts")
    end

    def js_command
      Rails.configuration.x.rails_vite.js_command.presence || "node"
    end

    def read_config
      @read_config ||= begin
        command =
          "#{js_command} #{__dir__}/dev_server_config_loader.js '#{config_file}'"
          .gsub("yarn node .*?\n", "")
          .gsub("warning package.json: .*?\n", "")
        JSON.parse(`#{command}`)
      rescue => e
        raise "#{command} failed: #{e.message}"
      end
    end

    def running_in_docker?
      File.exist?("/.dockerenv")
    end

    def server_host
      @config.dig("server", "host") || (running_in_docker? ? "0.0.0.0" : "localhost")
    end

    def server_port
      @config.dig("server", "port") || 5173
    end

    def base
      @config.dig("base") || raise("Please set the `base` path in your vite.config.ts file")
    end
  end
end
