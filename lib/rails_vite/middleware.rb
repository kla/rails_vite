# frozen_string_literal: true

require "faye/websocket"
require_relative "http_proxy"
require_relative "web_socket_proxy"

module RailsVite
  class Middleware
    def initialize(app)
      @app = app
      @dev_server = DevServer.new
      @web_socket_proxy = RailsVite::WebSocketProxy.new(@dev_server.config.server_host, @dev_server.config.server_port)
      @http_proxy = RailsVite::HttpProxy.new(@dev_server.config.server_host, @dev_server.config.server_port)
    end

    def relative_url_root
      return nil unless defined?(Rails) && Rails.respond_to?(:application) && Rails.application
      Rails.application.config.relative_url_root
    end

    def full_path(env)
      path = env["PATH_INFO"]
      path = "#{relative_url_root}#{path}" if relative_url_root.present? && !path.starts_with?(relative_url_root)
      path
    end

    def route_to_vite?(env)
      full_path(env).include?(@dev_server.config.base)
    end

    def call(env)
      return @app.call(env) unless route_to_vite?(env)

      @dev_server.ensure_running
      proxy = Faye::WebSocket.websocket?(env) ? @web_socket_proxy : @http_proxy
      proxy.call(env)
    end
  end
end
