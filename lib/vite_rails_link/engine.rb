# frozen_string_literal: true

require "rails/railtie"

module ViteRailsLink
  class Engine < ::Rails::Engine
    initializer "vite_rails_link.proxy" do |app|
      app.middleware.insert_before 0, ViteRailsLink::DevServerProxy, ssl_verify_none: true
    end
  end
end
