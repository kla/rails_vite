# frozen_string_literal: true

require "net/http"
require "uri"
require "rack"

module ViteRailsLink
  # This is a stripped down version of https://github.com/ncr/rack-proxy
  class HttpProxy
    DEFAULT_READ_TIMEOUT = 60

    def initialize(host, port)
      @host = host
      @port = port
    end

    def call(env)
      source_request = Rack::Request.new(env)

      env["HTTP_HOST"] = "#{@host}:#{@port}"
      full_path = source_request.fullpath.empty? ? URI.parse(env["REQUEST_URI"]).request_uri : source_request.fullpath
      target_request = Net::HTTP.const_get(source_request.request_method.capitalize, false).new(full_path)
      target_request.initialize_http_header(self.class.extract_http_request_headers(source_request.env))

      if target_request.request_body_permitted? && source_request.body
        target_request.body_stream    = source_request.body
        target_request.content_length = source_request.content_length.to_i
        target_request.content_type   = source_request.content_type if source_request.content_type
        target_request.body_stream.rewind
      end

      read_timeout = env.delete("http.read_timeout") || DEFAULT_READ_TIMEOUT

      http = Net::HTTP.new(@host, @port)
      http.read_timeout = read_timeout

      target_response = http.start do
        http.request(target_request)
      end

      code    = target_response.code
      headers = self.class.normalize_headers(target_response.respond_to?(:headers) ? target_response.headers : target_response.to_hash)
      body    = target_response.body || [""]
      body    = [body] unless body.respond_to?(:each)

      [code, headers, body]
    end

    class << self
      def extract_http_request_headers(env)
        headers = env.reject do |k, v|
          !(/^HTTP_[A-Z0-9_\.]+$/ === k) || v.nil?
        end.map do |k, v|
          [reconstruct_header_name(k), v]
        end.then { |pairs| build_header_hash(pairs) }

        x_forwarded_for = (headers["X-Forwarded-For"].to_s.split(/, +/) << env["REMOTE_ADDR"]).join(", ")
        headers.merge!("X-Forwarded-For" => x_forwarded_for)
      end

      def normalize_headers(headers)
        mapped = headers.map do |k, v|
          [titleize(k), v.is_a?(Array) ? v.join("\n") : v]
        end
        build_header_hash(mapped.to_h)
      end

      def build_header_hash(pairs)
        if Rack.const_defined?(:Headers)
          # Rack::Headers is only available from Rack 3 onward
          ::Rack::Headers.new.tap { |headers| pairs.each { |k, v| headers[k] = v } }
        else
          # Rack::Utils::HeaderHash is deprecated from Rack 3 onward and is to be removed in 3.1
          ::Rack::Utils::HeaderHash.new(pairs)
        end
      end

      protected

      def reconstruct_header_name(name)
        titleize(name.sub(/^HTTP_/, "").gsub("_", "-"))
      end

      def titleize(str)
        str.split("-").map(&:capitalize).join("-")
      end
    end
  end
end
