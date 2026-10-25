#==============================================================================
# Kanto Reloaded: core settings groups and pages
#==============================================================================
# The groups (tabs) and the core pages of the Kanto Reloaded settings screen.
# Each feature registers its own page in one of these groups.
#==============================================================================

module Reloaded
  module Settings
    register_group(:general, :name => "General", :priority => 10,
      :description => "How Kanto Reloaded looks and which features are on.")

    # Kanto Reloaded's systems that replace one of the game's: each is a
    # toggle between Kanto Reloaded's version and the game's own. First in
    # the Kanto Reloaded section, Reloaded Settings at its top.
    register_page(:systems, :group => :general, :name => "Reloaded Systems", :icon => :systems, :priority => 0,
      :description => "Each switches between Kanto Reloaded's version of a system and the game's own.")
    register_page(:features, :group => :general, :name => "Features", :icon => :features, :priority => 10,
      :description => "Switch each Kanto Reloaded feature on or off. Off features leave the game as it was.")
    register_page(:interface, :group => :general, :name => "Interface", :icon => :interface, :priority => 20,
      :description => "Text, colors and the look of Kanto Reloaded's screens.")
    # KR Debug (his ask, 2026-10-25): Stonewall's alone, a section of its
    # own after Kanto Reloaded's, there only with the Kanto Reloaded Debug
    # mod installed (Reloaded.debug_mod?): the mod's pages (Debug Mode),
    # then Developer Tools (the Hook Check, Dev). What a modder might use
    # stays in the Kanto Reloaded section, shown with KIF's DEBUG option on
    # (Reloaded.debug?): the Timing Profiler's headings (Core/Profiler).
    register_group(:kr_debug, :name => "KR Debug", :priority => 900, :section => [150, 96, 220], :ball => [150, 96, 220],
      :visible => proc { Reloaded.debug_mod? },
      :description => "Kanto Reloaded's own debug tools, from the Kanto Reloaded Debug mod.")
    register_page(:developer, :group => :kr_debug, :name => "Developer Tools", :icon => :system, :priority => 1100,
      :description => "Tools for making Kanto Reloaded.")
  end
end
