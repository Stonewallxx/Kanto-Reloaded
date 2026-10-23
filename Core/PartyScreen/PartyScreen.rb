#==============================================================================
# Kanto Reloaded: the Party Screen
#==============================================================================
# Roadmap topic party-screen (his picks, 2026-10-21): Cards and Details in
# his look (His Mix), the command menu in the details panel (Panel Menu),
# submenus in place, Switch with a gold edge and a preview, Grey Out when
# choosing for something, an Egg's steps bar, messages in a bar along the
# bottom, empty spots dashed, EXP under the level. Dark or Light with Theme
# Mode (full screens: Glass shows Dark, Frost shows Light).
#
# Only how the screen looks is replaced: the game's own party logic
# (PokemonPartyScreen) still builds the command list and does what's
# picked, so KIF Beta's commands (Kuray Actions, its command hook) and any
# mod's still show. Kanto Reloaded's scene is a subclass of the game's
# PokemonParty_Scene (UI/PartyScene.rb), made whenever the game makes one,
# while Reloaded Party Screen is On (Reloaded Systems). It's the same screen
# in battle (the game's and EBDX's), from the Bag, the Day Care, trades...
#
# A mod can add a command for a Pokemon cleanly (it shows before Cancel in
# the Pokemon's menu, outside battle):
#
#   Reloaded::PartyScreen.add_command(:walk, :label => proc { |pkmn| "Walk Together" or nil },
#     :description => "...", :handler => proc { |scene, pkmn, index| ... })
#==============================================================================

