#==============================================================================
# Kanto Reloaded: Quality of Life: Super Candy
#==============================================================================
# Raises the party to a level (the level cap, the highest in the party, or
# one of the player's own), one level at a time as a Rare Candy would, but
# quietly: each level's new moves are learned as the game learns them
# (Level-Up Moves applies), and evolutions come after, as after a
# battle (pbEvolutionCheck, so KIF's evolution lock is kept). No item is
# used. A level lock (Level Locking On) and the level cap stop it; Eggs
# are left as they are.
#==============================================================================

module Reloaded
  module QualityOfLife
    module SuperCandy
      class << self
        # [level it would reach, why]: :ok, :locked_at (a lock stops it
        # short), :locked (locked at its level now), :already
        def reach(pkmn, target)
          lock = Reloaded::QualityOfLife::LevelLocks.limit(pkmn)
          return [pkmn.level, :locked] if lock && lock <= pkmn.level
          goal = [target, Reloaded::QualityOfLife.level_cap(pkmn)].min
          stopped = lock && lock < goal
          goal = lock if stopped
          return [pkmn.level, :already] if goal <= pkmn.level
          return [goal, stopped ? :locked_at : :ok]
        end

        # What happened to each: { :pokemon, :result, :from, :to, :learned, :evolved }
        def raise_party(target)
          party = Reloaded::QualityOfLifeScreens.party
          before = party.map(&:level)
          results = party.map do |pkmn|
            next { :pokemon => pkmn, :result => :egg, :learned => [] } if pkmn.egg?
            to, why = reach(pkmn, target)
            from = pkmn.level
            next { :pokemon => pkmn, :result => why, :from => from, :to => from, :learned => [] } if [:locked, :already].include?(why)
            known = pkmn.moves.map { |m| m.id }
            (from + 1..to).each { |lv| raise_one(pkmn, lv) }
            learned = pkmn.moves.map { |m| m.id } - known
            { :pokemon => pkmn, :result => why == :locked_at ? :lock_stop : :ok, :from => from, :to => pkmn.level,
              :learned => learned.map { |id| (GameData::Move.get(id).name rescue id.to_s) }, :species => pkmn.species }
          end
          Reloaded::Log.info("Super Candy: the party raised to Lv #{target}.", :quality_of_life)
          pbEvolutionCheck(before) if respond_to?(:pbEvolutionCheck, true)
          results.each { |r| r[:evolved] = r[:species] && r[:pokemon].species != r[:species] }
          return results
        end

        def raise_one(pkmn, lv)
          pkmn.level = lv
          pkmn.changeHappiness("vitamin") if pkmn.respond_to?(:changeHappiness)
          pkmn.calc_stats
          pkmn.getMoveList.each do |at, move|
            next unless at == lv
            Reloaded::QualityOfLife::Hooks.level_up { pbLearnMove(pkmn, move, true) }
          end
        rescue StandardError => e
          Reloaded::Log.exception("Super Candy couldn't raise #{pkmn.name} to Lv #{lv}", e, :quality_of_life)
        end
      end
    end
  end
end
