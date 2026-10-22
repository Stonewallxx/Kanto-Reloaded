#==============================================================================
# Kanto Reloaded (Dev): Stonewall's own tools
#==============================================================================
# Never in a release: the Release Builder leaves the Dev folder out, and
# without it nothing here exists. Bootstrap loads this file after the rest
# of the mod when the folder is there (LoadOrder::DEV_FILE) and boots
# Reloaded::Dev last.
#
#   HookCheck/   the Hook Checker: Kanto Reloaded's hooks against the KIF
#                Beta it runs on, checked at the first load screen after
#                every KIF update (HookCheck/HookCheck.rb)
#   Tests/       its offline checks and screen preview:
#                  ruby Dev/Tests/hook_check_test.rb "<KIF Beta>" <empty temp folder>
#                  ruby Dev/Tests/hook_check_preview.rb "<KIF Beta>" <work dir with metrics.json>
#                  (then Tools/UIPreview/render.py draws the screens)
#==============================================================================

module Reloaded
  module Dev
    FILES = [
      "HookCheck/HookCheck.rb",
      "HookCheck/Diff.rb",
      "HookCheck/Report.rb",
      "HookCheck/Screen.rb",
      "HookCheck/Alert.rb"
    ].freeze

    def self.boot
      return Reloaded::HookCheck.boot
    end
  end
end

Reloaded::Dev::FILES.each { |f| load File.join(Reloaded::ROOT, "Dev", f) }
