#==============================================================================
# Kanto Reloaded: Features
#==============================================================================
# Every Kanto Reloaded feature (Controls, Overworld Menu, Reloaded PC, ...)
# can be switched On or Off:
#
#   :on   the feature works and its settings show
#   :off  the feature does nothing; its hooks fall straight through to the
#         game's own behaviour, and its settings and menu entries hide
#
# (KIF's modules also have Hidden, to shorten its settings list. Kanto
# Reloaded's settings screen shows each page as a closed header, so it
# doesn't need one.)
#
# Changes apply at once. A feature registered with :restart => true changes
# game data while the game starts, so a change applies after a restart.
# The states are Global (every save): <mod folder>\Settings\Features.json.
#
#   Reloaded::Features.register(:controls, :name => "Controls",
#     :description => "...", :default => :on)
#   Reloaded::Features.on?(:controls)     # fast; checked by every hook
#
# A feature that raises an error is switched off for the session (see
# Hooks): its hooks fall through and the error is logged once.
#
# A feature that takes over one of KIF's says which (KIF 0.21.52's
# KIF::Features, which KIF calls replacing), and KIF's steps aside only
# while ours runs:
#
#   Reloaded::Features.register(:speed_up, :name => "Speed-Up",
#     :takes_over => ["F-UI-05_SpeedUp"])
#
# While it's On, KIF's Speed Up acts as if its module were Off (its hooks
# fall through, its settings hide) and KIF's Mods list says Kanto Reloaded
# replaces it. Off, or failed, gives KIF's back at once.
#==============================================================================

module Reloaded
  module Features
    STATES = [:off, :on].freeze
    FILE = "Features.json"

    @features = {}
    @active = {}      # id => true while the feature runs (fast lookup)
    @failed = {}      # id => the error that switched it off this session
    @states = nil
    @taken_over = []  # KIF features taken over by features that run now

    class << self
      def register(id, options = {})
        id = id.to_sym
        @features[id] = {
          :id          => id,
          :name        => options[:name] || id.to_s,
          :description => options[:description] || "",
          :group       => options[:group] || :general,
          :default     => STATES.include?(options[:default]) ? options[:default] : :on,
          :restart     => !!options[:restart],
          :core        => !!options[:core],     # can't be switched off
          :page        => options[:page],       # its settings page, if any
          :order       => options[:order] || 100,
          :takes_over  => Array(options[:takes_over]).map(&:to_s)   # KIF features it takes over
        }
        refresh(id)
        return true
      end

      def registered?(id)
        return @features.has_key?(id.to_sym)
      end

      def definition(id)
        return @features[id.to_sym]
      end

      def all
        return @features.values.sort_by { |f| [f[:order], f[:name]] }
      end

      # True while the feature runs. Called on every hooked call, so it is a
      # single hash lookup.
      def on?(id)
        return @active[id]
      end

      def state(id)
        f = @features[id.to_sym]
        return :off unless f
        return :on if f[:core]
        stored = states[id.to_s]
        return stored.to_sym if stored && STATES.include?(stored.to_sym)
        return f[:default]
      end

      def failed?(id)
        return @failed.has_key?(id.to_sym)
      end

      def failure(id)
        return @failed[id.to_sym]
      end

      def set(id, new_state)
        id = id.to_sym
        f = @features[id]
        return false unless f && !f[:core] && STATES.include?(new_state)
        old = state(id)
        return false if old == new_state
        states[id.to_s] = new_state.to_s
        save
        refresh(id)
        Reloaded::Log.info("#{f[:name]}: #{old} -> #{new_state}", :features)
        Reloaded::Events.emit(:feature_changed, :id => id, :state => new_state, :old_state => old)
        return true
      end

      # Switches a feature off for this session after an error. The stored
      # state is kept, so it runs again next session.
      def fail!(id, error, where = nil)
        id = id.to_sym
        return if @failed.has_key?(id)
        @failed[id] = error
        @active[id] = false
        name = @features[id] ? @features[id][:name] : id.to_s
        Reloaded::Log.exception("#{name} failed#{where ? " in #{where}" : ""} and is off for this session", error, :features)
        sync_kif_features
      end

      # The KIF features taken over right now.
      def taken_over
        return @taken_over.dup
      end

      # Kanto Reloaded's mod id in KIF (its folder), which KIF's Mods list
      # shows what it took over under.
      def kif_owner
        return File.basename(Reloaded::ROOT)
      end

      private

      def refresh(id)
        @active[id] = !@failed.has_key?(id) && state(id) != :off
        sync_kif_features
      end

      # KIF's features are taken over only for features that run. KIF gives
      # a mod's back all at once, so the whole set is put back each time.
      def sync_kif_features
        return unless defined?(::KIF::Features) && ::KIF::Features.respond_to?(:replace) &&
                      ::KIF::Features.respond_to?(:release)
        wanted = @features.values.select { |f| @active[f[:id]] }.flat_map { |f| f[:takes_over] }.uniq
        return if wanted == @taken_over
        ::KIF::Features.release(kif_owner) unless @taken_over.empty?
        wanted.each do |key|
          next if ::KIF::Features.replace(key, :by => "Kanto Reloaded", :owner => kif_owner)
          Reloaded::Log.warning("KIF's #{key} couldn't be taken over (see KIF_log.txt): Both versions may run", :features)
        end
        @taken_over = wanted
      rescue StandardError => e
        Reloaded::Log.exception("Taking over KIF features failed", e, :features)
      end

      def states
        @states ||= load_states
      end

      def load_states
        text = Reloaded::Paths.read_text(File.join(Reloaded::Paths.settings_dir, FILE))
        return {} if text.nil? || text.strip.empty?
        data = Reloaded::JSON.parse(text)
        return data["states"].is_a?(Hash) ? data["states"] : {}
      rescue Exception => e
        Reloaded::Log.exception("Could not read #{FILE}; using defaults", e, :features)
        return {}
      end

      def save
        text = Reloaded::JSON.generate({ "schema" => 1, "states" => states }, true)
        Reloaded::Paths.write_atomic(File.join(Reloaded::Paths.settings_dir, FILE), text)
      rescue Exception => e
        Reloaded::Log.exception("Could not write #{FILE}", e, :features)
      end
    end
  end
end
