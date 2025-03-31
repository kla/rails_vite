# frozen_string_literal: true

require "rails_vite/engine"

module RailsVite
  autoload :DevServer, "rails_vite/dev_server"
  autoload :DevServerConfig, "rails_vite/dev_server_config"
  autoload :Middleware, "rails_vite/middleware"
end
