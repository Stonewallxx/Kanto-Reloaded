#==============================================================================
# Fixes: PIF's Bag (013_Items/008_PokemonBag.rb), found by the Reloaded Bag's
# prep (his pick, 2026-10-23: fixed for everyone, the Reloaded Bag on or off)
#==============================================================================
#   bag_change_quantity  PokemonBag#pbChangeQuantity asks the Bag for
#                        numPockets, which only the class has: any call
#                        would crash. The Bag answers it now.
#   bag_sort_direction   PIF's Sort Bag keeps one "backwards" flag for every
#                        pocket and every kind of sort, so a sort runs
#                        backwards whenever the last one anywhere ran
#                        forwards. Now only sorting the same pocket the same
#                        way again turns it round. And the pocket is sorted
#                        in place (the game's own lists keep it).
#   pinkan_toss          Taking any item out of the Bag on Pinkan Island
#                        (a Toss, a Potion) played a sound and redrew the
#                        Pinkan Berries: now only Pinkan Berries do.
#==============================================================================

module Reloaded
  module Fixes
    module BagNumPockets
      def numPockets
        return self.class.numPockets
      end
    end

    module BagSortDirection
      SORTS = [:sort_pocket_alphabetically, :sort_pocket_by_quantity, :sort_pocket_by_tm_number, :sort_pocket_by_move_type].freeze

      SORTS.each do |name|
        define_method(name) do |*args, &blk|
          pocket = @lastpocket
          before = @pockets[pocket]
          again = @kr_last_sort == [pocket, name]
          @descending_sort = again ? !@kr_last_descending : false
          ret = super(*args, &blk)
          @kr_last_sort = [pocket, name]
          @kr_last_descending = !@descending_sort      # PIF flips it after sorting
          if before.is_a?(Array) && !@pockets[pocket].equal?(before)
            before.replace(@pockets[pocket])
            @pockets[pocket] = before
          end
          ret
        end
      end
    end

    @deleting = nil     # the item PokemonBag#pbDeleteItem is taking out now

    class << self
      attr_accessor :deleting
    end
  end
end

Reloaded::Fixes.register(:bag_change_quantity, "The Bag's pbChangeQuantity no longer crashes (it asked the Bag for numPockets)") do
  next false unless defined?(::PokemonBag) && ::PokemonBag.respond_to?(:numPockets)
  next false if ::PokemonBag.method_defined?(:numPockets)
  Reloaded::Hooks.prepend(nil, ::PokemonBag, Reloaded::Fixes::BagNumPockets, :id => :fix_bag_num_pockets)
end

Reloaded::Fixes.register(:bag_sort_direction, "PIF's Sort Bag turns round only on the same pocket and sort again, and sorts in place") do
  next false unless defined?(::PokemonBag)
  sorts = Reloaded::Fixes::BagSortDirection::SORTS
  next false unless sorts.all? { |m| ::PokemonBag.method_defined?(m) }
  Reloaded::Hooks.prepend(nil, ::PokemonBag, Reloaded::Fixes::BagSortDirection, :id => :fix_bag_sort_direction)
end

Reloaded::Fixes.register(:pinkan_toss, "On Pinkan Island, only Pinkan Berries leaving the Bag redraw them (and play the sound)") do
  next false unless defined?(::PokemonBag) && ::PokemonBag.method_defined?(:pbDeleteItem)
  next false unless Object.private_method_defined?(:updatePinkanBerryDisplay) || Object.method_defined?(:updatePinkanBerryDisplay)
  Reloaded::Hooks.around(nil, ::PokemonBag, :pbDeleteItem, :id => :fix_pinkan_delete) do |original, item, *rest|
    before = Reloaded::Fixes.deleting
    Reloaded::Fixes.deleting = (::GameData::Item.get(item).id rescue item)
    begin
      original.call(item, *rest)
    ensure
      Reloaded::Fixes.deleting = before
    end
  end
  Reloaded::Hooks.around(nil, ::Object, :updatePinkanBerryDisplay, :id => :fix_pinkan_display) do |original, *args|
    gone = Reloaded::Fixes.deleting
    next nil if gone && gone != :PINKANBERRY
    original.call(*args)
  end
  next true
end
