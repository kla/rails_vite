# frozen_string_literal: true

module RailsVite
  class Build
    def self.build_command
      Rails.configuration.x.rails_vite.build_command.presence || "npm run build"
    end

    def self.run
      command = build_command
      puts "Building Vite assets with: #{command}"
      system(command, exception: true)
    end
  end
end
