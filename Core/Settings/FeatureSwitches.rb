#==============================================================================
# Kanto Reloaded: feature switches in the settings screen
#==============================================================================
# Once every file has loaded, each feature gets an On/Off row on the
# Features page, and another at the top of its own settings page. Both read
# and write Reloaded::Features directly (Features.json), so they always
# agree.
#==============================================================================

module Reloaded
  module FeatureSwitches
    class << self
      def boot
        Reloaded::Features.all.each do |f|
          next if f[:core]
          page = f[:page] && Reloaded::Settings.page(f[:page])
          # the Features row goes to the feature's own page (Go to Settings)
          register_row(:"features.#{f[:id]}", :features, f, f[:order], page ? f[:page] : nil)
          register_row(:"#{f[:page]}.enabled", f[:page], f, -1000) if page
        end
        return true
      end

      private

      def register_row(key, page, feature, priority, goes_to = nil)
        id = feature[:id]
        description = feature[:description].to_s
        description += " " + _INTL("Changes apply after a restart.") if feature[:restart]
        Reloaded::Settings.register(key, :page => page, :priority => priority,
          :name => feature[:name], :type => :toggle, :default => feature[:default] == :on,
          :description => description, :feature => nil, :goes_to => goes_to,
          :bind => Reloaded::Settings::Bind.direct(
            proc { Reloaded::Features.state(id) == :on },
            proc { |on| Reloaded::Features.set(id, on ? :on : :off) }))
      end
    end
  end
end