module Reloaded
  module PartyScreen
    TOGGLE = :"systems.party_screen"
    # The types' colours (the cards' and panel's tint); others are grey
    TYPE_RGB = { :NORMAL => [168, 168, 120], :FIGHTING => [192, 48, 40], :FLYING => [168, 144, 240], :POISON => [160, 64, 160],
                 :GROUND => [224, 192, 104], :ROCK => [184, 160, 56], :BUG => [168, 184, 32], :GHOST => [112, 88, 152],
                 :STEEL => [184, 184, 208], :FIRE => [240, 128, 48], :WATER => [104, 144, 240], :GRASS => [120, 200, 80],
                 :ELECTRIC => [248, 208, 48], :PSYCHIC => [248, 88, 136], :ICE => [152, 216, 216], :DRAGON => [112, 56, 248],
                 :DARK => [112, 88, 72], :FAIRY => [238, 153, 172] }.freeze
    GREY = [150, 150, 160].freeze
    # The Egg's stage, by steps left, as PIF's Summary words it, and its
    # short word on a card
    EGG_STAGES = [[1275, "Sounds can be heard coming from inside! It will hatch soon!", "Soon"],
                  [2550, "It appears to move occasionally. It may be close to hatching.", "Moving"],
                  [10200, "What will hatch from this? It doesn't seem close to hatching.", "Not Close"],
                  [nil, "It looks like this Egg will take a long time to hatch.", "A Long Time"]].freeze

    Command = Struct.new(:id, :label, :description, :handler)
    @commands = []

    class << self
      # [move, by a machine?] while the game is choosing who learns a move
      # (a TM, a tutor): the panel shows the move
      attr_accessor :teaching

      def boot
        register_settings
        install
        return true
      end

      def register_settings
        Reloaded::Settings.register(TOGGLE, :page => :systems, :priority => 32, :type => :toggle, :default => true, :preset => false,
          :name => "Reloaded Party Screen",
          :description => "Kanto Reloaded's party screen: Cards and details, the menu in the panel, in battle too. Off shows the game's own.")
      end

      def enabled?
        return Reloaded::Settings.get(TOGGLE) ? true : false
      rescue StandardError
        return false
      end

      # On, and its screen can draw
      def active?
        return enabled? && Reloaded::Pixel.available? && defined?(Reloaded::PartyScene) ? true : false
      end

      # The game's classes are there in the game; outside it (tests, the
      # preview tool) each hook is made only when its target is.
      def install
        if defined?(::PokemonParty_Scene) && !@new_hooked
          @new_hooked = true
          Reloaded::Hooks.prepend(nil, ::PokemonParty_Scene.singleton_class, SceneChoice, :id => :party_screen_scene)
        end
        if (::Object.private_method_defined?(:pbMoveTutorChoose) || ::Object.method_defined?(:pbMoveTutorChoose)) && !@tutor_hooked
          @tutor_hooked = true
          Reloaded::Hooks.around(nil, ::Object, :pbMoveTutorChoose, :id => :party_screen_teaching) do |original, move, *rest|
            before = Reloaded::PartyScreen.teaching
            Reloaded::PartyScreen.teaching = [move, rest[1] ? true : false]
            begin
              original.call(move, *rest)
            ensure
              Reloaded::PartyScreen.teaching = before
            end
          end
        end
        return true
      end

      # Kanto Reloaded's scene class: a subclass of the game's, made the
      # first time it's needed (so every mod's changes to the game's class
      # are in by then). The game's own command list and choosing are
      # replaced at their innermost method: a mod that wraps them (KIF's
      # command hook) still runs around ours.
      def scene_class
        return @scene_class if @scene_class
        base = ::PokemonParty_Scene
        k = Class.new(base) { include Reloaded::PartyScene }
        { :pbShowCommands => :kr_show_commands, :pbChoosePokemon => :kr_choose_pokemon }.each do |name, ours|
          inner = innermost(base, name)
          k.send(:define_method, inner) do |*args, &blk|
            @kr_vanilla ? super(*args, &blk) : send(ours, *args, &blk)
          end
        end
        return @scene_class = k
      end

      # The name the game's own method lives under now: a mod that wrapped
      # it (alias + new method) left PIF's under the alias
      def innermost(klass, name)
        names = klass.instance_methods + klass.private_instance_methods
        pif = names.select do |n|
          m = klass.instance_method(n)
          m.original_name == name && m.source_location && m.source_location[0].to_s =~ /005_UI_Party/
        end
        return name if pif.empty? || pif.include?(name)
        return pif.first
      rescue StandardError
        return name
      end

      #------------------------------------------------------------------------
      # Commands of mods
      #------------------------------------------------------------------------
      def add_command(id, options = {})
        @commands.reject! { |c| c.id == id.to_sym }
        @commands << Command.new(id.to_sym, options[:label], options[:description].to_s, options[:handler])
        return id.to_sym
      end

      # [[command, label]] for a Pokemon (a nil label hides it)
      def commands_for(pkmn)
        return @commands.map { |c| [c, label_of(c, pkmn)] }.select { |_c, l| l }
      end

      def label_of(c, pkmn)
        return c.label.respond_to?(:call) ? c.label.call(pkmn) : c.label
      rescue StandardError => e
        Reloaded::Log.warning_once("A party command's label failed (#{c.id}): #{e.message}", :party_screen)
        return nil
      end

      #------------------------------------------------------------------------
      # Words
      #------------------------------------------------------------------------
      # The title bar for the game's help line: "Party", or what's being
      # chosen, in Title Case
      def title_for(help, source = nil, teaching = nil)
        text = help.to_s.strip
        plain = [_INTL("Choose a Pokémon."), _INTL("Choose Pokémon or cancel."), ""]
        return _INTL("Party") if plain.include?(text) && !teaching
        if teaching
          name = (::GameData::Move.get(teaching[0]).name rescue teaching[0].to_s)
          return _INTL("Teach {1} to Which?", name)
        end
        return _INTL("Move {1} Where?", source.name) if source && text == _INTL("Move to where?")
        return title_case(text.sub(/\.\z/, ""))
      end

      SMALL = %w[a an and as at but by for in of on or the to with].freeze

      def title_case(text)
        words = text.split(" ")
        return words.each_with_index.map { |w, i| i > 0 && SMALL.include?(w.downcase) ? w.downcase : w[0].to_s.upcase + w[1..-1].to_s }.join(" ")
      end

      # What a command does, for the panel's foot
      def describe(label, pkmn)
        name = pkmn ? pkmn.name : ""
        words = {
          _INTL("Summary") => _INTL("{1}'s details.", name),
          _INTL("Switch") => _INTL("Move it to another place in the party."),
          _INTL("Switch In") => _INTL("Send it into battle."),
          _INTL("Item") => _INTL("Use, give, take or move its held item."),
          _INTL("Mail") => _INTL("Read or take its mail."),
          _INTL("Nickname") => _INTL("Give it a nickname, or take it off."),
          _INTL("Relearn Moves") => _INTL("Remember a move it knew before."),
          _INTL("Hat") => _INTL("Put on or take off a hat."),
          _INTL("Fuse") => _INTL("Fuse it with another Pokémon."),
          _INTL("Unfuse") => _INTL("Split it back into two Pokémon."),
          _INTL("Evolve!") => _INTL("It's ready to evolve."),
          _INTL("RLD Actions") => _INTL("Export it to a file."),
          _INTL("Export") => _INTL("Save it to a file."),
          _INTL("Debug") => _INTL("Debug options for it."),
          _INTL("Cancel") => _INTL("Back to the party."),
          _INTL("Back") => _INTL("Back."),
          _INTL("Give") => _INTL("Give it an item from the Bag to hold."),
          _INTL("Take") => _INTL("Put its item back in the Bag."),
          _INTL("Move") => _INTL("Give its item to another Pokémon."),
          _INTL("Use") => _INTL("Use an item from the Bag on it."),
          _INTL("Read") => _INTL("Read the mail."),
          _INTL("Rename") => _INTL("Give it a new nickname.")
        }
        return words[label] if words.key?(label)
        c = @commands.find { |x| label_of(x, pkmn) == label }
        return c ? c.description : ""
      end

      # [stage words, short word, steps left, how far along (0 to 1)]
      def egg_stage(pkmn)
        left = (pkmn.steps_to_hatch rescue 0).to_i
        total = (::GameData::Species.get(pkmn.species).hatch_steps rescue 0).to_i
        total = [total, left, 1].max
        stage = EGG_STAGES.find { |limit, _w, _s| limit.nil? || left < limit }
        return [_INTL(stage[1]), _INTL(stage[2]), left, 1.0 - left.to_f / total]
      end

      def type_rgb(type)
        return TYPE_RGB[type] || GREY
      end
    end

    # The game makes its party scene: Kanto Reloaded's, while it's on
    module SceneChoice
      def new(*args, &block)
        if equal?(::PokemonParty_Scene) && Reloaded::PartyScreen.active?
          begin
            return Reloaded::PartyScreen.scene_class.new(*args, &block)
          rescue Exception => e
            raise if Reloaded::Hooks.passthrough?(e)
            Reloaded::Log.exception("The Party Screen didn't open; the game's own instead", e, :party_screen)
          end
        end
        super
      end
    end
  end
end
