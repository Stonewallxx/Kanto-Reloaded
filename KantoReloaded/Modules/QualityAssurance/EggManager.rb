#==============================================================================
# Kanto Reloaded Quality of Life - Egg Manager
#==============================================================================
# Remote Egg inventory and Day Care management using KIF-owned data and
# mutation methods.
#==============================================================================

module KantoReloaded
  module QualityAssurance
    module EggManager
      ACTION_KEY = :egg_manager
      SETTINGS_PRIORITY = 83
      OVERWORLD_PRIORITY = 24
      FILTERS = [:all, :party, :pc].freeze
      IV_ORDER = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].freeze
      COMPATIBILITY_LABELS = [
        "Cannot Breed",
        "Low Compatibility",
        "Good Compatibility",
        "High Compatibility"
      ].freeze

      class << self
        def open(options = {})
          unless available?
            KantoReloaded.message(
              _INTL("Egg Manager is unavailable before a game has been loaded."),
              :theme => :warning
            )
            return false
          end
          runner = proc { KantoReloaded::QualityAssurance::EggManager::Scene.new.main }
          options[:fade] == false || !defined?(pbFadeOutIn) ? runner.call : pbFadeOutIn(&runner)
          true
        rescue StandardError => e
          log_exception("Egg Manager could not be opened", e)
          KantoReloaded.message(_INTL("Egg Manager could not be opened."), :theme => :error)
          false
        end

        def available?
          trainer && global_metadata
        rescue
          false
        end

        def trainer
          defined?($Trainer) ? $Trainer : nil
        end

        def storage
          defined?($PokemonStorage) ? $PokemonStorage : nil
        end

        def global_metadata
          defined?($PokemonGlobal) ? $PokemonGlobal : nil
        end

        def party
          value = trainer
          value && value.respond_to?(:party) ? Array(value.party) : []
        rescue
          []
        end

        def egg_entries(filter = :all)
          filter = FILTERS.include?(filter.to_sym) ? filter.to_sym : :all
          entries = []
          if filter != :pc
            party.each_with_index do |pokemon, index|
              next unless egg?(pokemon)
              entries << {
                :pokemon => pokemon,
                :location => :party,
                :party_index => index,
                :box => -1,
                :slot => index,
                :location_label => _INTL("Party Slot {1}", index + 1)
              }
            end
          end
          append_pc_eggs(entries) if filter != :party
          entries.sort_by do |entry|
            location_order = entry[:location] == :party ? 0 : 1
            [location_order, remaining_steps(entry[:pokemon]), entry[:box].to_i, entry[:slot].to_i]
          end
        rescue StandardError => e
          log_exception("Could not build Egg Manager index", e)
          []
        end

        def egg_counts
          entries = egg_entries(:all)
          party_count = entries.count { |entry| entry[:location] == :party }
          pc_count = entries.length - party_count
          {
            :party => party_count,
            :pc => pc_count,
            :total => entries.length,
            :waiting => waiting_egg?
          }
        rescue
          { :party => 0, :pc => 0, :total => 0, :waiting => false }
        end

        def remaining_steps(pokemon)
          return 0 unless pokemon && pokemon.respond_to?(:steps_to_hatch)
          [pokemon.steps_to_hatch.to_i, 0].max
        rescue
          0
        end

        def initial_steps(pokemon)
          return 1 unless pokemon && pokemon.respond_to?(:species_data)
          value = pokemon.species_data.hatch_steps.to_i
          value > 0 ? value : [remaining_steps(pokemon), 1].max
        rescue
          [remaining_steps(pokemon), 1].max
        end

        def hatch_progress(pokemon)
          initial = initial_steps(pokemon)
          remaining = [[remaining_steps(pokemon), initial].min, 0].max
          [[1.0 - remaining.to_f / initial, 0.0].max, 1.0].min
        rescue
          0.0
        end

        def hatch_status(pokemon, location = nil)
          return _INTL("Paused in PC") if location == :pc
          steps = remaining_steps(pokemon)
          return _INTL("Ready to hatch") if steps <= 1
          return _INTL("It will hatch soon") if steps < 1_275
          return _INTL("It may be close to hatching") if steps < 2_550
          return _INTL("It moves occasionally") if steps < 10_200
          _INTL("It does not seem close to hatching")
        rescue
          _INTL("Hatch status unavailable")
        end

        def daycare_slots
          metadata = global_metadata
          raw = metadata && metadata.respond_to?(:daycare) ? metadata.daycare : nil
          slots = Array(raw)
          [slots[0] || [nil, 0], slots[1] || [nil, 0]]
        rescue
          [[nil, 0], [nil, 0]]
        end

        def daycare_count
          daycare_slots.count { |slot| slot && slot[0] }
        end

        def daycare_parent(index)
          slot = daycare_slots[index.to_i]
          slot ? slot[0] : nil
        rescue
          nil
        end

        def daycare_deposit_level(index)
          slot = daycare_slots[index.to_i]
          slot ? slot[1].to_i : 0
        rescue
          0
        end

        def daycare_cost(index)
          return 0 unless daycare_parent(index)
          call_global(:pbDayCareGetCost, index.to_i).to_i
        rescue
          parent = daycare_parent(index)
          return 0 unless parent
          ((parent.level.to_i - daycare_deposit_level(index)) + 1) * 100
        end

        def daycare_compatibility
          return 0 unless daycare_count == 2
          [[call_global(:pbDayCareGetCompat).to_i, 0].max, 3].min
        rescue
          0
        end

        def daycare_compatibility_label
          COMPATIBILITY_LABELS[daycare_compatibility] || COMPATIBILITY_LABELS[0]
        end

        def daycare_chance
          values = oval_charm? ? [0, 40, 80, 88] : [0, 20, 50, 70]
          values[daycare_compatibility].to_i
        rescue
          0
        end

        def daycare_cycle_steps
          metadata = global_metadata
          return 0 unless metadata && metadata.respond_to?(:daycareEggSteps)
          [[metadata.daycareEggSteps.to_i, 0].max, 255].min
        rescue
          0
        end

        def waiting_egg?
          metadata = global_metadata
          return false unless metadata && daycare_count == 2
          metadata.respond_to?(:daycareEgg) && metadata.daycareEgg.to_i == 1
        rescue
          false
        end

        def can_deposit?
          return false if daycare_count >= 2 || !storage
          return false unless defined?(PokemonStorageScene) && defined?(PokemonStorageScreen)
          true
        rescue
          false
        end

        def can_withdraw?(index)
          !daycare_parent(index).nil?
        end

        def pc_space_available?
          target_storage = storage
          return false unless target_storage && target_storage.respond_to?(:pbStoreCaught)
          return false if target_storage.respond_to?(:full?) && target_storage.full?
          true
        rescue
          false
        end

        def move_to_pc(entry)
          return false unless valid_entry?(entry, :party)
          target_storage = storage
          unless target_storage && target_storage.respond_to?(:pbStoreCaught)
            KantoReloaded.message(_INTL("Pokemon Storage is unavailable."), :theme => :warning)
            return false
          end
          if target_storage.respond_to?(:full?) && target_storage.full?
            KantoReloaded.message(_INTL("All PC boxes are full."), :theme => :warning)
            return false
          end

          pokemon = entry[:pokemon]
          source_index = current_party_index(pokemon)
          return stale_entry unless source_index
          stored_box = target_storage.pbStoreCaught(pokemon)
          unless stored_box && stored_box.to_i >= 0 && storage_contains?(pokemon)
            KantoReloaded.message(_INTL("The Egg could not be moved to the PC."), :theme => :error)
            return false
          end
          trainer.party.delete_at(source_index)
          trainer.party.compact!
          box_name = storage_box_name(stored_box.to_i)
          KantoReloaded.toast_success(_INTL("The Egg was moved to {1}.", box_name))
          log_info("Moved Egg from party to #{box_name}")
          true
        rescue StandardError => e
          log_exception("Could not move Egg to PC", e)
          KantoReloaded.message(_INTL("The Egg could not be moved to the PC."), :theme => :error)
          false
        end

        def move_to_party(entry)
          return false unless valid_entry?(entry, :pc)
          if trainer.party_full?
            KantoReloaded.message(_INTL("The party is full."), :theme => :warning)
            return false
          end
          pokemon = current_pc_pokemon(entry)
          return stale_entry unless pokemon && pokemon.equal?(entry[:pokemon])

          trainer.party[trainer.party.length] = pokemon
          begin
            storage[entry[:box], entry[:slot]] = nil
          rescue StandardError
            trainer.party.delete(pokemon)
            trainer.party.compact!
            raise
          end
          prepare_instant_hatch
          KantoReloaded.toast_success(_INTL("The Egg was moved to the party."))
          log_info("Moved Egg from #{entry[:location_label]} to party")
          true
        rescue StandardError => e
          log_exception("Could not move Egg to party", e)
          KantoReloaded.message(_INTL("The Egg could not be moved to the party."), :theme => :error)
          false
        end

        def release_egg(entry)
          return false unless valid_entry?(entry)
          location = entry[:location_label].to_s
          return false unless KantoReloaded.confirm(
            _INTL("Release the Egg in {1}?", location),
            :default => false
          )
          return false unless KantoReloaded.confirm(
            _INTL("This cannot be undone. Release this Egg permanently?"),
            :default => false,
            :theme => :warning
          )

          pokemon = entry[:pokemon]
          removed = if entry[:location] == :party
                      index = current_party_index(pokemon)
                      index ? !trainer.party.delete_at(index).nil? : false
                    else
                      current = current_pc_pokemon(entry)
                      if current && current.equal?(pokemon)
                        storage[entry[:box], entry[:slot]] = nil
                        true
                      else
                        false
                      end
                    end
          return stale_entry unless removed
          trainer.party.compact! if entry[:location] == :party
          KantoReloaded.toast_success(_INTL("The Egg was released."))
          log_info("Released Egg from #{location}")
          true
        rescue StandardError => e
          log_exception("Could not release Egg", e)
          KantoReloaded.message(_INTL("The Egg could not be released."), :theme => :error)
          false
        end

        def deposit_parent(selection)
          return false unless can_deposit?
          position = normalize_storage_position(selection)
          return false unless position
          box = position[0]
          index = position[1]
          pokemon = storage[box, index]
          unless pokemon
            KantoReloaded.message(_INTL("That Pokemon is no longer in storage."), :theme => :warning)
            return false
          end
          if egg?(pokemon)
            KantoReloaded.message(_INTL("Eggs cannot be deposited in the Day Care."), :theme => :warning)
            return false
          end
          return false unless KantoReloaded.confirm(
            _INTL("Deposit {1} in the Day Care?", pokemon.name),
            :default => false
          )

          if box == -1
            call_global(:pbDayCareDeposit, index)
          else
            deposit_pc_parent(box, index, pokemon)
          end
          KantoReloaded.toast_success(_INTL("{1} was deposited in the Day Care.", pokemon.name))
          origin = box == -1 ? "party" : storage_box_name(box)
          log_info("Deposited #{pokemon.speciesName} from #{origin} in Day Care")
          true
        rescue StandardError => e
          log_exception("Could not deposit Day Care Pokemon", e)
          KantoReloaded.message(_INTL("That Pokemon could not be deposited."), :theme => :error)
          false
        end

        def withdraw_parent(index)
          index = index.to_i
          pokemon = daycare_parent(index)
          return false unless pokemon
          cost = daycare_cost(index)
          if trainer.money.to_i < cost
            KantoReloaded.message(
              _INTL("You need ${1} to withdraw {2}.", format_number(cost), pokemon.name),
              :theme => :warning
            )
            return false
          end
          destination = choose_destination(_INTL("Where should {1} go?", pokemon.name))
          return false unless destination
          warning = waiting_egg? ? _INTL("\nThe waiting Egg will be discarded.") : ""
          destination_name = destination == :party ? _INTL("the party") : _INTL("the PC")
          return false unless KantoReloaded.confirm(
            _INTL("Withdraw {1} to {2} for ${3}?{4}",
                  pokemon.name, destination_name, format_number(cost), warning),
            :default => false,
            :theme => (waiting_egg? ? :warning : :hr)
          )

          old_money = trainer.money.to_i
          stored_box = nil
          begin
            trainer.money = old_money - cost
            if destination == :party
              call_global(:pbDayCareWithdraw, index)
            else
              stored_box = withdraw_parent_to_pc(index, pokemon)
            end
          rescue StandardError
            trainer.money = old_money
            raise
          end
          location = destination == :party ? _INTL("the party") : storage_box_name(stored_box)
          KantoReloaded.toast_success(_INTL("{1} was sent to {2}.", pokemon.name, location))
          log_info("Withdrew #{pokemon.speciesName} from Day Care to #{location}")
          true
        rescue StandardError => e
          log_exception("Could not withdraw Day Care Pokemon", e)
          KantoReloaded.message(_INTL("That Pokemon could not be withdrawn."), :theme => :error)
          false
        end

        def collect_waiting_egg
          unless waiting_egg?
            KantoReloaded.message(_INTL("There is no Egg waiting."), :theme => :warning)
            return false
          end
          destination = choose_destination(_INTL("Where should the waiting Egg go?"))
          return false unless destination
          destination_name = destination == :party ? _INTL("the party") : _INTL("the PC")
          return false unless KantoReloaded.confirm(
            _INTL("Collect the waiting Day Care Egg into {1}?", destination_name),
            :default => true
          )

          stored_box = nil
          if destination == :party
            before = trainer.party.length
            call_global(:pbDayCareGenerateEgg)
            egg = trainer.party[before]
            unless egg?(egg)
              KantoReloaded.message(_INTL("The Day Care Egg could not be collected."), :theme => :error)
              return false
            end
          else
            egg, stored_box = generate_waiting_egg_to_pc
          end
          clear_waiting_egg
          prepare_instant_hatch if destination == :party
          location = destination == :party ? _INTL("the party") : storage_box_name(stored_box)
          KantoReloaded.toast_success(
            _INTL("The {1} Egg was sent to {2}.", egg.speciesName, location)
          )
          log_info("Collected Day Care Egg for #{egg.speciesName} into #{location}")
          true
        rescue StandardError => e
          log_exception("Could not collect Day Care Egg", e)
          KantoReloaded.message(_INTL("The Day Care Egg could not be collected."), :theme => :error)
          false
        end

        def discard_waiting_egg
          return false unless waiting_egg?
          return false unless KantoReloaded.confirm(
            _INTL("Discard the waiting Day Care Egg?"),
            :default => false,
            :theme => :warning
          )
          return false unless KantoReloaded.confirm(
            _INTL("This cannot be undone. Discard the waiting Egg?"),
            :default => false,
            :theme => :warning
          )
          clear_waiting_egg
          KantoReloaded.toast_success(_INTL("The waiting Egg was discarded."))
          log_info("Discarded waiting Day Care Egg")
          true
        rescue StandardError => e
          log_exception("Could not discard Day Care Egg", e)
          KantoReloaded.message(_INTL("The waiting Egg could not be discarded."), :theme => :error)
          false
        end

        def install
          register_action
          register_overworld_menu
          log_info("Installed Egg Manager module")
          true
        rescue StandardError => e
          log_exception("Egg Manager installation failed", e)
          false
        end

        private

        def append_pc_eggs(entries)
          target_storage = storage
          return entries unless target_storage
          target_storage.maxBoxes.times do |box|
            target_storage.maxPokemon(box).times do |slot|
              pokemon = target_storage[box, slot]
              next unless egg?(pokemon)
              entries << {
                :pokemon => pokemon,
                :location => :pc,
                :party_index => nil,
                :box => box,
                :slot => slot,
                :location_label => _INTL("{1}, Slot {2}", storage_box_name(box), slot + 1)
              }
            end
          end
          entries
        end

        def egg?(pokemon)
          pokemon && pokemon.respond_to?(:egg?) && pokemon.egg?
        rescue
          false
        end

        def valid_entry?(entry, location = nil)
          return false unless entry.is_a?(Hash) && egg?(entry[:pokemon])
          return false if location && entry[:location] != location
          true
        end

        def normalize_storage_position(selection)
          position = selection.is_a?(Array) ? selection : [-1, selection]
          return nil if position.length < 2
          box = position[0].to_i
          index = position[1].to_i
          return nil if box < -1 || index < 0
          return nil unless storage
          return nil if box >= storage.maxBoxes
          return nil if index >= storage.maxPokemon(box)
          [box, index]
        rescue
          nil
        end

        def deposit_pc_parent(box, index, pokemon)
          metadata = global_metadata
          daycare = metadata && metadata.respond_to?(:daycare) ? metadata.daycare : nil
          raise _INTL("Day Care data is unavailable.") unless daycare
          daycare_index = (0...2).find do |slot_index|
            slot = daycare[slot_index]
            !slot || !slot[0]
          end
          raise _INTL("No room to deposit a Pokemon.") if daycare_index.nil?

          daycare[daycare_index] ||= [nil, 0]
          destination = daycare[daycare_index]
          old_destination = destination.clone
          old_egg = metadata.daycareEgg if metadata.respond_to?(:daycareEgg)
          old_steps = metadata.daycareEggSteps if metadata.respond_to?(:daycareEggSteps)

          begin
            current = storage[box, index]
            raise _INTL("That Pokemon moved from its PC slot.") unless current && current.equal?(pokemon)
            storage[box, index] = nil
            destination[0] = pokemon
            destination[1] = pokemon.level
            pokemon.heal
            metadata.daycareEgg = 0 if metadata.respond_to?(:daycareEgg=)
            metadata.daycareEggSteps = 0 if metadata.respond_to?(:daycareEggSteps=)
          rescue StandardError
            storage[box, index] = pokemon if storage[box, index].nil?
            destination[0] = old_destination[0]
            destination[1] = old_destination[1]
            metadata.daycareEgg = old_egg if metadata.respond_to?(:daycareEgg=)
            metadata.daycareEggSteps = old_steps if metadata.respond_to?(:daycareEggSteps=)
            raise
          end
          true
        end

        def choose_destination(title)
          party_open = !trainer.party_full?
          pc_open = pc_space_available?
          unless party_open || pc_open
            KantoReloaded.message(
              _INTL("The party and PC are both full."),
              :theme => :warning
            )
            return nil
          end
          return :party if party_open && !pc_open
          return :pc if pc_open && !party_open

          rows = [
            { :label => _INTL("Send to Party"), :value => :party },
            { :label => _INTL("Send to PC"), :value => :pc },
            { :label => _INTL("Back"), :value => :back }
          ]
          selected = KantoReloaded::PopupWindow.choice(title, rows)
          selected == -1 || selected == :back ? nil : selected
        end

        def withdraw_parent_to_pc(index, pokemon)
          raise _INTL("The PC is full.") unless pc_space_available?
          metadata = global_metadata
          daycare = metadata && metadata.respond_to?(:daycare) ? metadata.daycare : nil
          raise _INTL("Day Care data is unavailable.") unless daycare && daycare[index]

          old_slot = daycare[index].clone
          old_egg = metadata.daycareEgg if metadata.respond_to?(:daycareEgg)
          old_steps = metadata.daycareEggSteps if metadata.respond_to?(:daycareEggSteps)
          held_party_member = trainer.party.pop if trainer.party_full?
          party_index = trainer.party.length

          begin
            call_global(:pbDayCareWithdraw, index)
            withdrawn = trainer.party[party_index]
            raise _INTL("The withdrawn Pokemon could not be identified.") unless withdrawn && withdrawn.equal?(pokemon)
            trainer.party.delete_at(party_index)
            stored_box = store_in_pc(pokemon)
            restore_held_party_member(held_party_member)
            held_party_member = nil
            stored_box
          rescue StandardError
            remove_from_storage(pokemon)
            remove_from_party(pokemon)
            daycare[index] ||= [nil, 0]
            daycare[index][0] = old_slot[0]
            daycare[index][1] = old_slot[1]
            metadata.daycareEgg = old_egg if metadata.respond_to?(:daycareEgg=)
            metadata.daycareEggSteps = old_steps if metadata.respond_to?(:daycareEggSteps=)
            raise
          ensure
            restore_held_party_member(held_party_member)
          end
        end

        def generate_waiting_egg_to_pc
          raise _INTL("The PC is full.") unless pc_space_available?
          metadata = global_metadata
          old_egg = metadata.daycareEgg if metadata && metadata.respond_to?(:daycareEgg)
          old_steps = metadata.daycareEggSteps if metadata && metadata.respond_to?(:daycareEggSteps)
          held_party_member = trainer.party.pop if trainer.party_full?
          party_index = trainer.party.length
          generated_egg = nil

          begin
            call_global(:pbDayCareGenerateEgg)
            generated_egg = trainer.party[party_index]
            raise _INTL("The generated Egg could not be identified.") unless egg?(generated_egg)
            trainer.party.delete_at(party_index)
            stored_box = store_in_pc(generated_egg)
            restore_held_party_member(held_party_member)
            held_party_member = nil
            [generated_egg, stored_box]
          rescue StandardError
            candidate = generated_egg || trainer.party[party_index]
            remove_from_storage(candidate) if candidate
            remove_from_party(candidate) if candidate
            metadata.daycareEgg = old_egg if metadata && metadata.respond_to?(:daycareEgg=)
            metadata.daycareEggSteps = old_steps if metadata && metadata.respond_to?(:daycareEggSteps=)
            raise
          ensure
            restore_held_party_member(held_party_member)
          end
        end

        def store_in_pc(pokemon)
          stored_box = storage.pbStoreCaught(pokemon)
          position = storage_position(pokemon)
          unless stored_box && stored_box.to_i >= 0 && position
            remove_from_storage(pokemon)
            raise _INTL("The PC could not store the Pokemon.")
          end
          position[0]
        end

        def storage_position(pokemon)
          return nil unless pokemon && storage
          storage.maxBoxes.times do |box|
            storage.maxPokemon(box).times do |slot|
              return [box, slot] if storage[box, slot].equal?(pokemon)
            end
          end
          nil
        rescue
          nil
        end

        def remove_from_storage(pokemon)
          position = storage_position(pokemon)
          storage[position[0], position[1]] = nil if position
          !position.nil?
        rescue
          false
        end

        def remove_from_party(pokemon)
          return false unless pokemon
          index = trainer.party.index { |candidate| candidate.equal?(pokemon) }
          return false unless index
          trainer.party.delete_at(index)
          trainer.party.compact!
          true
        rescue
          false
        end

        def restore_held_party_member(pokemon)
          return unless pokemon
          return if trainer.party.any? { |candidate| candidate.equal?(pokemon) }
          trainer.party << pokemon
        end

        def current_party_index(pokemon)
          trainer.party.index { |candidate| candidate.equal?(pokemon) }
        rescue
          nil
        end

        def current_pc_pokemon(entry)
          return nil unless storage
          storage[entry[:box], entry[:slot]]
        rescue
          nil
        end

        def storage_contains?(pokemon)
          !storage_position(pokemon).nil?
        rescue
          false
        end

        def storage_box_name(box)
          target_storage = storage
          value = target_storage && target_storage[box]
          name = value && value.respond_to?(:name) ? value.name.to_s : ""
          name.empty? ? _INTL("Box {1}", box.to_i + 1) : name
        rescue
          _INTL("Box {1}", box.to_i + 1)
        end

        def stale_entry
          KantoReloaded.message(
            _INTL("That Egg moved or is no longer available. The list will be refreshed."),
            :theme => :warning
          )
          false
        end

        def oval_charm?
          return false unless defined?(GameData::Item) && GameData::Item.exists?(:OVALCHARM)
          return false unless defined?($PokemonBag) && $PokemonBag
          $PokemonBag.pbHasItem?(:OVALCHARM)
        rescue
          false
        end

        def prepare_instant_hatch
          return unless defined?(KantoReloaded::QualityAssurance::InstantHatch)
          KantoReloaded::QualityAssurance::InstantHatch.prepare_party_eggs
        rescue StandardError => e
          log_exception("Could not apply Instant Hatch to Egg Manager transfer", e)
        end

        def clear_waiting_egg
          metadata = global_metadata
          metadata.daycareEgg = 0 if metadata && metadata.respond_to?(:daycareEgg=)
          metadata.daycareEggSteps = 0 if metadata && metadata.respond_to?(:daycareEggSteps=)
        end

        def call_global(name, *args, &block)
          receiver = Object.new
          receiver.__send__(name, *args, &block)
        end

        def format_number(value)
          value.to_i.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
        rescue
          value.to_i.to_s
        end

        def register_action
          KantoReloaded::Settings.register(ACTION_KEY, {
            :name => "Egg Manager",
            :description => "Inspect and manage Eggs in the party, PC, and Day Care.",
            :type => :button,
            :category => :quality_of_life,
            :owner => :quality_assurance,
            :priority => SETTINGS_PRIORITY,
            :enabled_if => proc {
              KantoReloaded::QualityAssurance::EggManager.available?
            },
            :on_press => proc {
              KantoReloaded::QualityAssurance::EggManager.open
            }
          })
        end

        def register_overworld_menu
          return false unless defined?(OverworldMenu) && OverworldMenu.respond_to?(:register)
          OverworldMenu.register(ACTION_KEY,
            :label => "Egg Manager",
            :priority => OVERWORLD_PRIORITY,
            :default_enabled => false,
            :status => proc {
              counts = KantoReloaded::QualityAssurance::EggManager.egg_counts
              suffix = counts[:waiting] ? " / Egg!" : ""
              "#{counts[:party]} Party / #{counts[:pc]} PC#{suffix}"
            },
            :condition => proc {
              KantoReloaded::QualityAssurance::EggManager.available?
            },
            :handler => proc { |screen|
              screen.run_with_overlay_hidden do
                KantoReloaded::QualityAssurance::EggManager.open
              end
              nil
            }
          )
        end

        def log_info(message)
          KantoReloaded::Log.info(message, :modules) if defined?(KantoReloaded::Log)
        rescue
          nil
        end

        def log_exception(message, exception)
          KantoReloaded::Log.exception(message, exception, channel: :modules) if defined?(KantoReloaded::Log)
        rescue
          nil
        end
      end

      class EggIconSprite < PokemonIconSprite
        def use_big_icon?
          false
        end
      end

      class Scene
        SCREEN_W = 512
        SCREEN_H = 384
        HEADER_H = 40
        TABS_Y = 40
        TABS_H = 28
        CONTENT_Y = 72
        CONTENT_H = 276
        FOOTER_Y = 352
        FOOTER_H = 32

        LIST_X = 8
        LIST_Y = CONTENT_Y
        LIST_W = 252
        DETAIL_X = 268
        DETAIL_Y = CONTENT_Y
        DETAIL_W = 236
        DETAIL_H = CONTENT_H
        LIST_HEADER_H = 52
        ROW_H = 36
        VISIBLE_ROWS = 6
        LIST_JUMP = 3

        WHITE = Color.new(248, 250, 255)
        TEXT = Color.new(224, 232, 244)
        GRAY = Color.new(158, 170, 192)
        DIM = Color.new(102, 112, 136)
        SHADOW = Color.new(0, 0, 0, 0)
        BLUE = Color.new(112, 188, 248)
        TEAL = Color.new(82, 210, 185)
        GREEN = Color.new(95, 215, 135)
        GOLD = Color.new(244, 198, 74)
        CORAL = Color.new(236, 102, 112)
        PANEL = Color.new(8, 18, 34, 225)
        PANEL_ALT = Color.new(14, 30, 48, 232)
        BORDER = Color.new(43, 72, 102, 220)
        ROW = Color.new(255, 255, 255, 10)
        ROW_PARTY = Color.new(72, 190, 155, 35)
        ROW_PC = Color.new(92, 142, 220, 30)
        FOOTER = Color.new(8, 16, 30, 245)
        SHADE = Color.new(4, 10, 20, 148)

        def main
          setup
          while @running
            Graphics.update
            Input.update
            update_icons
            @tick = (@tick + 1) % 120
            handle_input
            draw if (@tick % 4).zero?
          end
          true
        ensure
          teardown
        end

        private

        def setup
          @running = true
          @view = :eggs
          @filter = :all
          @index = 0
          @scroll = 0
          @inspect_entry = nil
          @tick = 0
          @icons = []
          @daycare_buttons = []

          @viewport = Viewport.new(0, 0, SCREEN_W, SCREEN_H)
          @viewport.z = 120_000
          create_background
          @shade = BitmapSprite.new(SCREEN_W, SCREEN_H, @viewport)
          @shade.bitmap.fill_rect(0, 0, SCREEN_W, SCREEN_H, SHADE)
          @canvas = BitmapSprite.new(SCREEN_W, SCREEN_H, @viewport)
          @canvas.z = 2
          rebuild_entries
          draw
        end

        def create_background
          @background = Sprite.new(@viewport)
          @background_asset = AnimatedBitmap.new("Graphics/Pictures/hatchbg")
          @background.bitmap = @background_asset.bitmap
          @background.z = 0
        rescue
          @background = BitmapSprite.new(SCREEN_W, SCREEN_H, @viewport)
          @background.bitmap.fill_rect(0, 0, SCREEN_W, SCREEN_H, Color.new(16, 42, 52))
          @background_asset = nil
        end

        def teardown
          dispose_icons
          if @canvas
            @canvas.bitmap.dispose rescue nil
            @canvas.dispose rescue nil
          end
          if @shade
            @shade.bitmap.dispose rescue nil
            @shade.dispose rescue nil
          end
          @background.dispose rescue nil
          @background_asset.dispose rescue nil
          @viewport.dispose rescue nil
        end

        def rebuild_entries
          current = selected_entry
          @entries = EggManager.egg_entries(@filter)
          if current
            remembered = @entries.index { |entry| entry[:pokemon].equal?(current[:pokemon]) }
            @index = remembered if remembered
          end
          clamp_selection
          refresh_icons
        end

        def selected_entry
          @entries && @entries[@index]
        end

        def clamp_selection
          if !@entries || @entries.empty?
            @index = 0
            @scroll = 0
            return
          end
          @index = [[@index.to_i, 0].max, @entries.length - 1].min
          @scroll = @index if @index < @scroll
          @scroll = @index - VISIBLE_ROWS + 1 if @index >= @scroll + VISIBLE_ROWS
          @scroll = [[@scroll, 0].max, [@entries.length - VISIBLE_ROWS, 0].max].min
        end

        def draw
          bitmap = @canvas.bitmap
          bitmap.clear
          draw_header(bitmap)
          if @inspect_entry
            draw_inspect(bitmap)
          elsif @view == :eggs
            draw_eggs(bitmap)
          else
            draw_daycare(bitmap)
          end
          draw_footer(bitmap)
        rescue StandardError => e
          EggManager.send(:log_exception, "Egg Manager draw failed", e)
        end

        def draw_header(bitmap)
          bitmap.fill_rect(0, 0, SCREEN_W, HEADER_H, Color.new(7, 20, 34, 240))
          bitmap.fill_rect(0, HEADER_H - 1, SCREEN_W, 1, BORDER)
          title_text(bitmap, 16, 4, 270, 30, "EGG MANAGER", WHITE, 26)
          counts = EggManager.egg_counts
          status = _INTL("{1} Party  |  {2} PC", counts[:party], counts[:pc])
          status += _INTL("  |  EGG WAITING") if counts[:waiting]
          text(bitmap, 280, 7, 216, 24, status, counts[:waiting] ? GOLD : GRAY, 14, 2)
          draw_tabs(bitmap) unless @inspect_entry
        end

        def draw_tabs(bitmap)
          tabs = [[:eggs, "EGGS"], [:daycare, "DAY CARE"]]
          width = 112
          start_x = (SCREEN_W - width * tabs.length - 8) / 2
          tabs.each_with_index do |tab, index|
            x = start_x + index * (width + 8)
            active = @view == tab[0]
            fill = active ? Color.new(32, 80, 105, 245) : Color.new(10, 28, 44, 220)
            border = active ? TEAL : BORDER
            panel(bitmap, x, TABS_Y + 2, width, TABS_H - 4, fill, border, 4)
            text(bitmap, x, TABS_Y + 1, width, TABS_H - 2, tab[1], active ? WHITE : GRAY, 16, 1)
          end
        end

        def draw_eggs(bitmap)
          panel(bitmap, LIST_X, LIST_Y, LIST_W, CONTENT_H, PANEL, BORDER, 5)
          panel(bitmap, DETAIL_X, DETAIL_Y, DETAIL_W, DETAIL_H, PANEL_ALT, BORDER, 5)
          draw_filters(bitmap)
          draw_egg_rows(bitmap)
          draw_selected_summary(bitmap)
        end

        def draw_filters(bitmap)
          labels = [[:all, "ALL"], [:party, "PARTY"], [:pc, "PC"]]
          x = LIST_X + 8
          width = 72
          labels.each do |value, label|
            active = @filter == value
            fill = active ? Color.new(34, 86, 108, 235) : Color.new(15, 35, 52, 225)
            panel(bitmap, x, LIST_Y + 8, width, 24, fill, active ? TEAL : BORDER, 4)
            text(bitmap, x, LIST_Y + 5, width, 24, label, active ? WHITE : GRAY, 14, 1)
            x += width + 5
          end
          count_text = _INTL("{1} Egg{2}", @entries.length, @entries.length == 1 ? "" : "s")
          text(bitmap, LIST_X + 10, LIST_Y + 31, LIST_W - 20, 20, count_text, GRAY, 13, 2)
        end

        def draw_egg_rows(bitmap)
          if @entries.empty?
            text(bitmap, LIST_X + 18, LIST_Y + 118, LIST_W - 36, 28,
                 _INTL("No Eggs found in this location."), GRAY, 16, 1)
            return
          end
          visible = @entries[@scroll, VISIBLE_ROWS] || []
          visible.each_with_index do |entry, local_index|
            index = @scroll + local_index
            y = LIST_Y + LIST_HEADER_H + local_index * ROW_H
            selected = index == @index
            fill = entry[:location] == :party ? ROW_PARTY : ROW_PC
            fill = cursor_fill if selected
            panel(bitmap, LIST_X + 6, y, LIST_W - 12, ROW_H - 3, fill,
                  selected ? cursor_border : nil, 4)
            text(bitmap, LIST_X + 45, y - 1, 116, 19, _INTL("Egg"), selected ? WHITE : TEXT, 16)
            text(bitmap, LIST_X + 45, y + 14, 151, 17, compact_location(entry), GRAY, 12)
            steps = EggManager.remaining_steps(entry[:pokemon])
            text(bitmap, LIST_X + 174, y + 1, 69, 18, format_steps(steps),
                 steps <= 1 ? GOLD : (entry[:location] == :pc ? BLUE : TEAL), 12, 2)
            draw_progress(bitmap, LIST_X + 174, y + 23, 62, 5,
                          EggManager.hatch_progress(entry[:pokemon]),
                          entry[:location] == :pc ? BLUE : GREEN)
          end
          if @entries.length > VISIBLE_ROWS
            label = _INTL("{1}-{2} / {3}", @scroll + 1,
                          [@scroll + VISIBLE_ROWS, @entries.length].min, @entries.length)
            text(bitmap, LIST_X + 8, LIST_Y + CONTENT_H - 21, LIST_W - 16, 18, label, DIM, 12, 1)
          end
        end

        def draw_selected_summary(bitmap)
          entry = selected_entry
          unless entry
            text(bitmap, DETAIL_X + 16, DETAIL_Y + 112, DETAIL_W - 32, 24,
                 _INTL("Select an Egg to inspect or manage."), GRAY, 16, 1)
            return
          end
          text(bitmap, DETAIL_X + 12, DETAIL_Y + 10, DETAIL_W - 24, 24,
               _INTL("SELECTED EGG"), TEAL, 18, 1)
          text(bitmap, DETAIL_X + 12, DETAIL_Y + 87, DETAIL_W - 24, 22,
               entry[:location_label], WHITE, 15, 1)
          remaining = EggManager.remaining_steps(entry[:pokemon])
          progress = EggManager.hatch_progress(entry[:pokemon])
          text(bitmap, DETAIL_X + 16, DETAIL_Y + 118, DETAIL_W - 32, 22,
               _INTL("{1} steps remaining", format_number(remaining)), TEXT, 16, 1)
          draw_progress(bitmap, DETAIL_X + 24, DETAIL_Y + 146, DETAIL_W - 48, 10,
                        progress, entry[:location] == :pc ? BLUE : GREEN)
          text(bitmap, DETAIL_X + 16, DETAIL_Y + 159, DETAIL_W - 32, 20,
               _INTL("{1}% complete", (progress * 100).round), GRAY, 14, 1)
          status = EggManager.hatch_status(entry[:pokemon], entry[:location])
          text_lines(bitmap, status, DETAIL_X + 18, DETAIL_Y + 190, DETAIL_W - 36, 20, GOLD, 14, 1)
          action = entry[:location] == :party ? _INTL("Can move to PC") : _INTL("Can move to Party")
          text(bitmap, DETAIL_X + 16, DETAIL_Y + 239, DETAIL_W - 32, 18, action, DIM, 12, 1)
        end

        def draw_inspect(bitmap)
          entry = @inspect_entry
          pokemon = entry && entry[:pokemon]
          panel(bitmap, 12, CONTENT_Y, SCREEN_W - 24, CONTENT_H, PANEL_ALT, BORDER, 6)
          unless pokemon
            text(bitmap, 24, CONTENT_Y + 110, SCREEN_W - 48, 28,
                 _INTL("This Egg is no longer available."), CORAL, 18, 1)
            return
          end

          text(bitmap, 28, CONTENT_Y + 10, 456, 27, pokemon.speciesName, WHITE, 24, 1)
          form = form_name(pokemon)
          subtitle = []
          subtitle << form unless form.empty?
          subtitle << (pokemon.shiny? ? _INTL("Shiny") : _INTL("Not Shiny"))
          text(bitmap, 116, CONTENT_Y + 40, 368, 22, subtitle.join("  |  "),
               pokemon.shiny? ? GOLD : GRAY, 14)

          nature = pokemon.nature
          ability = pokemon.ability
          ball = poke_ball_name(pokemon)
          text(bitmap, 116, CONTENT_Y + 67, 176, 20,
               _INTL("Nature: {1}", nature ? nature.name : "Unknown"), TEXT, 14)
          text(bitmap, 300, CONTENT_Y + 67, 184, 20,
               _INTL("Ability: {1}", ability ? ability.name : "Unknown"), TEXT, 14)
          text(bitmap, 116, CONTENT_Y + 89, 176, 20,
               _INTL("Ball: {1}", ball), TEXT, 14)
          text(bitmap, 300, CONTENT_Y + 89, 184, 20,
               _INTL("Location: {1}", compact_location(entry)), TEXT, 14)

          progress = EggManager.hatch_progress(pokemon)
          draw_progress(bitmap, 116, CONTENT_Y + 116, 368, 10, progress, GREEN)
          text(bitmap, 116, CONTENT_Y + 128, 368, 18,
               _INTL("{1} steps remaining  |  {2}% complete",
                     format_number(EggManager.remaining_steps(pokemon)), (progress * 100).round),
               GRAY, 13, 1)

          text(bitmap, 28, CONTENT_Y + 157, 210, 20, _INTL("INDIVIDUAL VALUES"), TEAL, 15)
          iv_lines(pokemon).each_with_index do |line, index|
            text(bitmap, 28, CONTENT_Y + 179 + index * 19, 216, 19, line, TEXT, 13)
          end

          text(bitmap, 260, CONTENT_Y + 157, 224, 20, _INTL("INHERITED MOVES"), BLUE, 15)
          move_names(pokemon).each_with_index do |move, index|
            text(bitmap, 260, CONTENT_Y + 179 + index * 19, 224, 19, move, TEXT, 13)
          end
        end

        def draw_daycare(bitmap)
          draw_parent_card(bitmap, 8, CONTENT_Y, 244, 130, 0)
          draw_parent_card(bitmap, 260, CONTENT_Y, 244, 130, 1)
          draw_compatibility(bitmap)
          draw_daycare_actions(bitmap)
        end

        def draw_parent_card(bitmap, x, y, width, height, index)
          parent = EggManager.daycare_parent(index)
          panel(bitmap, x, y, width, height, PANEL_ALT, BORDER, 6)
          label = index == 0 ? _INTL("LEFT PARENT") : _INTL("RIGHT PARENT")
          text(bitmap, x + 10, y + 5, width - 20, 22, label, index == 0 ? TEAL : BLUE, 15, 1)
          bitmap.fill_rect(x + 10, y + 29, width - 20, 1, BORDER)
          unless parent
            text(bitmap, x + 18, y + 59, width - 36, 24, _INTL("Day Care slot is empty."), DIM, 15, 1)
            return
          end
          deposit_level = EggManager.daycare_deposit_level(index)
          gained = [parent.level.to_i - deposit_level, 0].max
          gender = parent.male? ? _INTL("Male") : (parent.female? ? _INTL("Female") : _INTL("Genderless"))
          held = parent.item ? parent.item.name : _INTL("None")
          text(bitmap, x + 76, y + 33, width - 88, 20, parent.name, WHITE, 17)
          text(bitmap, x + 76, y + 52, width - 88, 18, parent.speciesName, GRAY, 13)
          text(bitmap, x + 76, y + 72, width - 88, 18,
               _INTL("{1}  |  Lv. {2} (+{3})", gender, parent.level, gained), TEXT, 13)
          text(bitmap, x + 76, y + 91, width - 88, 18, _INTL("Held: {1}", held), TEXT, 13)
          cost = EggManager.daycare_cost(index)
          text(bitmap, x + 76, y + 108, width - 88, 18,
               _INTL("Withdraw: ${1}", format_number(cost)), GOLD, 13)
        end

        def draw_compatibility(bitmap)
          y = CONTENT_Y + 138
          panel(bitmap, 8, y, 496, 72, PANEL, BORDER, 6)
          compatibility = EggManager.daycare_compatibility
          color = compatibility == 0 ? CORAL : (compatibility == 1 ? GOLD : GREEN)
          text(bitmap, 20, y + 7, 220, 22, EggManager.daycare_compatibility_label, color, 17)
          chance = EggManager.daycare_chance
          charm = EggManager.send(:oval_charm?) ? _INTL("Oval Charm active") : _INTL("No Oval Charm")
          text(bitmap, 20, y + 29, 220, 18,
               _INTL("{1}% chance each check", chance), TEXT, 13)
          text(bitmap, 20, y + 47, 220, 18, charm, GRAY, 12)

          waiting = EggManager.waiting_egg?
          steps = waiting ? 256 : EggManager.daycare_cycle_steps
          text(bitmap, 264, y + 8, 220, 20,
               waiting ? _INTL("EGG WAITING") : _INTL("NEXT BREEDING CHECK"),
               waiting ? GOLD : BLUE, 16, 1)
          draw_progress(bitmap, 284, y + 35, 172, 10, steps.to_f / 256, waiting ? GOLD : BLUE)
          detail = waiting ? _INTL("Ready to collect") : _INTL("{1} / 256 steps", steps)
          text(bitmap, 264, y + 47, 220, 18, detail, waiting ? GOLD : GRAY, 13, 1)
        end

        def draw_daycare_actions(bitmap)
          @daycare_buttons = []
          y = CONTENT_Y + 218
          buttons = [
            [:deposit, _INTL("Deposit Party / PC"), EggManager.can_deposit?],
            [:withdraw_left, _INTL("Withdraw Left"), EggManager.can_withdraw?(0)],
            [:withdraw_right, _INTL("Withdraw Right"), EggManager.can_withdraw?(1)],
            [:collect, _INTL("Collect Egg"), EggManager.waiting_egg?],
            [:discard, _INTL("Discard Egg"), EggManager.waiting_egg?]
          ]
          button_w = 156
          button_h = 23
          buttons.each_with_index do |button, index|
            row = index / 3
            col = index % 3
            x = 8 + col * 166
            by = y + row * 28
            enabled = button[2]
            destructive = button[0] == :discard
            fill = enabled ? Color.new(18, 48, 64, 235) : Color.new(12, 24, 36, 210)
            border = if enabled
                       destructive ? CORAL : TEAL
                      else
                        Color.new(45, 58, 72)
                      end
            panel(bitmap, x, by, button_w, button_h, fill, border, 4)
            text(bitmap, x, by - 2, button_w, button_h, button[1],
                 enabled ? (destructive ? CORAL : WHITE) : DIM, 13, 1)
            @daycare_buttons << {
              :action => button[0],
              :enabled => enabled,
              :x => x,
              :y => by,
              :width => button_w,
              :height => button_h
            }
          end
        end

        def draw_footer(bitmap)
          bitmap.fill_rect(0, FOOTER_Y, SCREEN_W, FOOTER_H, FOOTER)
          bitmap.fill_rect(0, FOOTER_Y, SCREEN_W, 1, BORDER)
          entries = if @inspect_entry
                      [KantoReloaded::HintText.back("Egg List")]
                    else
                      [
                        KantoReloaded::HintText.confirm(@view == :eggs ? "Actions" : "Manage"),
                        KantoReloaded::HintText.back("Close"),
                        KantoReloaded::HintText.action("Switch View"),
                        KantoReloaded::HintText.special("Controls")
                      ]
                    end
          KantoReloaded::HintText.draw(bitmap, entries, 8, FOOTER_Y + 3, SCREEN_W - 16, :size => 14)
        rescue
          nil
        end

        def refresh_icons
          dispose_icons
          if @inspect_entry
            create_reveal_icon(@inspect_entry)
          elsif @view == :eggs
            create_egg_list_icons
            create_selected_egg_icon
          else
            create_parent_sprites
            create_waiting_egg_icon if EggManager.waiting_egg?
          end
        end

        def create_egg_list_icons
          visible = @entries[@scroll, VISIBLE_ROWS] || []
          visible.each_with_index do |entry, local_index|
            icon = EggIconSprite.new(entry[:pokemon], @viewport)
            icon.setOffset(PictureOrigin::Center) if defined?(PictureOrigin)
            icon.x = LIST_X + 27
            icon.y = LIST_Y + LIST_HEADER_H + local_index * ROW_H + 16
            icon.z = 5
            @icons << icon
          end
        rescue StandardError => e
          EggManager.send(:log_exception, "Could not create Egg list icons", e)
        end

        def create_selected_egg_icon
          entry = selected_entry
          return unless entry
          icon = EggIconSprite.new(entry[:pokemon], @viewport)
          icon.setOffset(PictureOrigin::Center) if defined?(PictureOrigin)
          icon.x = DETAIL_X + DETAIL_W / 2
          icon.y = DETAIL_Y + 64
          icon.zoom_x = 1.5
          icon.zoom_y = 1.5
          icon.z = 5
          @icons << icon
        rescue StandardError => e
          EggManager.send(:log_exception, "Could not create selected Egg icon", e)
        end

        def create_reveal_icon(entry)
          pokemon = entry[:pokemon]
          @reveal_clone = pokemon.clone
          @reveal_clone.steps_to_hatch = 0
          icon = EggIconSprite.new(@reveal_clone, @viewport)
          icon.setOffset(PictureOrigin::Center) if defined?(PictureOrigin)
          icon.x = 72
          icon.y = CONTENT_Y + 91
          icon.zoom_x = 1.35
          icon.zoom_y = 1.35
          icon.z = 5
          @icons << icon
        rescue StandardError => e
          EggManager.send(:log_exception, "Could not create revealed Egg icon", e)
        end

        def create_parent_sprites
          [0, 1].each do |index|
            parent = EggManager.daycare_parent(index)
            next unless parent
            x = index == 0 ? 46 : 298
            sprite = PokemonSprite.new(@viewport)
            sprite.setPokemonBitmap(parent)
            sprite.setOffset(PictureOrigin::Center) if defined?(PictureOrigin)
            fit_sprite(sprite, 60, 84)
            sprite.x = x
            sprite.y = CONTENT_Y + 78
            sprite.z = 5
            @icons << sprite
          end
        rescue StandardError => e
          EggManager.send(:log_exception, "Could not create Day Care parent sprites", e)
        end

        def fit_sprite(sprite, maximum_width, maximum_height)
          bitmap = sprite && sprite.bitmap
          return unless bitmap && bitmap.width.to_i > 0 && bitmap.height.to_i > 0
          scale = [
            maximum_width.to_f / bitmap.width,
            maximum_height.to_f / bitmap.height,
            1.0
          ].min
          sprite.zoom_x = scale
          sprite.zoom_y = scale
        end

        def create_waiting_egg_icon
          @waiting_asset = AnimatedBitmap.new("Graphics/Icons/iconEgg")
          sprite = Sprite.new(@viewport)
          sprite.bitmap = @waiting_asset.bitmap
          frame = sprite.bitmap.height
          sprite.src_rect = Rect.new(0, 0, frame, frame)
          sprite.x = 464
          sprite.y = CONTENT_Y + 160
          sprite.z = 5
          @icons << sprite
        rescue StandardError => e
          EggManager.send(:log_exception, "Could not create waiting Egg icon", e)
        end

        def dispose_icons
          Array(@icons).each { |icon| icon.dispose rescue nil }
          @icons = []
          @waiting_asset.dispose rescue nil
          @waiting_asset = nil
          @reveal_clone = nil
        end

        def update_icons
          @icons.each { |icon| icon.update rescue nil }
          return unless @waiting_asset && @icons.last && @icons.last.respond_to?(:src_rect)
          frame = @waiting_asset.bitmap.height
          frames = [@waiting_asset.bitmap.width / frame, 1].max
          index = ((Graphics.frame_count rescue 0) / 20) % frames
          @icons.last.src_rect.x = index * frame
        rescue
          nil
        end

        def handle_input
          return handle_inspect_input if @inspect_entry
          mouse_result = handle_mouse
          return if mouse_result
          if trigger?(:SPECIAL)
            show_controls
          elsif trigger?(:ACTION)
            switch_view
          elsif trigger?(:BACK)
            pbPlayCloseMenuSE rescue nil
            @running = false
          elsif @view == :eggs
            handle_egg_input
          else
            handle_daycare_input
          end
        end

        def handle_inspect_input
          if trigger?(:BACK) || trigger?(:USE) || KantoReloaded::MouseInput.mouse_triggered?
            pbPlayCancelSE rescue nil
            @inspect_entry = nil
            refresh_icons
            draw
            drain_input
          end
        end

        def handle_egg_input
          if repeat?(:UP)
            move_selection(-1)
          elsif repeat?(:DOWN)
            move_selection(1)
          elsif repeat?(:LEFT)
            move_selection(-LIST_JUMP)
          elsif repeat?(:RIGHT)
            move_selection(LIST_JUMP)
          elsif trigger?(:USE)
            open_egg_actions
          end
        end

        def handle_daycare_input
          open_daycare_actions if trigger?(:USE)
        end

        def handle_mouse
          wheel = KantoReloaded::MouseInput.wheel_delta
          position = KantoReloaded::MouseInput.active_position
          return false unless position
          x = position[0]
          y = position[1]
          if @view == :eggs && inside?(x, y, LIST_X, LIST_Y + LIST_HEADER_H, LIST_W, ROW_H * VISIBLE_ROWS)
            move_selection(wheel < 0 ? 1 : -1) unless wheel == 0
            row = @scroll + ((y - LIST_Y - LIST_HEADER_H) / ROW_H)
            if row >= 0 && row < @entries.length && @index != row
              @index = row
              clamp_selection
              refresh_icons
              pbPlayCursorSE rescue nil
              draw
            end
          end
          return false unless KantoReloaded::MouseInput.mouse_triggered?

          if KantoReloaded::HintText.controls_at?(
            @canvas.bitmap, x, y, 8, FOOTER_Y + 3, SCREEN_W - 16,
            :height => 24,
            :hint_entry => KantoReloaded::HintText.special("Controls")
          )
            show_controls
            return true
          end

          tab_width = 112
          tab_start = (SCREEN_W - tab_width * 2 - 8) / 2
          if inside?(x, y, tab_start, TABS_Y + 2, tab_width, TABS_H - 4)
            set_view(:eggs)
            return true
          elsif inside?(x, y, tab_start + tab_width + 8, TABS_Y + 2, tab_width, TABS_H - 4)
            set_view(:daycare)
            return true
          end
          if @view == :eggs
            filter = filter_at(x, y)
            if filter
              set_filter(filter)
              return true
            end
            if inside?(x, y, LIST_X, LIST_Y + LIST_HEADER_H, LIST_W, ROW_H * VISIBLE_ROWS)
              open_egg_actions
              return true
            end
          else
            button = @daycare_buttons.find do |candidate|
              inside?(x, y, candidate[:x], candidate[:y], candidate[:width], candidate[:height])
            end
            if button
              button[:enabled] ? perform_daycare_action(button[:action]) : (pbPlayBuzzerSE rescue nil)
              return true
            end
          end
          false
        rescue StandardError => e
          EggManager.send(:log_exception, "Egg Manager mouse handling failed", e)
          false
        end

        def filter_at(x, y)
          start_x = LIST_X + 8
          [:all, :party, :pc].each_with_index do |filter, index|
            fx = start_x + index * 77
            return filter if inside?(x, y, fx, LIST_Y + 8, 72, 24)
          end
          nil
        end

        def move_selection(amount)
          return if @entries.empty?
          old = @index
          @index = [[@index + amount, 0].max, @entries.length - 1].min
          return if old == @index
          clamp_selection
          refresh_icons
          pbPlayCursorSE rescue nil
          draw
        end

        def switch_view
          set_view(@view == :eggs ? :daycare : :eggs)
        end

        def set_view(view)
          return if @view == view
          @view = view
          refresh_icons
          pbPlayCursorSE rescue nil
          draw
          drain_input
        end

        def set_filter(filter)
          return unless FILTERS.include?(filter)
          @filter = filter
          @index = 0
          @scroll = 0
          rebuild_entries
          pbPlayCursorSE rescue nil
          draw
          drain_input
        end

        def open_egg_actions
          entry = selected_entry
          unless entry
            rows = filter_rows
            choice = KantoReloaded::PopupWindow.choice(_INTL("Choose an Egg location."), rows)
            set_filter(choice) if FILTERS.include?(choice)
            return
          end
          destination = entry[:location] == :party ? _INTL("Move to PC") : _INTL("Move to Party")
          rows = [
            { :label => _INTL("Inspect Egg"), :value => :inspect },
            { :label => destination, :value => :move },
            { :label => _INTL("Release Egg"), :value => :release },
            { :label => _INTL("Change Location Filter"), :value => :filter },
            { :label => _INTL("Back"), :value => :back }
          ]
          choice = KantoReloaded::PopupWindow.choice(
            _INTL("Manage the Egg in {1}.", entry[:location_label]),
            rows
          )
          case choice
          when :inspect
            @inspect_entry = entry
            refresh_icons
          when :move
            changed = entry[:location] == :party ? EggManager.move_to_pc(entry) : EggManager.move_to_party(entry)
            rebuild_entries if changed
          when :release
            rebuild_entries if EggManager.release_egg(entry)
          when :filter
            selected = KantoReloaded::PopupWindow.choice(_INTL("Choose an Egg location."), filter_rows)
            set_filter(selected) if FILTERS.include?(selected)
          end
          draw
          drain_input
        end

        def filter_rows
          [
            { :label => _INTL("All Eggs"), :value => :all },
            { :label => _INTL("Party Eggs"), :value => :party },
            { :label => _INTL("PC Eggs"), :value => :pc },
            { :label => _INTL("Back"), :value => :back }
          ]
        end

        def open_daycare_actions
          rows = [
            {
              :label => _INTL("Deposit Pokemon"),
              :value => :deposit,
              :enabled => EggManager.can_deposit?
            },
            {
              :label => _INTL("Withdraw Left Parent"),
              :value => :withdraw_left,
              :enabled => EggManager.can_withdraw?(0)
            },
            {
              :label => _INTL("Withdraw Right Parent"),
              :value => :withdraw_right,
              :enabled => EggManager.can_withdraw?(1)
            },
            {
              :label => _INTL("Collect Waiting Egg"),
              :value => :collect,
              :enabled => EggManager.waiting_egg?
            },
            {
              :label => _INTL("Discard Waiting Egg"),
              :value => :discard,
              :enabled => EggManager.waiting_egg?
            },
            { :label => _INTL("Back"), :value => :back }
          ]
          choice = KantoReloaded::PopupWindow.choice(_INTL("Manage the Day Care."), rows)
          perform_daycare_action(choice) unless choice == -1 || choice == :back
        end

        def perform_daycare_action(action)
          changed = case action
                    when :deposit
                      position = choose_deposit_pokemon
                      position.nil? ? false : EggManager.deposit_parent(position)
                    when :withdraw_left
                      EggManager.withdraw_parent(0)
                    when :withdraw_right
                      EggManager.withdraw_parent(1)
                    when :collect
                      EggManager.collect_waiting_egg
                    when :discard
                      EggManager.discard_waiting_egg
                    else
                      false
                    end
          if changed
            rebuild_entries
            refresh_icons
          end
          draw
          drain_input
          changed
        end

        def choose_deposit_pokemon
          unless EggManager.storage &&
                 defined?(PokemonStorageScene) && defined?(PokemonStorageScreen)
            KantoReloaded.message(_INTL("Pokemon Storage is unavailable."), :theme => :warning)
            return nil
          end

          loop do
            selected = nil
            with_scene_hidden do
              storage_scene = PokemonStorageScene.new
              storage_screen = PokemonStorageScreen.new(storage_scene, EggManager.storage)
              selected = storage_screen.pbChoosePokemon
            end
            drain_input
            return nil unless selected.is_a?(Array) && selected.length >= 2
            pokemon = EggManager.storage[selected[0], selected[1]]
            next unless pokemon
            if pokemon.egg?
              KantoReloaded.message(
                _INTL("Eggs cannot be deposited in the Day Care."),
                :theme => :warning
              )
              next
            end
            return [selected[0].to_i, selected[1].to_i]
          end
        rescue StandardError => e
          EggManager.send(:log_exception, "Could not open Day Care storage picker", e)
          KantoReloaded.message(_INTL("Pokemon Storage could not be opened."), :theme => :error)
          nil
        end

        def with_scene_hidden
          was_visible = @viewport.visible if @viewport && @viewport.respond_to?(:visible)
          @viewport.visible = false if @viewport && @viewport.respond_to?(:visible=)
          yield
        ensure
          @viewport.visible = was_visible unless was_visible.nil? || !@viewport.respond_to?(:visible=)
        end

        def show_controls
          entries = [
            KantoReloaded::HintText.confirm(@view == :eggs ? "Egg Actions" : "Day Care Actions"),
            KantoReloaded::HintText.back("Close"),
            KantoReloaded::HintText.action("Switch Eggs / Day Care"),
            KantoReloaded::HintText.special("Controls"),
            KantoReloaded::HintText.other("Move 1", "Up/Down"),
            KantoReloaded::HintText.other("Jump 3", "Left/Right"),
            KantoReloaded::HintText.other("Scroll", "Wheel")
          ]
          KantoReloaded::HintText.open_popup(_INTL("Egg Manager Controls"), entries)
          drain_input
        end

        def compact_location(entry)
          return _INTL("Party {1}", entry[:party_index].to_i + 1) if entry[:location] == :party
          entry[:location_label].to_s
        end

        def format_steps(value)
          value.to_i <= 1 ? _INTL("READY") : format_number(value)
        end

        def format_number(value)
          value.to_i.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
        rescue
          value.to_i.to_s
        end

        def form_name(pokemon)
          data = pokemon.species_data
          value = data.respond_to?(:form_name) ? data.form_name.to_s : ""
          return "" if value.empty?
          _INTL("Form: {1}", value)
        rescue
          ""
        end

        def poke_ball_name(pokemon)
          return _INTL("Unknown") unless pokemon.respond_to?(:poke_ball)
          item = GameData::Item.try_get(pokemon.poke_ball)
          item ? item.name : pokemon.poke_ball.to_s
        rescue
          _INTL("Unknown")
        end

        def iv_lines(pokemon)
          values = IV_ORDER.map do |stat_id|
            stat = GameData::Stat.get(stat_id)
            name = stat.respond_to?(:name_brief) ? stat.name_brief : stat.name
            [name.to_s, pokemon.iv[stat_id].to_i]
          end
          [
            values[0, 3].map { |value| "#{value[0]} #{value[1]}" }.join("   "),
            values[3, 3].map { |value| "#{value[0]} #{value[1]}" }.join("   ")
          ]
        rescue
          [_INTL("IV data unavailable")]
        end

        def move_names(pokemon)
          names = Array(pokemon.moves).map do |move|
            move.respond_to?(:name) ? move.name.to_s : move.to_s
          end.reject(&:empty?).first(4)
          names.empty? ? [_INTL("No inherited moves")] : names
        rescue
          [_INTL("Move data unavailable")]
        end

        def panel(bitmap, x, y, width, height, fill, border = nil, radius = 4)
          KantoReloaded::UI::Draw.rounded_rect(bitmap, x, y, width, height, radius, fill, nil)
          return unless border
          radius = [[radius.to_i, width / 2, height / 2].min, 0].max
          bitmap.fill_rect(x + radius, y, width - radius * 2, 1, border)
          bitmap.fill_rect(x + radius, y + height - 1, width - radius * 2, 1, border)
          bitmap.fill_rect(x, y + radius, 1, height - radius * 2, border)
          bitmap.fill_rect(x + width - 1, y + radius, 1, height - radius * 2, border)
        end

        def text(bitmap, x, y, width, height, value, color = TEXT, size = 16, align = 0)
          pbSetSmallFont(bitmap) if defined?(pbSetSmallFont)
          bitmap.font.shadow = false if bitmap.respond_to?(:font) && bitmap.font.respond_to?(:shadow=)
          fitted_size = fitted_text_size(bitmap, value, width, size)
          KantoReloaded::UI::Draw.plain_text(
            bitmap, x, y, width, height, value, color, align, fitted_size
          )
        end

        def title_text(bitmap, x, y, width, height, value, color = WHITE, size = 26, align = 0)
          pbSetSystemFont(bitmap) if defined?(pbSetSystemFont)
          fitted_size = fitted_text_size(bitmap, value, width, size)
          KantoReloaded::UI::Draw.plain_text(
            bitmap, x, y, width, height, value, color, align, fitted_size
          )
        end

        def text_lines(bitmap, value, x, y, width, line_height, color, size, align = 0)
          measure = Bitmap.new(1, 1)
          pbSetSmallFont(measure) if defined?(pbSetSmallFont)
          measure.font.size = size
          lines = KantoReloaded::UI::Draw.wrap_lines(measure, value, width)
          measure.dispose
          lines.first(3).each_with_index do |line, index|
            text(bitmap, x, y + index * line_height, width, line_height, line, color, size, align)
          end
        rescue
          text(bitmap, x, y, width, line_height, value, color, size, align)
        end

        def draw_progress(bitmap, x, y, width, height, progress, color)
          progress = [[progress.to_f, 0.0].max, 1.0].min
          panel(bitmap, x, y, width, height, Color.new(4, 12, 22, 220), BORDER, [height / 2, 3].min)
          inner = [(width - 2) * progress, 0].max.to_i
          bitmap.fill_rect(x + 1, y + 1, inner, [height - 2, 1].max, color) if inner > 0
        end

        def fitted_text_size(bitmap, value, width, preferred)
          return preferred unless bitmap && bitmap.respond_to?(:text_size)
          old_size = bitmap.font.size
          size = preferred.to_i
          minimum = [size, 10].min
          while size > minimum
            bitmap.font.size = size
            break if bitmap.text_size(value.to_s).width <= width - 4
            size -= 1
          end
          size
        rescue
          preferred
        ensure
          bitmap.font.size = old_size if bitmap && bitmap.respond_to?(:font) && old_size rescue nil
        end

        def cursor_fill
          pulse = Math.sin((Graphics.frame_count rescue 0) * Math::PI / 20.0) * 0.5 + 0.5
          Color.new(42, 104, 128, 145 + (pulse * 55).to_i)
        end

        def cursor_border
          TEAL
        end

        def inside?(x, y, left, top, width, height)
          x >= left && x < left + width && y >= top && y < top + height
        end

        def trigger?(name)
          KantoReloaded::MouseInput.input_triggered?(name)
        end

        def repeat?(name)
          KantoReloaded::MouseInput.input_repeated?(name)
        end

        def drain_input
          KantoReloaded::UI::Modal.drain_input if defined?(KantoReloaded::UI::Modal)
        rescue
          nil
        end
      end
    end
  end
end

KantoReloaded::QualityAssurance::EggManager.install
