# encoding: utf-8
#==============================================================================
# Kanto Reloaded: the Randomizer screen (during a run)
#==============================================================================
# His pick, Overview First: cody's Randomizer in Kanto Reloaded's settings
# layout (a subclass of the improved KIF Settings). Sections: Overview (every
# part with its state), each part (cody's own rows, RandomizerRows.rb),
# Seed. Changes wait until Randomize Now (cody's draft):
#
#   - an amber dot on a part or row with a waiting change; WAITING in the
#     description box; the dropdown marks the value the game uses now IN USE
#   - the Overview's description box sums up the part (a waiting value in
#     amber) with the seed
#   - Y: Randomize Now? (the waiting changes on their own lines, old to new)
#   - leaving with changes waiting: Randomize, Undo or Later (Later the
#     default, and what B picks: cody's question)
#   - A on Seed: New Random Seed, Type a Seed (typed into the title bar),
#     Copy Seed
#   - rows Archipelago holds on a linked save: locked, with why
#   - the Settings Code card and Presets (RandomizerShare.rb), the ban lists
#     (RandomizerBans.rb), the spoiler log, Class Theme List and Entrance
#     Log (RandomizerViewers.rb); Door Kinds as rows under Which Doors, NO
#     DOORS SHUFFLED when every kind is Off
#
# Opened wherever cody's Randomizer opens (KIF Settings' Game > Randomizer,
# PIF's reroll events, the Update Man), through one hook on
# PokemonOptionScreen#pbStartScreen, and from Kanto Reloaded's own Randomizer
# section. During the New Game intro the New Game screen opens instead
# (RandomizerNewGame.rb), and A on one of its parts opens this screen on that
# part's section (no draft then: the intro randomizes once).
#==============================================================================

return unless defined?(Reloaded::SettingsScreen) && defined?(Reloaded::Randomizer::Rows)

