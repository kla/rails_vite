# frozen_string_literal: true

require "rails/engine"
require_relative "middleware"
require_relative "view_helper"

module ViteRailsLink
  class Engine < ::Rails::Engine
    initializer "vite_rails_link.view_helper" do
      ActiveSupport.on_load(:action_view) do
        include ViteRailsLink::ViewHelper
      end
    end
  end
end
