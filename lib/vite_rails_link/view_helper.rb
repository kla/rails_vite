# frozen_string_literal: true

module ViteRailsLink
  module ViewHelper
    def vite_manifest
      Thread.current[:vite_manifest] ||= JSON.parse(File.read(Rails.root.join("public/vite/.vite/manifest.json")))
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
