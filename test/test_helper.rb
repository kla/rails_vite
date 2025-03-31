# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "rails_vite"

require "minitest/autorun"
require "minitest/pride"
require "mocha/minitest"

# Set up Rails stub for testing
module Rails
  def self.root
    Pathname.new(File.expand_path("../", __dir__))
  end

  def self.env
    "test"
  end
end
