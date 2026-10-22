#==============================================================================
# Kanto Reloaded: who a file belongs to
#==============================================================================
# The Timing Profiler names each piece of code by its owner: "Kanto
# Reloaded", a mod (its name in KIF's Mods list), "EBDX", "KIF Beta" or
# "PIF". The game loads Data\Scripts with only each file's name as its
# source path, so a bare name is looked up there (Paths.script_file); mods
# load with their full path (Mods\<folder>\...).
#
#   Reloaded::Profiler::Owners.of("E:/.../Mods/HardTrainers/team.rb")  => "Hard Trainers+"
#   Reloaded::Profiler::Owners.of("010_EBDX_Scene.rb")                  => "EBDX"
#==============================================================================

module Reloaded
  module Profiler
    module Owners
      KR = "Kanto Reloaded".freeze
      EBDX = "EBDX".freeze
      KIF = "KIF Beta".freeze
      PIF = "PIF".freeze
      GAME = [EBDX, KIF, PIF].freeze      # the game itself, not a mod

      @cache = {}

      class << self
        # The owner of a source file (a method's source_location[0]).
        def of(file)
          file = file.to_s
          return PIF if file.empty?
          return @cache[file] ||= find(file)
        end

        # A mod (not the game, not Kanto Reloaded).
        def mod?(owner)
          return !GAME.include?(owner) && owner != KR
        end

        def game?(owner)
          return GAME.include?(owner)
        end

        # A mod's folder => its name in KIF's Mods list (the folder's name
        # when it isn't listed).
        def mod_name(folder)
          @names ||= begin
            names = {}
            if defined?(::KIF::Mods) && ::KIF::Mods.respond_to?(:entries)
              (::KIF::Mods.entries rescue []).each do |e|
                next unless e.respond_to?(:path) && e.path
                names[File.basename(e.path.to_s).downcase] = e.name.to_s
              end
            end
            names
          end
          return @names[folder.to_s.downcase] || folder.to_s
        end

        # Forget what was worked out (mods switched, tests).
        def reset
          @cache = {}
          @names = nil
        end

        private

        def find(file)
          path = file.tr("\\", "/")
          root = File.expand_path(Reloaded::ROOT).tr("\\", "/").downcase
          return KR if path.downcase.start_with?(root + "/")
          if (m = path.match(%r{(?:\A|/)Mods/([^/]+)/}i))
            return KR if m[1].casecmp?(File.basename(Reloaded::ROOT))
            return mod_name(m[1])
          end
          full = Reloaded::Paths.script_file(path) || path
          parts = full.tr("\\", "/").split("/")
          scripts = parts.rindex { |p| p.casecmp?("Scripts") }
          folder = scripts ? parts[scripts + 1].to_s : ""
          return EBDX if folder =~ /EBDX/i
          return KIF if folder.start_with?("990_KIF")
          return PIF
        end
      end
    end
  end
end
