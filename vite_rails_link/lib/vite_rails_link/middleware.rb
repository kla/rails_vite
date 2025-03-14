# frozen_string_literal: true

require "faye/websocket"
require "net/http"
require "uri"
require "fileutils"

module ViteRailsLink
  class Middleware
    KEEPALIVE_TIMEOUT = 15

    attr_reader :dev_server

    def initialize(app)
      @app = app
      @clients = {}  # Use a hash to store client-server pairs
      @dev_server = DevServer.new
    end

    def call(env)
      return @app.call(env) unless env["PATH_INFO"].include?(dev_server.config.base)

      dev_server.ensure_running
      Faye::WebSocket.websocket?(env) ? handle_websocket(env) : handle_http_request(env)
    end

    private

    def handle_websocket(env)
      debug_log("WebSocket", "Handling WebSocket connection")

      # Create client WebSocket with appropriate subprotocols
      ws_client = Faye::WebSocket.new(env, ["vite-hmr"], {ping: KEEPALIVE_TIMEOUT})

      # Construct the full URL with the path and query parameters
      query_string = env["QUERY_STRING"].empty? ? "" : "?#{env["QUERY_STRING"]}"
      path = env["PATH_INFO"]

      # Ensure the path is correctly formatted for the Vite server
      target_url = "ws://localhost:#{dev_server.config.server_port}#{path}#{query_string}"
      debug_log("WebSocket", "Connecting to Vite server at #{target_url}")

      begin
        # Create server WebSocket with the same subprotocols as the client
        ws_server = Faye::WebSocket::Client.new(target_url, ["vite-hmr"])
        debug_log("WebSocket", "Successfully connected to Vite server")

        # Store the client-server pair
        client_id = ws_client.object_id
        @clients[client_id] = {
          client: ws_client,
          server: ws_server
        }
        debug_log("WebSocket", "Added client-server pair with ID #{client_id}. Total connections: #{@clients.size}")
      rescue => e
        debug_log("WebSocket", "Failed to connect to Vite server: #{e.message}")
        return [500, {"Content-Type" => "text/plain"}, ["Failed to connect to Vite server: #{e.message}"]]
      end

      # Use a closure to capture the logger for event handlers
      ws_client.on :message do |event|
        # Forward the message to the server
        if ws_server && ws_server.ready_state == Faye::WebSocket::API::OPEN
          debug_log("WebSocket", "Forwarding message from client to server (#{event.data.bytesize} bytes)")
          ws_server.send(event.data)
        end
      end

      ws_server.on :message do |event|
        # Forward the message to the client
        if ws_client && ws_client.ready_state == Faye::WebSocket::API::OPEN
          debug_log("WebSocket", "Forwarding message from server to client (#{event.data.bytesize} bytes)")
          ws_client.send(event.data)
        end
      end

      ws_client.on :close do |event|
        # Clean up resources
        pair = @clients.delete(client_id)
        debug_log("WebSocket", "Client connection closed (code: #{event.code}, reason: #{event.reason}). Remaining connections: #{@clients.size}")
        if pair && pair[:server]
          pair[:server].close if pair[:server].ready_state != Faye::WebSocket::API::CLOSED
        end
      end

      ws_server.on :close do |event|
        # Close the client if it's still open
        pair = @clients.find { |_, v| v[:server] == ws_server }
        debug_log("WebSocket", "Server connection closed (code: #{event.code}, reason: #{event.reason})")
        if pair && pair[1][:client]
          client = pair[1][:client]
          client.close if client.ready_state != Faye::WebSocket::API::CLOSED
          @clients.delete(pair[0])
          debug_log("WebSocket", "Closed corresponding client connection. Remaining connections: #{@clients.size}")
        end
      end

      # Return async Rack response
      debug_log("WebSocket", "Connection established")
      ws_client.rack_response
    end

    def handle_http_request(env)
      target_uri = dev_server.target_uri(env["PATH_INFO"], env["QUERY_STRING"])
      debug_log("HTTP", "Forwarding request to Vite server #{target_uri}")

      # Create a new Net::HTTP request based on the original request method
      http = Net::HTTP.new(target_uri.host, target_uri.port)
      request_class = case env["REQUEST_METHOD"]
                      when "GET"     then Net::HTTP::Get
                      when "POST"    then Net::HTTP::Post
                      when "PUT"     then Net::HTTP::Put
                      when "DELETE"  then Net::HTTP::Delete
                      when "HEAD"    then Net::HTTP::Head
                      when "OPTIONS" then Net::HTTP::Options
                      when "PATCH"   then Net::HTTP::Patch
                      else Net::HTTP::Get
                      end

      request = request_class.new(target_uri.request_uri)
      debug_log("HTTP","Created #{request_class} request")

      # Copy headers from the original request
      env.each do |key, value|
        if key.start_with?("HTTP_")
          header_name = key[5..-1].split("_").map(&:capitalize).join("-")
          request[header_name] = value
        end
      end

      # Set content type and content length if present
      request["Content-Type"] = env["CONTENT_TYPE"] if env["CONTENT_TYPE"]
      request["Content-Length"] = env["CONTENT_LENGTH"] if env["CONTENT_LENGTH"]

      # Read and set request body if present
      if ["POST", "PUT", "PATCH"].include?(env["REQUEST_METHOD"])
        request.body = env["rack.input"].read
        env["rack.input"].rewind
        debug_log("HTTP", "Added request body (#{request.body.bytesize} bytes)")
      end

      # Execute the request
      debug_log("HTTP", "Sending request to Vite server")
      begin
        response = http.request(request)
        debug_log("HTTP", "Received response from Vite server (status: #{response.code})")
      rescue => e
        debug_log("HTTP", "Error communicating with Vite server: #{e.message}")
        return [500, {"Content-Type" => "text/plain"}, ["Error communicating with Vite server: #{e.message}"]]
      end

      # Convert Net::HTTP response to Rack response
      status = response.code.to_i
      headers = {}
      response.each_header do |key, value|
        headers[key] = value unless ["transfer-encoding"].include?(key.downcase)
      end

      body = [response.body]
      debug_log("HTTP", "Returning response to client (status: #{status})")

      [status, headers, body]
    end

    def debug_log(type, message)
      Rails.logger.debug("[#{self.class.name}] [#{type}] #{message}") if Rails.configuration.x.vite_rails_link.debug
    end
  end
end
