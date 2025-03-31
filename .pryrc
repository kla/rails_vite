# Add lib directory to load path
$LOAD_PATH.unshift(File.expand_path("../lib", __FILE__))

# Require the main library file
require "rails_vite"

# Set up Pry prompt (using current API)
if defined?(Rails)
  Pry.config.prompt = Pry::Prompt.new(
    "rails",
    "Rails prompt",
    [
      proc { |obj, nest_level, _| "[#{obj}] #{nest_level}> " },
      proc { |obj, nest_level, _| "[#{obj}] #{nest_level}* " }
    ]
  )
end

# You can also add custom commands or methods here that you want available in your Pry sessions
