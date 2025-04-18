# frozen_string_literal: true


module RailsVite
  # Simplified version of https://github.com/ncr/rack-proxy
  class WebSocketProxy
    KEEPALIVE_TIMEOUT = 15

    def initialize(host, port)
      @host = host
      @port = port
      @clients = {} # stores client-server pairs
    end

    def call(env)
      # Create client WebSocket with appropriate subprotocols
      ws_client = Faye::WebSocket.new(env, ["vite-hmr"], {ping: KEEPALIVE_TIMEOUT})

      debug_log("Handling WebSocket connection from")

      # Construct the full URL with the path and query parameters
      query_string = env["QUERY_STRING"].empty? ? "" : "?#{env["QUERY_STRING"]}"
      path = env["PATH_INFO"]

      # Ensure the path is correctly formatted for the Vite server
      target_url = "ws://#{@host}:#{@port}#{path}#{query_string}"
      debug_log("Connecting to Vite server at #{target_url}")

      begin
        # Create server WebSocket with the same subprotocols as the client
        ws_server = Faye::WebSocket::Client.new(target_url, ["vite-hmr"])
        debug_log("Successfully connected to Vite server")

        # Store the client-server pair
        client_id = ws_client.object_id
        @clients[client_id] = { client: ws_client, server: ws_server }
        debug_log("Added client-server pair with ID #{client_id}. Total connections: #{@clients.size}")
      rescue => e
        debug_log("Failed to connect to Vite server: #{e.message}\n#{e.backtrace.join("\n")}")
        return [500, {"Content-Type" => "text/plain"}, ["Failed to connect to Vite server: #{e.message}"]]
      end

      # Use a closure to capture the logger for event handlers
      ws_client.on :message do |event|
        # Forward the message to the server
        if ws_server && ws_server.ready_state == Faye::WebSocket::API::OPEN
          debug_log("Forwarding message from client to server (#{event.data.bytesize} bytes)")
          ws_server.send(event.data)
        end
      end

      ws_server.on :message do |event|
        # Forward the message to the client
        if ws_client && ws_client.ready_state == Faye::WebSocket::API::OPEN
          debug_log("Forwarding message from server to client (#{event.data.bytesize} bytes)")
          ws_client.send(event.data)
        end
      end

      ws_client.on :close do |event|
        # Clean up resources
        pair = @clients.delete(client_id)
        debug_log("Client connection closed (code: #{event.code}, reason: #{event.reason}). Remaining connections: #{@clients.size}")
        if pair && pair[:server]
          pair[:server].close if pair[:server].ready_state != Faye::WebSocket::API::CLOSED
        end
      end

      ws_server.on :close do |event|
        # Close the client if it's still open
        pair = @clients.find { |_, v| v[:server] == ws_server }
        debug_log("Server connection closed (code: #{event.code}, reason: #{event.reason})")
        if pair && pair[1][:client]
          client = pair[1][:client]
          client.close if client.ready_state != Faye::WebSocket::API::CLOSED
          @clients.delete(pair[0])
          debug_log("Closed corresponding client connection. Remaining connections: #{@clients.size}")
        end
      end

      # Return async Rack response
      debug_log("Connection established")
      ws_client.rack_response
    end

    def debug_log(message)
      Rails.logger.debug("[#{self.class.name}] #{message}") if Rails.configuration.x.rails_vite.debug
    end
  end
end
