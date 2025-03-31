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

    def call(env)
      return @app.call(env) unless env["PATH_INFO"].include?(@dev_server.config.base)

      @dev_server.ensure_running
      proxy = Faye::WebSocket.websocket?(env) ? @web_socket_proxy : @http_proxy
      proxy.call(env)
    end
  end
end
