# frozen_string_literal: true

require "test_helper"
require "json"

class ViewHelperTest < Minitest::Test
  class DummyView
    include ViteRailsLink::ViewHelper

    def tag
      Tag.new
    end

    def raw(content)
      content
    end

    class Tag
      def script(options = {})
        "<script type=\"#{options[:type]}\" src=\"#{options[:src]}\"></script>"
      end

      def link(options = {})
        "<link rel=\"#{options[:rel]}\" href=\"#{options[:href]}\">"
      end
    end
  end

  def setup
    @view = DummyView.new
    @manifest_path = Rails.root.join("public/vite/.vite/manifest.json")

    # Mock Rails.env
    Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new("development"))

    # Reset thread variable
    Thread.current[:vite_manifest] = nil
  end

  def test_vite_manifest
    manifest_content = {
      "src/main.ts" => {
        "file" => "assets/main-1234abcd.js",
        "css" => ["assets/main-5678efgh.css"]
      }
    }

    File.stubs(:read).with(@manifest_path).returns(JSON.generate(manifest_content))

    assert_equal manifest_content, @view.vite_manifest

    # Test caching
    File.expects(:read).never
    assert_equal manifest_content, @view.vite_manifest
  end

  def test_vite_manifest_file_not_found
    File.stubs(:read).with(@manifest_path).raises(Errno::ENOENT.new("File not found"))

    error = assert_raises(Errno::ENOENT) do
      @view.vite_manifest
    end

    assert_match(/Vite manifest not found and is required for production/, error.message)
  end

  def test_vite_client_tag_in_development
    Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new("development"))

    expected = '<script type="module" src="/vite/@vite/client"></script>'
    assert_equal expected, @view.vite_client_tag
  end

  def test_vite_client_tag_in_production
    Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new("production"))

    assert_nil @view.vite_client_tag
  end

  def test_vite_javascript_tag_in_development
    Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new("development"))

    expected = '<script type="module" src="/vite/src/main.ts"></script>'
    assert_equal expected, @view.vite_javascript_tag("src/main.ts")
  end

  def test_vite_javascript_tag_in_production
    Rails.stubs(:env).returns(ActiveSupport::StringInquirer.new("production"))

    manifest_content = {
      "src/main.ts" => {
        "file" => "assets/main-1234abcd.js",
        "css" => ["assets/main-5678efgh.css"]
      }
    }

    @view.stubs(:vite_manifest).returns(manifest_content)

    expected = '<script type="module" src="/vite/assets/main-1234abcd.js"></script>' +
               '<link rel="stylesheet" href="/vite/assets/main-5678efgh.css">'

    assert_equal expected, @view.vite_javascript_tag("src/main.ts")
  end
end
