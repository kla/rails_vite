# frozen_string_literal: true

require "vite_rails_link/engine"

module ViteRailsLink
  autoload :DevServer, "vite_rails_link/dev_server"
  autoload :DevServerConfig, "vite_rails_link/dev_server_config"
  autoload :Middleware, "vite_rails_link/middleware"
end
