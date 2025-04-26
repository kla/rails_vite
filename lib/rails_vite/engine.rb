# frozen_string_literal: true

require "rails/engine"
require_relative "middleware"
require_relative "view_helper"

module RailsVite
  class Engine < ::Rails::Engine
    initializer "rails_vite.view_helper" do
      ActiveSupport.on_load(:action_view) do
        include RailsVite::ViewHelper
      end
    end
  end
end
