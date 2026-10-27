# encoding: utf-8
#==============================================================================
# Kanto Reloaded: Double Abilities (Banned Pairs)
#==============================================================================
# Two abilities a fusion can't have together, each with a badge and its
# reason in plain words (his picks 2026-10-26: Q6 the Full Page, Q7 all seven
# kept). The Fusion Screen, the capsules, the worked-out second and the
# battle all ask here; the Banned Pairs page lists them, leaving off a pair
# while one of its abilities isn't in the game's data (Perish Body is only
# there with KIF: Elite Redux; Water Bubble and Shadow Shield are on no
# species, but the Randomizer and mods can give them). With KIF: Elite
# Redux's Innates On its own rules apply instead (EliteRedux.rb).
#
#   Reloaded::DoubleAbilities.ban(:HUGEPOWER, :PUREPOWER, :badge => "x4 ATK",
#     :tone => :red, :short => "Attack x4",
#     :reason => "Both double its Attack: Together it would be quadrupled.",
#     :owner => :my_mod)
#   Reloaded::DoubleAbilities::Banned.banned?(a, b)   either order
#   Reloaded::DoubleAbilities::Banned.with(a, b)      the pair's entry
#   Reloaded::DoubleAbilities::Banned.shown           the page's pairs
#==============================================================================

module Reloaded
  module DoubleAbilities
    module Banned
      Pair = Struct.new(:a, :b, :badge, :tone, :short, :reason, :owner)
      # Kanto Reloaded's (old Kanto Reloaded's list; the reasons checked on
      # PIF's own handlers in the prep, verify_dispatch.rb)
      OWN = [
        [:WONDERGUARD, :STURDY, "NO KO", :blue, "Can't be knocked out by a hit",
         "Wonder Guard leaves it 1 HP, and Sturdy saves a Pokémon at full HP from any hit: No attack could ever knock it out."],
        [:HUGEPOWER, :PUREPOWER, "x4 ATK", :red, "Attack x4",
         "Both double its Attack: Together it would be quadrupled."],
        [:HUGEPOWER, :WATERBUBBLE, "x4 ATK", :red, "Water moves' Attack x4",
         "Water Bubble doubles its Water moves' Attack, Huge Power all its physical moves: Water moves would hit at x4."],
        [:PUREPOWER, :WATERBUBBLE, "x4 ATK", :red, "Water moves' Attack x4",
         "Water Bubble doubles its Water moves' Attack, Pure Power all its physical moves: Water moves would hit at x4."],
        [:MULTISCALE, :SHADOWSHIELD, "x1/4 DMG", :blue, "Damage x1/4 at full HP",
         "Both halve the damage it takes at full HP: Together it would take a quarter."],
        [:ILLUSION, :IMPOSTER, "CLASH", :amber, "The disguises clash",
         "Both change what it looks like when it comes in: The disguise and the transformation break each other."],
        [:SHADOWTAG, :PERISHBODY, "TRAPPED", :amber, "Trapped and fainted",
         "Shadow Tag stops the foe switching out, so Perish Body's count would faint it for certain."]
      ].freeze
      @pairs = {}
      @order = []

      class << self
        def install
          OWN.each do |a, b, badge, tone, short, reason|
            ban(a, b, :badge => badge, :tone => tone, :short => short, :reason => reason, :owner => :kanto_reloaded)
          end
        end

        def pair_key(a, b)
          return [a.to_s, b.to_s].sort.map(&:to_sym)
        end

        def ban(a, b, options = {})
          a = a.to_sym
          b = b.to_sym
          k = pair_key(a, b)
          @order << k unless @pairs.has_key?(k)
          @pairs[k] = Pair.new(a, b, (options[:badge] || "BANNED").to_s, options[:tone] || :red,
                               (options[:short] || "Banned").to_s, (options[:reason] || "").to_s, options[:owner])
          return true
        end

        def unban(a, b)
          k = pair_key(a, b)
          @order.delete(k)
          return !@pairs.delete(k).nil?
        end

        def with(a, b)
          return nil if a.nil? || b.nil? || a == b
          return @pairs[pair_key(a, b)]
        end

        def banned?(a, b)
          return !with(a, b).nil?
        end

        def all
          return @order.map { |k| @pairs[k] }
        end

        # The page's: a pair whose abilities are both in the game's data
        def shown
          return all.select { |p| ::GameData::Ability.exists?(p.a) && ::GameData::Ability.exists?(p.b) }
        rescue StandardError
          return all
        end
      end
    end

    class << self
      def ban(a, b, options = {})
        return Banned.ban(a, b, options)
      end
    end
  end
end
