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

    initializer "rails_vite.assets" do
      if defined?(Rake) && Rake.application.top_level_tasks.include?('assets:precompile')
        Rake::Task["assets:precompile"].enhance do
          Rake::Task["rails_vite:build"].invoke
        end
      end
    end
  end
end
