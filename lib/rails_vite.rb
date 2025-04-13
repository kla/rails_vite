# frozen_string_literal: true

require "rails_vite/engine"

module RailsVite
  autoload :Build, "rails_vite/build"
  autoload :DevServer, "rails_vite/dev_server"
  autoload :DevServerConfig, "rails_vite/dev_server_config"
  autoload :Middleware, "rails_vite/middleware"
end
