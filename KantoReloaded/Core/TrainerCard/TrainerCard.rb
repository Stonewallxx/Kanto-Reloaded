# encoding: utf-8
#==============================================================================
# Kanto Reloaded: A New Trainer Card
#==============================================================================
# Roadmap topic trainer-card (his picks, 2026-10-28). PIF's background art
# with no frame, a mat in the art's edge colour around it, plates by Theme
# Mode (Glass White on Light, Glass Charcoal on Dark), made stronger on busy
# or dark art; words in PIF's own colours with their shadows (not on tags,
# badges, hints or the ID). Tabs: Front (a lanyard ID), Records, Stats,
# Style and Unlocks.
#
# Only the scene is replaced, as the Party Screen: whenever the game makes a
# PokemonTrainerCard_Scene while Reloaded Trainer Card is On (Reloaded
# Systems), it gets Kanto Reloaded's subclass (UI/TrainerCardScene.rb).
# PokemonTrainerCardScreen still runs it, so every way in (PIF's pause menu,
# Kanto Reloaded's Pause Menu, the Overworld Menu, a mod's own call) opens
# it. If it fails to open, the log says why and PIF's card opens. Off gives
# PIF's card back at once. The counting (Counters.rb) runs either way.
#
# The background stays PIF's own ($Trainer.card_background), so PIF's card
# and its Printers stay in step. Kanto Reloaded's own data is in the save's
# "trainer_card" section.
#
#   Reloaded::TrainerCard.open                 # the card, faded in
#==============================================================================

