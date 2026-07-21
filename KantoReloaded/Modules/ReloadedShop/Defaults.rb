#==============================================================================
# Kanto Reloaded - Reloaded Shop Defaults
#==============================================================================

module KantoReloaded
  module ReloadedShop
    module Defaults
      CATEGORIES = [
        { "id" => "items",       "name" => "Items" },
        { "id" => "medicine",    "name" => "Medicine" },
        { "id" => "poke_balls",  "name" => "Pokeballs" },
        { "id" => "tms_hms",     "name" => "TM/HMs" },
        { "id" => "berries",     "name" => "Berries" },
        { "id" => "battle_items","name" => "Battle Items" },
        { "id" => "kuray_eggs",  "name" => "K-Eggs" },
        { "id" => "key_items",   "name" => "Key Items" },
        { "id" => "mail",        "name" => "Mail" }
      ].freeze

      # All stock the KIF Pause Menu may expose. Actual availability still comes
      # from the stock array KIF builds when the shop is opened.
      KIF_ITEM_IDS = [
        570, 569, 568, 245, 247, 249, 246, 248, 250,
        121, 122, 123, 124, 125, 126,
        303, 314, 329, 335, 343, 345, 346, 356, 358, 367,
        618, 619, 646, 647, 648, 649, 650, 651, 652, 653, 654,
        655, 656, 657, 659,
        114, 115, 116, 100, 194, 235, 263, 264, 3, 68, 623,
        2000, 2001, 2032, 2021, 2020,
        2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010,
        2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019,
        2022, 2023, 2024, 2025, 2026, 2027, 2028, 2029, 2030,
        2031
      ].freeze

      POCKET_CATEGORIES = {
        1 => "items",
        2 => "medicine",
        3 => "poke_balls",
        4 => "tms_hms",
        5 => "berries",
        6 => "mail",
        7 => "battle_items",
        8 => "key_items"
      }.freeze

      module_function

      def category_for(item)
        data = GameData::Item.try_get(item) rescue nil
        return "items" unless data
        number = data.id_number.to_i rescue 0
        return "kuray_eggs" if number >= 2000 && number <= 2032
        POCKET_CATEGORIES[data.pocket.to_i] || "items"
      end

      def categories
        CATEGORIES.each_with_index.map do |entry, index|
          entry.merge("order" => index)
        end
      end
    end
  end
end
