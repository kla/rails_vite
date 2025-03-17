# frozen_string_literal: true

require "pathname"
require_relative "lib/vite_rails_link/version"

Gem::Specification.new do |spec|
  spec.name          = "vite_rails_link"
  spec.version       = ViteRailsLink::VERSION
  spec.platform      = Gem::Platform::RUBY
  spec.authors       = ["Kien La"]
  spec.email         = ["la.kien+rubygems@gmail.com"]
  spec.description   = "Link Rails with Vite dev server"
  spec.summary       = "A Ruby gem to link Rails with Vite dev server"
  spec.homepage      = "https://github.com/kla/vite_rails_link"
  spec.require_paths = ["lib"]

  spec.files       = ::Dir.glob(::Pathname.new(__dir__).join("lib/**/**")).reject do |file|
    file.match(%r{^(test|spec|features)/}) || ::File.directory?(file)
  end

  spec.required_ruby_version = ">= 3.0.0"
  spec.add_dependency("railties", ">= 6.0.0")
  spec.add_dependency("faye-websocket", ">= 0.11.0")
end
