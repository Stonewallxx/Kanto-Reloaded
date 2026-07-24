#==============================================================================
# Kanto Reloaded Bug Report Workflow
#==============================================================================

begin
  require "net/http"
  require "uri"
rescue LoadError, StandardError
end

module KantoReloaded
  module BugReport
    PASTE_URL = "https://paste.rs/"
    BUG_REPORT_THREAD_URL = "https://discord.com/channels/1121345297352753243/1529078153786429552/1529078153786429552"
    MAX_REPORT_BYTES = 5 * 1024 * 1024
    NETWORK_TIMEOUT_SECONDS = 8

    class << self
      def file
        outcome = run_export
        return false unless outcome
        if outcome[:cancelled]
          KantoReloaded.toast_warning(_INTL("Bug report export cancelled."))
          return false
        end
        return handle_failure(outcome) unless outcome[:success]
        handle_success(outcome)
      rescue StandardError => e
        log_exception("File bug report failed", e)
        KantoReloaded.message(
          _INTL("Could not file the bug report.\n{1}", sanitized_error(e)),
          :theme => :error
        )
        false
      end

      def open_discord
        if platform_open_url(BUG_REPORT_THREAD_URL)
          KantoReloaded.toast_success(_INTL("Opened the Kanto Reloaded Discord thread."))
          return true
        end
        KantoReloaded.toast_warning(_INTL("The Kanto Reloaded Discord thread could not be opened."))
        false
      rescue StandardError => e
        log_exception("Open Discord thread failed", e)
        KantoReloaded.toast_warning(_INTL("The Kanto Reloaded Discord thread could not be opened."))
        false
      end

      def install
        KantoReloaded::Log.info("Bug report service ready", :framework) if defined?(KantoReloaded::Log)
        true
      end

      private

      def run_export
        if progress_ui_available? && defined?(Thread)
          return KantoReloaded::UI::Modal.with_modal do
            ExportProgressScene.new(proc { |callback| perform_export(&callback) }).main
          end
        end
        perform_export
      ensure
        KantoReloaded::UI::Modal.drain_input if defined?(KantoReloaded::UI::Modal)
      end

      def perform_export
        report_path = nil
        yield(_INTL("Creating sanitized report...")) if block_given?
        report_path = KantoReloaded::Log.export_bug_report
        raise "LatestBugReport.txt could not be created." unless report_path && File.file?(report_path)
        raise "LatestBugReport.txt is empty." if File.size(report_path).to_i <= 0
        raise "LatestBugReport.txt is too large to upload." if File.size(report_path).to_i > MAX_REPORT_BYTES
        text = File.open(report_path, "rb") { |file| file.read }
        raise "LatestBugReport.txt is not a text file." if text.include?("\0")
        yield(_INTL("Uploading sanitized report...")) if block_given?
        url = upload_to_paste(text)
        {
          :success => true,
          :path => report_path,
          :url => url
        }
      rescue StandardError => e
        {
          :success => false,
          :path => report_path,
          :error => e
        }
      end

      def upload_to_paste(text)
        content = KantoReloaded::Log.sanitize(text)
        return upload_with_httplite(content) if defined?(HTTPLite)
        return upload_with_net_http(content) if defined?(Net::HTTP) && defined?(URI)
        raise "No HTTP upload backend is available in this runtime."
      end

      def upload_with_httplite(content)
        response = HTTPLite.post_body(
          PASTE_URL,
          content,
          "text/plain",
          {
            "User-Agent" => "KantoReloaded/#{KantoReloaded.version}",
            "Content-Length" => content.bytesize.to_s
          }
        )
        status = response.is_a?(Hash) ? (response[:status] || response["status"]).to_i : 0
        raise "Paste upload failed with HTTP #{status}." unless [200, 201, 206].include?(status)
        body = response[:body] || response["body"]
        validate_url(body)
      end

      def upload_with_net_http(content)
        uri = URI.parse(PASTE_URL)
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "text/plain; charset=utf-8"
        request["User-Agent"] = "KantoReloaded/#{KantoReloaded.version}"
        request.body = content
        response = Net::HTTP.start(
          uri.host,
          uri.port,
          :use_ssl => uri.scheme == "https",
          :open_timeout => NETWORK_TIMEOUT_SECONDS,
          :read_timeout => NETWORK_TIMEOUT_SECONDS
        ) { |http| http.request(request) }
        code = response.code.to_i
        raise "Paste upload failed with HTTP #{response.code}." unless code >= 200 && code < 300
        validate_url(response.body)
      end

      def validate_url(value)
        url = value.to_s.strip
        raise "Paste upload did not return a URL." unless url =~ /\Ahttps?:\/\/[^\s]+\z/i
        url
      end

      def handle_success(outcome)
        url = outcome[:url].to_s
        link = "[Bug Report](#{url})"
        copied = platform_clipboard_write(link)
        opened = platform_open_url(BUG_REPORT_THREAD_URL)
        if copied && opened
          KantoReloaded.toast_success(
            _INTL("Bug report link copied. Discord thread opened.")
          )
        elsif copied
          KantoReloaded.toast_warning(
            _INTL("Bug report link copied, but Discord could not be opened.")
          )
        elsif opened
          KantoReloaded.toast_warning(
            _INTL("Discord opened, but the bug report link could not be copied.\n{1}", url)
          )
        else
          KantoReloaded.message(
            _INTL("Bug report uploaded, but clipboard and Discord are unavailable.\n{1}", url),
            :theme => :warning
          )
        end
        true
      end

      def handle_failure(outcome)
        error = outcome[:error]
        path = outcome[:path]
        if path && File.file?(path)
          KantoReloaded.message(
            _INTL(
              "LatestBugReport.txt was created, but it could not be uploaded.\n{1}\n{2}",
              display_path(path),
              sanitized_error(error)
            ),
            :theme => :warning
          )
        else
          KantoReloaded.message(
            _INTL("Could not create the bug report.\n{1}", sanitized_error(error)),
            :theme => :error
          )
        end
        false
      end

      def platform_clipboard_write(text)
        return false unless defined?(KantoReloaded::Platform)
        return false unless KantoReloaded::Platform.respond_to?(:clipboard_write)
        KantoReloaded::Platform.clipboard_write(text)
      rescue
        false
      end

      def platform_open_url(url)
        return false unless defined?(KantoReloaded::Platform)
        return false unless KantoReloaded::Platform.respond_to?(:open_url)
        KantoReloaded::Platform.open_url(url)
      rescue
        false
      end

      def display_path(path)
        return KantoReloaded::Platform.display_path(path) if defined?(KantoReloaded::Platform)
        File.basename(path.to_s)
      rescue
        "LatestBugReport.txt"
      end

      def sanitized_error(error)
        return _INTL("Unknown error.") unless error
        KantoReloaded::Log.sanitize("#{error.class}: #{error.message}")
      rescue
        _INTL("Unknown error.")
      end

      def progress_ui_available?
        defined?(Graphics) && defined?(Input) && defined?(Viewport) &&
          defined?(Sprite) && defined?(Bitmap) &&
          defined?(KantoReloaded::UI::PopupWindow)
      end

      def log_exception(message, exception)
        return unless defined?(KantoReloaded::Log)
        KantoReloaded::Log.exception(message, exception, channel: :framework)
      rescue
        nil
      end
    end

    class ExportProgressScene
      WIDTH = 320
      HEIGHT = 112

      def initialize(worker)
        @worker = worker
        @state = { :message => _INTL("Preparing bug report...") }
        @cancelled = false
      end

      def main
        setup
        start_worker
        update_loop
      ensure
        stop_worker if @cancelled
        dispose
      end

      private

      def setup
        @viewport = Viewport.new(
          0, 0,
          KantoReloaded::UI::PopupWindow::SCREEN_W,
          KantoReloaded::UI::PopupWindow::SCREEN_H
        )
        @viewport.z = 999_999_990
        @dim_sprite = Sprite.new(@viewport)
        @dim_sprite.bitmap = Bitmap.new(
          KantoReloaded::UI::PopupWindow::SCREEN_W,
          KantoReloaded::UI::PopupWindow::SCREEN_H
        )
        @dim_sprite.bitmap.fill_rect(
          0, 0,
          KantoReloaded::UI::PopupWindow::SCREEN_W,
          KantoReloaded::UI::PopupWindow::SCREEN_H,
          KantoReloaded::UI::PopupWindow::DIM_BG
        )
        @sprite = Sprite.new(@viewport)
        @sprite.bitmap = Bitmap.new(WIDTH, HEIGHT)
        @sprite.x = (KantoReloaded::UI::PopupWindow::SCREEN_W - WIDTH) / 2
        @sprite.y = (KantoReloaded::UI::PopupWindow::SCREEN_H - HEIGHT) / 2
        draw
      end

      def start_worker
        @thread = Thread.new do
          begin
            @state[:outcome] = @worker.call(proc { |message| @state[:message] = message.to_s })
          rescue StandardError => e
            @state[:outcome] = { :success => false, :error => e }
          ensure
            @state[:finished] = true
          end
        end
      end

      def update_loop
        loop do
          Graphics.update
          Input.update
          return @state[:outcome] if @state[:finished]
          if KantoReloaded::UI::InputRouter.input_triggered?(:BACK)
            if KantoReloaded.confirm(
              _INTL("Cancel the bug report export?"),
              :default => false,
              :z => @viewport.z + 10
            )
              @cancelled = true
              return { :cancelled => true }
            end
          end
          draw if ((Graphics.frame_count rescue 0) % 3).zero?
          sleep(0.01)
        end
      end

      def draw
        bitmap = @sprite.bitmap
        bitmap.clear
        pbSetSmallFont(bitmap) if defined?(pbSetSmallFont)
        popup = KantoReloaded::UI::PopupWindow
        draw = KantoReloaded::UI::Draw
        theme = popup::THEMES[:hr]
        draw.rounded_rect(bitmap, 0, 0, WIDTH, HEIGHT,
                          popup::PANEL_RADIUS, theme[:border])
        draw.rounded_rect(bitmap, 1, 1, WIDTH - 2, HEIGHT - 2,
                          popup::PANEL_RADIUS - 1, theme[:background])
        draw.plain_text(
          bitmap, 14, 6, WIDTH - 28, 24,
          _INTL("Exporting Bug Report"), theme[:title], 1
        )
        draw.plain_text(
          bitmap, 14, 36, WIDTH - 28, 22,
          @state[:message].to_s, theme[:text], 1, 16
        )
        draw_progress_bar(bitmap)
        if defined?(KantoReloaded::UI::HintText)
          KantoReloaded::UI::HintText.draw(
            bitmap,
            [KantoReloaded::UI::HintText.back("Cancel")],
            14, HEIGHT - 27, WIDTH - 28,
            :size => 13
          )
        end
      end

      def draw_progress_bar(bitmap)
        popup = KantoReloaded::UI::PopupWindow
        draw = KantoReloaded::UI::Draw
        x = 28
        y = 66
        width = WIDTH - 56
        draw.rounded_rect(bitmap, x, y, width, 10, 4,
                          Color.new(18, 25, 45, 230), popup::PANEL_BORDER)
        travel = [width - 58, 1].max
        offset = ((Graphics.frame_count rescue 0) * 3) % (travel * 2)
        offset = travel * 2 - offset if offset > travel
        draw.rounded_rect(bitmap, x + 3 + offset, y + 2, 52, 6, 3,
                          popup::BLUE)
      end

      def stop_worker
        return unless @thread && @thread.alive?
        @thread.kill
        @thread.join rescue nil
      rescue
        nil
      end

      def dispose
        if @dim_sprite
          @dim_sprite.bitmap.dispose if @dim_sprite.bitmap && !@dim_sprite.bitmap.disposed?
          @dim_sprite.dispose unless @dim_sprite.disposed?
        end
        if @sprite
          @sprite.bitmap.dispose if @sprite.bitmap && !@sprite.bitmap.disposed?
          @sprite.dispose unless @sprite.disposed?
        end
        @viewport.dispose if @viewport && !@viewport.disposed?
      rescue
        nil
      end
    end
  end
end

KantoReloaded::BugReport.install