module Reloaded
  class RandomizerScreen < Reloaded::SettingsScreen
    RW = Reloaded::Randomizer::Rows
    HELP = { :overview => "Every part at a glance. A opens a part; changes wait for Randomize Now.",
             :seed => "Same seed and settings, same game. Copy the settings code to share them." }.freeze

    class << self
      # Opens it (a randomized save, the feature on): true when it ran
      def open
        return false unless Reloaded::Randomizer.randomized?
        new.main
        return true
      end

      # A question with lines of coloured words (a name never splits from
      # its value): the Header Plate look, its buttons. lines: [[[text,
      # colour] or [:arrow, colour], ...], ...]
      def draw_question(b, c, title, text, lines, buttons, choice)
        p = Reloaded::Pixel
        dl = Reloaded::Dialogs
        w = dl::TEXT_W
        tl = p.wrap(text.to_s, w - 32).first(6)
        shown = lines.first(6)
        h = 40 + tl.length * 18 + (shown.empty? ? 0 : shown.length * 18 + 8) + 48
        x = (dl::SCREEN_W - w) / 2
        y = (dl::SCREEN_H - h) / 2
        dl.frame(b, c, x, y, w, h, title)
        tl.each_with_index { |ln, i| p.text(b, x + 16, y + 40 + i * 18, w - 32, 18, ln, c[:txt], nil, 2) }
        ly = y + 46 + tl.length * 18
        p.small_font(b)
        shown.each_with_index do |line, k|
          lw = line.sum { |t, _c| t == :arrow ? 12 : b.text_size(t.to_s).width }
          lx = x + (w - lw) / 2
          line.each do |t, col|
            if t == :arrow
              p.ui.tri(b, lx + 3, ly + k * 18 + 6, :r, col, 3)
              lx += 12
            else
              lx += p.small(b, lx, ly + k * 18, 300, 18, t, col)
            end
          end
        end
        dl.button_row(b, c, x, w, y + h - 36, buttons, choice)
      end
    end

    # start: a section to open on (New Game's parts)
    def initialize(start = nil)
      super(false, start)
      return if start
      @focus = :side
      @section = 0
    end

    # The sections and rows are the Randomizer's (cody's pages, read again
    # after every change)
    def rebuild
      @boxes = nil
      @setting_info = nil
      @sections = RW::SECTIONS.map { |id, label, col| [id, _INTL(label), col] }
      @rows = RW.build
      RW.rows = @rows
      @sections.reject! { |id, _l, _c| (@rows[id] || []).empty? }
      @defaults = {}
      @locks = {}
    end

    def main
      before = SettingsScreen.showing
      SettingsScreen.showing = self
      ::KIF::Rand.open_draft unless intro?
      open_sprites
      refresh
      loop do
        Graphics.update
        Input.update
        update_frame
        break if handle_input == :close
        tick_description
      end
      finish                    # its question shows over the screen
      dispose_sprites
      return nil
    ensure
      SettingsScreen.showing = before
      dispose_sprites
    end

    # A waiting change's dot (amber); nothing else counts as changed here
    def changed?(r)
      return false if @plain_dots && r.indent.to_i > 0
      return r.opt ? RW.waiting?(r.opt) : false
    end

    private

    def intro?
      return $game_switches && defined?(::SWITCH_DURING_INTRO) && $game_switches[::SWITCH_DURING_INTRO] ? true : false
    end

    #--------------------------------------------------------------------------
    # Input
    #--------------------------------------------------------------------------
    def handle_input
      if Input.trigger?(Input::X) && !@entry && !@dropdown         # a controller's Y
        randomize_now
        return nil
      end
      return super
    end

    # A on a part: its section; on Seed: the seed's actions
    def press
      r = current
      return unless r
      o = r.opt
      if o.is_a?(RW::PartRow)
        i = @sections.index { |s| s[0] == o.part }
        return pbPlayBuzzerSE unless i
        pbPlayDecisionSE
        @section = i
        @sel = 0
        @scroll = 0
        @focus = :list
        return refresh
      end
      return seed_menu if o.is_a?(RW::SeedRow)
      return open_bans(o.kind) if o.is_a?(RW::BanRow)
      case o.respond_to?(:rkey) ? o.rkey : nil
      when :btn_settings_code then return code_card
      when :btn_view_log then return open_viewer(:log)
      when :btn_class_theme_list then return open_viewer(:themes)
      when :btn_entrance_log then return open_viewer(:entrances)
      end
      super
    end

    # A ban list: Kanto Reloaded's Exclusions screen (RandomizerBans.rb);
    # its bans wait for Randomize Now like any change
    def open_bans(kind)
      pbPlayDecisionSE
      hidden { Reloaded::RandomizerBans.new(kind, intro?).main }
      after_change
      return nil
    end

    # The spoiler log (asks first, as cody's does), the Class Theme List, the
    # Entrance Log (RandomizerViewers.rb)
    def open_viewer(kind)
      pbPlayDecisionSE
      v = Reloaded::RandomizerViewer
      case kind
      when :log
        ok = with_hints([[:lr, _INTL("Choose")], [button(:C), _INTL("Press")], [button(:B), _INTL("Cancel")]]) do
          Reloaded::Dialogs.confirm(self, _INTL("View the Spoiler Log?"), _INTL("It shows everything that was randomized."),
                                    _INTL("View"), _INTL("Cancel"))
        end
        return refresh unless ok
      when :entrances
        why = v.doors_missing
        return Reloaded::Dialogs.notice(self, _INTL("Entrance Log"), why) if why
      end
      hidden { v.open(kind) }
      refresh
      return nil
    end

    def seed_menu
      pbPlayDecisionSE
      r = ::KIF::Rand
      labels = [_INTL("New Random Seed"), _INTL("Type a Seed"), _INTL("Copy Seed")]
      descs = [_INTL("A new seed: Same settings, another game."),
               _INTL("8 letters and numbers (no I, O, 0 or 1), from a friend's run."),
               _INTL("Copies {1} to paste somewhere else.", r.format_seed)]
      case Reloaded::Dialogs.menu(self, _INTL("Seed: {1}", r.format_seed), labels, descs)
      when 0
        r.seed = r.new_seed
        after_change
      when 1 then type_seed
      when 2 then copy_seed
      end
      refresh
    end

    def type_seed
      text, how = run_entry(:seed, _INTL("Type a Seed"), ::KIF::Rand.format_seed, 9, :prompt => _INTL("Seed"))
      return refresh unless how == :enter
      s = ::KIF::Rand.parse_seed(text)
      if s
        ::KIF::Rand.seed = s
        after_change
      elsif !text.to_s.strip.empty?
        pbPlayBuzzerSE
        Reloaded::Dialogs.notice(self, _INTL("Type a Seed"), _INTL("A seed is 8 letters and numbers (no I, O, 0 or 1)."))
      end
      refresh
    end

    def copy_seed
      seed = ::KIF::Rand.format_seed
      return copy_for_phone(seed, _INTL("The seed, ready to paste.")) if Reloaded::Runtime.phone?
      ok = (Input.clipboard = seed rescue nil)
      Reloaded::Dialogs.notice(self, _INTL("Copy Seed"), ok ? _INTL("Copied: {1}", seed) : _INTL("Couldn't copy. The seed is {1}.", seed))
    end

    #--------------------------------------------------------------------------
    # Randomize Now, and leaving with changes waiting
    #--------------------------------------------------------------------------
    def randomize_now
      return pbPlayBuzzerSE if intro?
      pbPlayDecisionSE
      return refresh unless ask_randomize
      hidden { ::KIF::Rand.randomize_now }
      after_change
    end

    # Randomize Now?: the seed, then each waiting change on its own line
    def ask_randomize
      c = palette
      lines = RW.waiting(@rows).map do |r|
        o = r.opt
        [[(o.full || o.label).to_s + ": ", c[:dim]], [RW.shown(o, RW.applied(o.rkey)), c[:txt]], [:arrow, c[:dim]], [RW.shown(o), c[:amber]]]
      end
      text = _INTL("Seed {1}. Pokémon, trainers and items are randomized again with these changes. Your party and boxes stay.",
                   ::KIF::Rand.format_seed)
      choice = Reloaded::Dialogs.drawn(self, 2, 0) do |b, cc, i|
        RandomizerScreen.draw_question(b, cc, _INTL("Randomize Now?"), text, lines, [_INTL("Randomize"), _INTL("Cancel")], i)
      end
      return choice == 0
    end

    # Closing: cody's draft settled (his three choices), his masters synced
    def finish
      r = ::KIF::Rand
      if r.applied_state
        if r.changed_keys.empty?
          r.data.delete(:pending)
        else
          choice = Reloaded::Dialogs.ask(self, _INTL("Changes Waiting"),
                     _INTL("They take effect when you Randomize Now. Later keeps them waiting in this save; Undo puts them back."),
                     nil, [_INTL("Randomize"), _INTL("Undo"), _INTL("Later")], 2)
          case choice
          when 0 then r.randomize_now
          when 1
            r.restore(r.applied_state)
            r.data.delete(:pending)
          else
            r.data[:pending] = r.capture
            r.restore(r.applied_state)
          end
        end
      end
      r.applied_state = nil
      r.sync_masters
    rescue StandardError => e
      Reloaded::Log.exception("The Randomizer's changes couldn't be settled", e, :randomizer)
      ::KIF::Rand.applied_state = nil rescue nil
    end

    #--------------------------------------------------------------------------
    # What's shown
    #--------------------------------------------------------------------------
    def desc_of(opt)
      d = opt.description
      if d.is_a?(Array)
        v = (opt.get rescue 0).to_i
        d = d[v] || d[0]
      end
      text = PF.utf8(d.to_s).gsub(/\s+/, " ").strip
      why = kr_lock(opt)
      return why ? Reloaded::KIFDropdowns.with_lock(text, _INTL(why)) : text
    end

    # Archipelago's held rows; Kanto Reloaded's while the row above says
    # they don't apply (Per Pokémon while Abilities is Same, a Rolls row
    # while its row is Off)
    def kr_lock(opt)
      return nil unless opt.respond_to?(:rkey)
      why = RW.kr_why(opt.rkey)
      return _INTL(why) if why
      return RW.lock_reason(opt.rkey)
    end

    def read_only?(_opt)
      return false
    end

    def section_help
      id = section_id
      return _INTL(HELP[id]) if HELP[id]
      return _INTL(RW.section_help(id).to_s)
    end

    # Waiting changes: the amber dot in every theme; an indented row's dot
    # in the column of the others (not on its tree line)
    def paint_list(base, top, c)
      @plain_dots = true
      super(base, top, c.merge(:dot => c[:amber]))
      @plain_dots = false
      list = rows
      (@row_hits || []).each do |i, _x0, y, *|
        r = list[i]
        next unless r && r.indent > 0 && RW.waiting?(r.opt)
        dy = y + (ROW_H - 2) / 2 - 3
        P.ui.rrect(top, NAME_X - 11, dy, NAME_X - 6, dy + 5, 3, c[:amber])
      end
    end

    def paint_title(base, top, c)
      return super if @entry
      paint_title_bar(base, c)
      P.text(top, 0, 2, W, 28, _INTL("Randomizer"), c[:title], PF::TITLE, 2)
      title_box(base, top, c, 8, @query || _INTL("Search"), :search => true, :active => !@query.nil?)
      title_box(base, top, c, W - 8 - BUTTON_W, _INTL("Presets"))
      title_keys(top, c, left_key, right_key)
    end

    def paint_value(top, c, r, y, selected, kind)
      o = r.opt
      if o.is_a?(RW::PartRow)
        st, on = RW.part_state(o.part)
        P.text(top, VAL_X1 - 180, y, 180, ROW_H - 2, st, on ? c[:opt] : c[:dim], nil, 1)
        return
      end
      if o.is_a?(RW::SeedRow)
        P.text(top, VAL_X1 - 180, y, 180, ROW_H - 2, ::KIF::Rand.format_seed, c[:strong], nil, 1)
        return
      end
      if o.is_a?(RW::BanRow)
        n = o.get
        P.text(top, VAL_X1 - 180, y, 180, ROW_H - 2, n == 1 ? _INTL("1 Banned") : _INTL("{1} Banned", n), n > 0 ? c[:opt] : c[:dim], nil, 1)
        return
      end
      super
    end

    def pills(top, y0, list)
      x = W - 14
      list.each { |label, fill, col| x -= P.pill(top, x, y0 + 7, label, fill, col) + 6 }
    end

    def amber_fill(c)
      return Reloaded::Palette.mix(c[:panel2], c[:amber], c[:light] ? 0.22 : 0.3)
    end

    def paint_description(base, top, c)
      r = (@focus == :list && !@entry) ? current : nil
      y0 = LIST_Y1 + 4
      if @entry && @entry_kind == :preset_name
        description_box(base, c, y0)
        P.text(top, 14, y0 + 1, 330, 26, _INTL("Save as Preset"), c[:head], PF::ROW)
        rich_left(top, 14, y0 + 28, W - 34, DESC_DY,
                  [[_INTL("Type a name for these settings. They're kept as a file in {1}, to load later or share.", presets_folder), c[:txt]]], DESC_LINES)
        return
      end
      if r && RW.no_doors?(r.opt)
        description_box(base, c, y0)
        P.text(top, 14, y0 + 1, 330, 26, r.opt.label, c[:head], PF::ROW)
        pills(top, y0, [[_INTL("NO DOORS SHUFFLED"), RD.tone_fill(c, c[:red]), c[:red]]])
        rich_left(top, 14, y0 + 28, W - 34, DESC_DY,
                  [[RW.shown(r.opt) + ". ", c[:txt]], [_INTL("With every kind of door Off, no doors are shuffled."), c[:red]],
                   [" " + _INTL("Switch one On, or pick another Which Doors."), c[:txt]]], DESC_LINES)
        return
      end
      if r && r.opt.is_a?(RW::PartRow)
        description_box(base, c, y0)
        P.text(top, 14, y0 + 1, 330, 26, r.opt.label, c[:head], PF::ROW)
        list = [[_INTL("SEED {1}", ::KIF::Rand.format_seed), c[:pill], c[:txt]]]
        list.unshift([_INTL("WAITING"), amber_fill(c), c[:amber]]) if RW.waiting?(r.opt)
        pills(top, y0, list)
        seg = []
        RW.summary(@rows, r.opt.part).each do |name, v, w|
          seg << [", ", c[:dim]] unless seg.empty?
          seg << [name.to_s + ": ", c[:dim], :glue]
          seg << [v, w ? c[:amber] : c[:txt], true]
        end
        seg = [[_INTL("Nothing here is randomized."), c[:dim]]] if seg.empty?
        rich_left(top, 14, y0 + 28, W - 34, DESC_DY, seg, DESC_LINES)
        return
      end
      super
      if r && r.opt.respond_to?(:rkey) && RW.lock_reason(r.opt.rkey)
        return pills(top, y0, [[_INTL("LOCKED BY ARCHIPELAGO"), LOCK_FILL, c[:white]]])
      end
      return unless r && RW.waiting?(r.opt)
      pills(top, y0, [[_INTL("WAITING"), amber_fill(c), c[:amber]]])
    end

    # Coloured words, wrapped to w, left-aligned: a whole segment never
    # splits; a :glue one stays on the line of the segment after it (a name
    # and its value)
    def rich_left(b, x, y, w, line_h, segments, max_lines)
      P.small_font(b)
      units = []
      pending = nil
      segments.each do |text, color, mode|
        pieces = mode ? [[text.to_s, color]] : text.to_s.scan(/\S+|\s+/).map { |t| [t, color] }
        pieces.each do |pc|
          if pending
            units << (pending << pc)
            pending = nil
          else
            units << [pc]
          end
        end
        pending = units.pop if mode == :glue
      end
      units << pending if pending
      lines = [[]]
      width = 0
      units.each do |unit|
        uw = unit.sum { |t, _c| b.text_size(t).width }
        if unit.all? { |t, _c| t =~ /\A\s+\z/ }
          next if lines.last.empty?
        elsif width + uw > w && !lines.last.empty?
          lines.last.pop while lines.last.last && lines.last.last.all? { |t, _c| t =~ /\A\s+\z/ }
          lines << []
          width = 0
        end
        lines.last << unit
        width += uw
      end
      lines.first(max_lines).each_with_index do |line, i|
        lx = x
        line.flatten(1).each do |t, color|
          tw = b.text_size(t).width
          P.small(b, lx, y + i * line_h, tw + 2, line_h, t, color)
          lx += tw
        end
      end
    end

    # A waiting row's dropdown marks the value the game uses now: IN USE
    def open_dropdown(r)
      o = r.opt
      anchor = (@value_boxes || {})[r]
      return cycle(o) unless anchor
      cur = (o.get rescue 0).to_i
      values = o.values.map { |v| PF.utf8(v.to_s) }
      tags = {}
      if o.respond_to?(:rkey) && RW.waiting?(o)
        inuse = RW.applied(o.rkey)
        tags[inuse] = [_INTL("IN USE"), :amber] if inuse != cur
      end
      dd = Reloaded::Dropdown.new(values, cur, anchor, dropdown_bounds(LIST_X0, LIST_Y0, LIST_X1, LIST_Y1), :tags => tags)
      @dropdown_keys = Array.new(values.length) { Object.new }
      choice = run_dropdown(dd) { tick_description }
      return if choice.nil? || choice == cur
      o.set(choice)
      after_change
    end

    def hint_pairs
      return @popup_hints if @popup_hints
      return super if @entry || @dropdown || @focus == :side
      r = current
      list = if r && (r.opt.is_a?(RW::PartRow) || r.opt.is_a?(RW::SeedRow) || ::KIF::SettingsScreen.button?(r.opt))
               [[:ud, _INTL("Select")], [button(:C), _INTL("Open"), :press]]
             else
               [[:ud, _INTL("Select")], [:lr, _INTL("Change"), :mouse_change]]
             end
      list << [button(:X), _INTL("Randomize Now"), :randomize_now] unless intro?
      list << [button(:B), _INTL("Sections"), :mouse_back]
      return list
    end
  end

  module Randomizer
    INTRO_QUESTION = "Are those settings correct?"

    # The intro's loop after Kanto Reloaded's New Game screen: straight to
    # its break (PIF's summary and question skipped). A cheap flag check
    # first: this runs for every event command.
    module IntroSkip
      def execute_command
        Reloaded::Randomizer.skip_intro(self) if Reloaded::Randomizer.skip_intro_summary
        return super
      end
    end

    class << self
      attr_accessor :skip_intro_summary

      # cody's Randomizer screen opens: Kanto Reloaded's instead (the New
      # Game one during the intro); a failure gives his back
      def install_screen
        return unless defined?(::PokemonOptionScreen) && defined?(::RandomizerOptionsScene)
        Reloaded::Hooks.around(FEATURE, "PokemonOptionScreen", :pbStartScreen, :id => :randomizer_screen) do |original, *args|
          scene = original.receiver.instance_variable_get(:@scene)
          next original.call(*args) unless scene.instance_of?(::RandomizerOptionsScene) && Reloaded::Randomizer.on?
          intro = $game_switches && defined?(::SWITCH_DURING_INTRO) && $game_switches[::SWITCH_DURING_INTRO]
          next original.call(*args) unless intro || Reloaded::Randomizer.randomized?
          begin
            intro ? Reloaded::RandomizerNewGame.new.main : Reloaded::RandomizerScreen.new.main
            nil
          rescue StandardError => e
            Reloaded::Log.exception("The Randomizer screen failed; KIF's instead", e, :randomizer)
            ::KIF::Rand.applied_state = nil rescue nil
            original.call(*args)
          end
        end
        Reloaded::Hooks.prepend(FEATURE, "Interpreter", IntroSkip, :id => :randomizer_intro_skip) if defined?(::Interpreter)
      end

      # In the intro's randomizer loop (found by its question), before the
      # question: jump to the loop's break
      def skip_intro(interp)
        return unless Reloaded::Features.on?(FEATURE)
        list = interp.instance_variable_get(:@list)
        index = interp.instance_variable_get(:@index).to_i
        return unless list && list[index]
        q = list.index { |c| c.code == 101 && c.parameters[0].to_s.strip == INTRO_QUESTION }
        return unless q && index < q && index > q - 10
        brk = (q...list.length).find { |k| list[k].code == 113 }
        return unless brk
        interp.instance_variable_set(:@index, brk)
        self.skip_intro_summary = false
      end
    end
  end
end
