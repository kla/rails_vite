# frozen_string_literal: true

require "socket"

module ViteRailsLink
  class DevServer
    attr_reader :config

    def initialize
      @config = DevServerConfig.new
    end

    def debug_log(type, message)
      Rails.logger.debug("[#{self.class.name}] [#{type}] #{message}") if Rails.configuration.x.vite_rails_link.debug
    end

    def target_uri(path, query_string)
      URI::HTTP.build(
        host: config.server_host,
        port: config.server_port,
        path: path,
        query: query_string.empty? ? "" : "?#{query_string}"
      )
    end

    def lock_file
      Rails.configuration.x.vite_rails_link.lock_file.presence || Rails.root.join("tmp", "vite_dev_server.lock")
    end

    def pid_file
      Rails.configuration.x.vite_rails_link.pid_file.presence || Rails.root.join("tmp", "vite_dev_server.pid")
    end

    def log_file
      Rails.configuration.x.vite_rails_link.log_file.presence || Rails.root.join("log", "vite_dev_server.log")
    end

    def ensure_running
      return if command.blank?

      # Fast check first - if port is open, we're good to go
      return if port_open?(config.server_host, config.server_port)

      FileUtils.mkdir_p(File.dirname(lock_file))

      # Use non-blocking lock to avoid hanging requests
      File.open(lock_file, File::RDWR | File::CREAT) do |f|
        if f.flock(File::LOCK_EX | File::LOCK_NB)
          begin
            # Double-check port after acquiring lock
            unless port_open?(config.server_host, config.server_port)
              debug_log("Server", "Starting Vite dev server")
              start
            end
          ensure
            f.flock(File::LOCK_UN)
            File.unlink(lock_file) rescue nil
          end
        else
          # Another process is handling it, just wait briefly
          debug_log("Server", "Another process is starting Vite server")

          # Wait a moment for the other process to start the server
          10.times do
            sleep 0.2
            break if port_open?(config.server_host, config.server_port)
          end
        end
      end
    end

    def port_open?(host, port)
      # Set a very short timeout for quick checks
      Socket.tcp(host, port, connect_timeout: 0.1) { |socket| true }
    rescue Errno::ECONNREFUSED
      # Server is not running
      false
    rescue Errno::ETIMEDOUT, SocketError, Errno::EHOSTUNREACH
      # Connection timed out or other network issues
      false
    end

    def start
      cleanup_stale_process(pid_file)
      launch_vite_server(pid_file)
      wait_for_server_start
    end

    # Stop existing server if running
    def stop
      if File.exist?(pid_file)
        pid = File.read(pid_file).to_i
        terminate_process(pid) if pid > 0
      end
    end

    private

    def cleanup_stale_process(pid_path)
      return unless File.exist?(pid_path)

      begin
        old_pid = File.read(pid_path).to_i
        handle_existing_process(old_pid) if old_pid > 0
      rescue => e
        debug_log("Server", "Error checking old PID: #{e.message}")
      ensure
        File.unlink(pid_path) rescue nil
      end
    end

    def handle_existing_process(old_pid)
      begin
        Process.kill(0, old_pid)
        debug_log("Server", "Found running Vite server with PID #{old_pid}")
        return if port_open?(config.server_host, config.server_port)

        terminate_process(old_pid)
      rescue Errno::ESRCH
        # Process doesn't exist, just clean up the file
      end
    end

    def terminate_process(pid)
      # Check if process exists before attempting to terminate
      begin
        Process.getpgid(pid)
        debug_log("Server", "Killing Vite server process group #{pid}")

        # Kill the entire process group
        Process.kill('-TERM', pid) rescue nil
        sleep 0.5
        # Force kill any remaining processes in the group
        Process.kill('-KILL', pid) rescue nil
      rescue Errno::ESRCH
        debug_log("Server", "Process #{pid} is not a valid PID")
        return
      end

      # Wait briefly to ensure processes are cleaned up
      sleep 0.2
    end

    def command
      Rails.configuration.x.vite_rails_link.dev_server_command.presence
    end

    def launch_vite_server(pid_path)
      debug_log("Server", "Launching '#{command}'")
      pid = Process.spawn(
        "cd #{Rails.root} && #{command}",
        out: log_file.to_s,
        err: log_file.to_s,
        pgroup: true  # Create a new process group
      )

      Process.detach(pid)
      File.write(pid_path, pid.to_s)
      debug_log("Server", "Started Vite server with PID #{pid}")
    end

    def wait_for_server_start
      20.times do
        break if port_open?(config.server_host, config.server_port)
        sleep 0.2
      end
    end
  end
end
