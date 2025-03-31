# frozen_string_literal: true

module RailsVite
  module ViewHelper
    @@vite_manifest = nil
    @@manifest_last_modified = nil
    @@manifest_mutex = Mutex.new

    def vite_manifest
      manifest_path = Rails.root.join("public/vite/.vite/manifest.json")
      current_mtime = File.exist?(manifest_path) ? File.mtime(manifest_path) : nil

      # Quick check without mutex
      return @@vite_manifest if @@vite_manifest && current_mtime == @@manifest_last_modified

      # If we need to update, use mutex to ensure thread safety
      @@manifest_mutex.synchronize do
        # Check again within the mutex to avoid race conditions
        if @@vite_manifest.nil? || current_mtime != @@manifest_last_modified
          @@manifest_last_modified = current_mtime
          @@vite_manifest = JSON.parse(File.read(manifest_path))
        end
      end

      @@vite_manifest
    rescue Errno::ENOENT => e
      raise e, "Vite manifest not found and is required for production. Please enable `build.manifest` (see https://vite.dev/guide/backend-integration)"
    end

    def vite_client_tag
      tag.script(type: "module", src: "/vite/@vite/client") unless Rails.env.production?
    end

    def vite_javascript_tag(name)
      name_with_ext = File.extname(name).empty? ? "#{name}.js" : name

      if Rails.env.production? && (manifest = vite_manifest[name_with_ext])
        tag.script(type: "module", src: "/vite/#{manifest["file"]}") +
          raw(manifest["css"].map { |css| tag.link(rel: "stylesheet", href: "/vite/#{css}") }.join("\n"))
      else
        tag.script(type: "module", src: "/vite/#{name_with_ext}")
      end
    end
  end
end
