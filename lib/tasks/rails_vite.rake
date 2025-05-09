# frozen_string_literal: true

namespace :rails_vite do
  namespace :dev_server do
    desc "Restart Vite dev server"
    task restart: :environment do
      puts "Stopping Vite dev server..."
      RailsVite::DevServer.new.stop
      puts "Vite dev server will restart automatically on next request."
    end
  end

  desc "Build Vite assets"
  task build: :environment do
    RailsVite::Build.run
  end

  if Rake::Task.task_defined?("assets:precompile")
    Rake::Task["assets:precompile"].enhance do |task|
      Rake::Task["rails_vite:build"].invoke
    end
  end
end
