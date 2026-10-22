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
    # Tools for making Kanto Reloaded and mods, last in the Kanto Reloaded
    # section and shown only with KIF's DEBUG option on (Settings >
    # Advanced): the Timing Profiler's headings (Core/Profiler), then
    # Developer Tools (the Hook Check, Dev).
    register_page(:developer, :group => :general, :name => "Developer Tools", :icon => :system, :priority => 1100,
      :visible => proc { Reloaded.debug? },
      :description => "Tools for making Kanto Reloaded. Shown while KIF's DEBUG option is on.")
  end
end
