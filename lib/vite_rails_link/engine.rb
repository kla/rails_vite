# frozen_string_literal: true

require "rails/railtie"
require_relative "middleware"
require_relative "view_helper"

module ViteRailsLink
  class Engine < ::Rails::Engine
    initializer "vite_rails_link.middleware" do |app|
      app.middleware.insert_before 0, ViteRailsLink::Middleware
    end

    initializer "vite_rails_link.view_helper" do
      ActiveSupport.on_load(:action_view) do
        include ViteRailsLink::ViewHelper
      end
    end
  end
end