module Reloaded
  module TrainerCard
    TOGGLE = :"systems.trainer_card"
    SECTION = :trainer_card
    DEFAULT_TITLE = "Pokémon Trainer"            # PIF's own word for the player
    FOLDER = "Trainer Cards"                     # Save as Image, in the mod folder
    BG_DIR = "Graphics/Pictures/Trainer Card/backgrounds"
    ART = [24, 20, 488, 372].freeze              # PIF's art in its 512 x 384 pictures (its frame covered the rest)
    # The plates' strength: Light's Glass White and Dark's Glass Charcoal,
    # from the picked glass to the strongest busy or dark art needs (his
    # pick, art-aware)
    GLASS = { :light => [150, 215], :dark => [200, 235] }.freeze
    # Where the Front's plates sit: what the art is measured under
    PLATES = [[40, 56, 232, 356], [296, 252, 474, 304]].freeze
    # PIF's text colours by name (getSkinColor's numbers)
    SKINS = { "Blue" => 1, "Red" => 2, "Green" => 3, "Cyan" => 4, "Magenta" => 5, "Yellow" => 6, "Grey" => 7,
              "White" => 8, "Purple" => 9, "Orange" => 10 }.freeze
    # Run Tags' colours (the New Game Setup prep's): Randomized amber,
    # Nuzlocke pink; the difficulty's and Debug's are Difficulty's
    TAG_RGB = { :randomized => [240, 170, 60], :nuzlocke => [240, 130, 160], :easy => [120, 230, 150],
                :normal => [130, 190, 250], :hard => [240, 100, 90] }.freeze
    # PIF's numbers, if its names aren't there
    NUMBERS = { :SWITCH_BEAT_THE_LEAGUE => 12, :SWITCH_RANDOMIZED_AT_LEAST_ONCE => 855, :VAR_FUSE_COUNTER => 126,
                :VAR_NB_EGGS_HATCHED => 298, :VAR_STAT_LEADER_REMATCH => 162 }.freeze

    class << self
      # Set once Kanto Reloaded's card has failed: PIF's for the rest of the
      # session
      attr_accessor :failed

      def boot
        register_settings
        Reloaded::SaveStore.register(SECTION)
        Counters.boot             # always counting, the card On or Off (his pick)
        Unlocks.boot
        install
        register_menu_entries
        Reloaded::Hooks.needs(:kif_option, :ch_nuzlocke, :id => :trainer_card_nuzlocke)
        return true
      end

      def register_settings
        Reloaded::Settings.register(TOGGLE, :page => :systems, :priority => 38, :type => :toggle, :default => true, :preset => false,
          :name => "Reloaded Trainer Card",
          :description => "Kanto Reloaded's Trainer Card: A lanyard ID, Records, Stats, a Dressing Room and Unlocks. Off shows the game's own; " \
                          "its counts keep going either way.")
      end

      def enabled?
        return Reloaded::Settings.get(TOGGLE) ? true : false
      rescue StandardError
        return false
      end

      def active?
        return enabled? && !@failed && Reloaded::Pixel.available? && defined?(Reloaded::TrainerCardScene) ? true : false
      end

      def install
        return if @installed || !defined?(::PokemonTrainerCard_Scene)
        @installed = true
        Reloaded::Hooks.prepend(nil, ::PokemonTrainerCard_Scene.singleton_class, SceneChoice, :id => :trainer_card_scene)
      end

      # Kanto Reloaded's scene class: a subclass of the game's, made the
      # first time it's needed. What watches the game's card (Recent Steps,
      # the Timing Profiler) watches ours too.
      def scene_class
        return @scene_class if @scene_class
        k = Class.new(::PokemonTrainerCard_Scene) { include Reloaded::TrainerCardScene }
        Reloaded::Hooks.scene_class(::PokemonTrainerCard_Scene, k)
        return @scene_class = k
      end

      # The card, as PIF's pause menu opens it
      def open
        run = proc { ::PokemonTrainerCardScreen.new(::PokemonTrainerCard_Scene.new).pbStartScreen }
        defined?(pbFadeOutIn) ? pbFadeOutIn(&run) : run.call
      end

      # The Overworld Menu: an action players add themselves (his pick,
      # In the Pool Only)
      def register_menu_entries
        return unless defined?(Reloaded::OverworldMenu)
        Reloaded::OverworldMenu.register(:trainer_card, :name => "Trainer Card", :kind => :action, :priority => 75, :home => false,
          :description => "The Trainer Card: The ID, records, stats and style.",
          :handler => proc { |menu| open; menu.refresh rescue nil; nil })
      end

      #------------------------------------------------------------------------
      # The save's data
      #------------------------------------------------------------------------
      # Kanto Reloaded's card data in this save (an empty Hash when nothing's
      # loaded, so a preview reads defaults)
      def data
        return Reloaded::SaveStore.section(SECTION) || {}
      end

      def title
        return Unlocks.name(:titles, Unlocks.title_id)
      end

      #------------------------------------------------------------------------
      # The game's numbers
      #------------------------------------------------------------------------
      def number(name)
        return ::Object.const_defined?(name) ? ::Object.const_get(name) : NUMBERS[name]
      end

      def switch?(name)
        id = number(name)
        return id && $game_switches && $game_switches[id] ? true : false
      rescue StandardError
        return false
      end

      def variable(name)
        id = number(name)
        return id && $game_variables ? $game_variables[id].to_i : 0
      rescue StandardError
        return 0
      end

      def league?
        return switch?(:SWITCH_BEAT_THE_LEAGUE)
      end

      def money
        return $Trainer ? $Trainer.money.to_i : 0
      end

      # Multiplayer's Platinum, only while Multiplayer is installed (its
      # cached balance; Multiplayer's own code is never changed)
      def platinum?
        return defined?(::MultiplayerPlatinum) && ::MultiplayerPlatinum.respond_to?(:cached_balance) ? true : false
      end

      def platinum
        return (::MultiplayerPlatinum.cached_balance rescue 0).to_i
      end

      # The Pokédex's size: its base Pokémon
      def dex_size
        n = defined?(::Settings::NB_POKEMON) ? ::Settings::NB_POKEMON : (defined?(::NB_POKEMON) ? ::NB_POKEMON : 0)
        return [n.to_i, 1].max
      end

      # How many of them are owned (his pick: owned of the Pokédex's size):
      # each base Pokémon owned on its own, or as the head or body of a
      # fusion owned. Worked out once when the card opens.
      def dex_owned
        dex = $Trainer && $Trainer.pokedex
        return 0 unless dex
        size = dex_size
        standard = dex.instance_variable_get(:@owned_standard)
        fusion = dex.instance_variable_get(:@owned_fusion)
        return [dex.owned_count.to_i, size].min unless standard.is_a?(Array)
        got = Array.new(size + 1, false)
        standard.each_with_index { |o, i| got[i] = true if o && i <= size }
        if fusion.is_a?(Array)
          fusion.each_with_index do |bodies, head|
            next unless bodies.is_a?(Array)
            bodies.each_with_index do |o, body|
              next unless o
              got[head] = true if head <= size
              got[body] = true if body <= size
            end
          end
        end
        return got[1..-1].count(true)
      rescue StandardError => e
        Reloaded::Log.warning_once("The Trainer Card couldn't count the Pokédex: #{e.message}", :trainer_card)
        return 0
      end

      # Play time as PIF's card counts it
      def play_seconds
        return (Graphics.frame_count / Graphics.frame_rate).to_i
      rescue StandardError
        return 0
      end

      def play_words
        s = play_seconds
        h = s / 3600
        m = s / 60 % 60
        return h > 0 ? _INTL("{1}h {2}m", h, m) : _INTL("{1}m", m)
      end

      # When the run started (PIF writes it when its card is drawn; Kanto
      # Reloaded's only reads it)
      def started
        t = $PokemonGlobal ? $PokemonGlobal.startTime : nil
        return t.is_a?(Time) ? t : nil
      rescue StandardError
        return nil
      end

      def started_words
        t = started
        return "-" unless t
        month = defined?(pbGetAbbrevMonthName) ? pbGetAbbrevMonthName(t.mon) : t.strftime("%b.")
        return "#{month} #{t.day}, #{t.year}"
      end

      # Run Tags, live from the game (his pick): [[label, colour], ...]
      def run_tags
        out = []
        out << [_INTL("RANDOMIZED"), TAG_RGB[:randomized]] if randomized?
        out << [_INTL("NUZLOCKE"), TAG_RGB[:nuzlocke]] if nuzlocke?
        if defined?(Reloaded::Difficulty)
          d = Reloaded::Difficulty
          i = (d.shown rescue nil)
          out << [_INTL(d.shown_name(i).to_s).upcase, TAG_RGB[[:easy, :normal, :hard][i]]] if i.is_a?(Integer) && i.between?(0, 2)
          out << [_INTL("DEBUG"), d::DEBUG_COLOUR] if (d.debug? rescue false)
        end
        return out
      end

      def randomized?
        return true if switch?(:SWITCH_RANDOMIZED_AT_LEAST_ONCE)
        run = defined?(Reloaded::NewGameSetup) ? (Reloaded::NewGameSetup.run rescue nil) : nil
        return run && run["mode"].to_s == "randomized" ? true : false
      end

      def nuzlocke?
        return ::KIF::Nuzlocke.on? ? true : false if defined?(::KIF::Nuzlocke) && ::KIF::Nuzlocke.respond_to?(:on?)
        return $PokemonSystem && $PokemonSystem.respond_to?(:ch_nuzlocke) && $PokemonSystem.ch_nuzlocke == 1 ? true : false
      rescue StandardError
        return false
      end

      # The badges owned (16: Kanto, then Johto)
      def badge?(i)
        return $Trainer && $Trainer.badges && $Trainer.badges[i] ? true : false
      end

      #------------------------------------------------------------------------
      # The Showcase (his pick: any of yours, party or PC, kept by personal
      # ID; a slot whose Pokémon is gone falls back to the party)
      #------------------------------------------------------------------------
      def showcase
        picks = Array(data["showcase"])
        mons = owned_pokemon
        out = Array.new(3)
        picks.first(3).each_with_index do |pid, i|
          next unless pid
          out[i] = mons.find { |pk| (pk.personalID rescue nil) == pid }
        end
        party = self.party.reject { |pk| (pk.egg? rescue true) }
        out.each_index do |i|
          next if out[i]
          out[i] = party.find { |pk| !out.include?(pk) }
        end
        return out
      end

      def party
        return Array($Trainer && $Trainer.respond_to?(:party) ? $Trainer.party : []).compact
      end

      # The party, then every box
      def owned_pokemon
        out = party
        st = $PokemonStorage
        if st
          st.maxBoxes.times do |b|
            next unless st[b]
            st.maxPokemon(b).times { |i| (pk = st[b, i]) && out << pk }
          end
        end
        return out.reject { |pk| (pk.egg? rescue true) }
      rescue StandardError
        return party
      end

      #------------------------------------------------------------------------
      # PIF's words: its colours, read from the game when the card opens
      #------------------------------------------------------------------------
      # [base, shadow] of PIF's light-background colour by name ("Dark": its
      # default dark words)
      def skin(name)
        @skins ||= {}
        return @skins[name] if @skins[name]
        pair = nil
        if name == "Dark"
          pair = [::MessageConfig::DARK_TEXT_MAIN_COLOR, ::MessageConfig::DARK_TEXT_SHADOW_COLOR] if defined?(::MessageConfig::DARK_TEXT_MAIN_COLOR)
          pair ||= [Color.new(80, 80, 88), Color.new(160, 160, 168)]
        else
          tag = (getSkinColor(nil, SKINS[name], false) rescue "").to_s
          hexes = tag.scan(/[0-9A-Fa-f]{6}/)
          pair = hexes.length >= 2 ? hexes.first(2).map { |h| hex(h) } : [Color.new(80, 80, 88), Color.new(160, 160, 168)]
        end
        return @skins[name] = pair
      end

      def hex(h)
        v = h.to_i(16)
        return Color.new((v >> 16) & 255, (v >> 8) & 255, v & 255)
      end

      #------------------------------------------------------------------------
      # The art: PIF's picture for a background, the mat around it and how
      # strong the plates are over it (each measured once a session)
      #------------------------------------------------------------------------
      def background
        id = $Trainer && $Trainer.respond_to?(:card_background) ? $Trainer.card_background : nil
        id = (defined?(::Settings::DEFAULT_TRAINER_CARD_BG) ? ::Settings::DEFAULT_TRAINER_CARD_BG : "BLUE") if id.to_s.empty?
        return id.to_s
      end

      # The picture's path for a background (Sewers' file has a space after
      # its name), or nil
      def art_path(id)
        [id.to_s, id.to_s.strip, id.to_s.strip + " "].uniq.each do |n|
          path = "#{BG_DIR}/#{n}"
          return path if defined?(pbResolveBitmap) ? pbResolveBitmap(path) : File.file?(path + ".png")
        end
        return nil
      end

      # [mat colour, plate strength 0 to 1] for a background's picture
      def art_facts(id, bitmap)
        @art_facts ||= {}
        return @art_facts[id] if @art_facts[id]
        return [Color.new(80, 144, 224), 0.0] unless bitmap
        counts = Hash.new(0)
        x0, y0, x1, y1 = ART
        (x0...x1).step(4) { |x| [y0, y1 - 1].each { |y| edge_count(counts, bitmap, x, y) } }
        (y0...y1).step(4) { |y| [x0, x1 - 1].each { |x| edge_count(counts, bitmap, x, y) } }
        rgb = counts.max_by { |_k, n| n }
        mat = rgb ? Color.new(*rgb[0]) : Color.new(80, 144, 224)
        return @art_facts[id] = [mat, busyness(bitmap)]
      rescue StandardError => e
        Reloaded::Log.warning_once("The Trainer Card couldn't measure a background (#{id}): #{e.message}", :trainer_card)
        return [Color.new(80, 144, 224), 0.0]
      end

      def edge_count(counts, bitmap, x, y)
        px = bitmap.get_pixel(x, y)
        counts[[px.red.to_i, px.green.to_i, px.blue.to_i]] += 1 if px.alpha > 0
      end

      # How much the art under the plates fights the words, 0 to 1: dark art
      # or busy art (how much the brightness changes)
      def busyness(bitmap)
        values = []
        PLATES.each do |x0, y0, x1, y1|
          (y0...y1).step(6) do |y|
            (x0...x1).step(6) do |x|
              px = bitmap.get_pixel(x, y)
              next if px.alpha < 16
              values << (px.red * 0.299 + px.green * 0.587 + px.blue * 0.114)
            end
          end
        end
        return 0.0 if values.empty?
        mean = values.sum / values.length
        spread = Math.sqrt(values.sum { |v| (v - mean)**2 } / values.length)
        dark = mean < 120 ? (120 - mean) / 90.0 : 0.0
        busy = spread > 30 ? (spread - 30) / 40.0 : 0.0
        return [[dark, busy].max, 1.0].min
      end

      # A plate's alpha for this Theme Mode over this background
      def glass_alpha(light, strength)
        lo, hi = GLASS[light ? :light : :dark]
        return (lo + (hi - lo) * strength.to_f).round
      end

      #------------------------------------------------------------------------
      # Save as Image (his pick: Kanto Reloaded's Trainer Cards folder, 2x)
      #------------------------------------------------------------------------
      def folder
        return Reloaded::Paths.mod_file(FOLDER)
      end

      def can_save_image?
        return Bitmap.method_defined?(:to_file)
      end

      # Writes the card's picture (512 x 384) at twice its size: the path, or
      # nil. A mod folder that can't be written (a phone) gets it beside the
      # saves instead.
      def save_image(bitmap)
        return nil unless bitmap && can_save_image?
        big = Bitmap.new(bitmap.width * 2, bitmap.height * 2)
        big.stretch_blt(Rect.new(0, 0, big.width, big.height), bitmap, bitmap.rect)
        path = nil
        [folder, File.join(Reloaded::Paths.data_dir, FOLDER)].each do |dir|
          path = write_picture(big, dir)
          break if path
        end
        big.dispose
        Reloaded::Log.info("Trainer Card saved as #{path}", :trainer_card) if path
        return path
      rescue StandardError => e
        Reloaded::Log.exception("The Trainer Card couldn't be saved as a picture", e, :trainer_card)
        return nil
      end

      def write_picture(big, dir)
        Reloaded::Paths.ensure_dir(dir)
        name = ($Trainer ? $Trainer.name.to_s : "Trainer").gsub(/[\\\/:*?"<>|]/, "").strip
        name = "Trainer" if name.empty?
        path = Reloaded::Paths.free_name(File.join(dir, "#{name} #{Time.now.strftime("%Y-%m-%d %H.%M")}.png"))
        big.to_file(path)
        return File.file?(path) ? path : nil
      rescue StandardError => e
        Reloaded::Log.warning("The Trainer Card's picture couldn't be written in #{dir}: #{e.message}", :trainer_card)
        return nil
      end

      # Copy Trainer ID: true when it's on the clipboard
      def copy_id
        return $Trainer ? Reloaded::ShareCodes.copy($Trainer.id.to_s) : false
      end
    end

    # The game makes its card's scene: Kanto Reloaded's, while it's on
    module SceneChoice
      def new(*args, &block)
        if equal?(::PokemonTrainerCard_Scene) && Reloaded::TrainerCard.active?
          begin
            return Reloaded::TrainerCard.scene_class.new(*args, &block)
          rescue Exception => e
            raise if Reloaded::Hooks.passthrough?(e)
            Reloaded::Log.exception("The Trainer Card didn't open; the game's own instead", e, :trainer_card)
          end
        end
        super
      end
    end
  end
end
