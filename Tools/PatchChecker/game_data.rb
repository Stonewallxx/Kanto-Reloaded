# encoding: utf-8
# KIF Beta's data, loaded outside the game the way the game loads it: its
# data classes (Data/Scripts/010_Data) and .dat files, on the engine's
# stand-ins (Tools/Tests/test_stubs.rb). The Patch Checker and the Data
# Patches test load this, then Kanto Reloaded's Bootstrap.rb. Set KIF_ROOT,
# USERDIR (an empty folder) and $log first. Not loaded by the game.
# A release keeps Tools/Tests/test_stubs.rb: the Patch Checker needs it.
require "json"
load File.join(KIF_ROOT, "Mods/KantoReloaded/Tools/Tests/test_stubs.rb")

SCRIPTS = File.join(KIF_ROOT, "Data", "Scripts")
def pbGetMessage(*a); nil; end
def pbGetMessageFromHash(*a); nil; end
module MessageTypes; def self.const_missing(n); const_set(n, 0); end; def self.get(*a); nil; end; end
module Settings
  NB_POKEMON = 576 unless const_defined?(:NB_POKEMON)
  MAX_PARTY_SIZE = 6 unless const_defined?(:MAX_PARTY_SIZE)
  def self.const_missing(n); const_set(n, 0); end
end
NB_POKEMON = 576 unless defined?(NB_POKEMON)
class PokemonSystem; attr_accessor :runstyle, :textskin; end

module GameDataLoader
  CLASSES = %w[Type Ability Move Item Species Encounter EncounterModern EncounterRandom
               TrainerType Trainer TrainerModern TrainerExpert].freeze

  def self.files
    return ["001_Technical/000_Encryption.rb", "010_Data/001_GameData.rb"] +
           Dir.glob(File.join(SCRIPTS, "010_Data/001_Hardcoded data/*.rb")).sort.map { |f| f.sub(SCRIPTS + "/", "") } +
           %w[003_Type 004_Ability 005_Move 006_Item 008_Species 011_Encounter 011_EncounterModern 011_Encounter_random
              012_TrainerType 013_Trainer 013_TrainerModern 013_TrainerExpert].map { |n| "010_Data/002_PBS data/#{n}.rb" } +
           ["053_PIF_Hoenn/Contests/Pokemon Contests/006_ContestMoves.rb"]
  end

  def self.load_all
    verbose = $VERBOSE
    $VERBOSE = nil
    files.each { |f| load File.join(SCRIPTS, f) }
    Dir.chdir(KIF_ROOT) { CLASSES.each { |c| GameData.const_get(c).load } }
  ensure
    $VERBOSE = verbose
  end

  # The game's outfits (their classes, and the lists made from its outfit
  # JSON), as the outfit targets need them. Paths as KIF's Settings has them.
  OUTFIT_FILES = %w[wrappers/001_Outfit wrappers/Clothes wrappers/Hat wrappers/Hairstyle 001_OutfitsMain/OutfitsGlobal].freeze

  def self.load_outfits
    settings = File.read(File.join(SCRIPTS, "001_Settings.rb"), :encoding => "UTF-8")
    %w[HATS_DATA_PATH HAIRSTYLE_DATA_PATH CLOTHES_DATA_PATH].each do |c|
      rel = settings[/#{c}\s*=\s*"([^"]+)"/, 1]
      ::Settings.const_set(c, File.join(KIF_ROOT, rel)) if rel && !::Settings.const_defined?(c, false)
    end
    OUTFIT_FILES.each { |f| load File.join(SCRIPTS, "050_Outfits", "#{f}.rb") }
  end

  # KIF Beta's version, from its README script ("0.21.55"), or nil.
  def self.kif_version
    text = File.read(File.join(SCRIPTS, "990_KIF/000_README.rb"), :encoding => "UTF-8")
    return text[/PORT_VERSION\s*=\s*"([^"]+)"/, 1]
  rescue StandardError
    return nil
  end
end

module HTTPLite; module JSON; def self.parse(text); ::JSON.parse(text); end; end; end unless defined?(HTTPLite)
def _OUTFIT_INTL(text); text; end unless defined?(_OUTFIT_INTL)

GameDataLoader.load_all
GameDataLoader.load_outfits
