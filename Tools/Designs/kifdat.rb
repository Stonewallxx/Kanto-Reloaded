# Loads an encrypted KIF Beta data file (Encryption.xor, 16-byte key) with stub classes.
KEY = [0x4A, 0x8F, 0x2C, 0xE1, 0x73, 0xB5, 0x96, 0x0D, 0x5E, 0xA2, 0x3F, 0xC7, 0x81, 0x14, 0x6B, 0xD9]
module GameData
  def self.const_missing(n); const_set(n, Class.new); end
  class Encounter; end; class Species; end; class Move; end; class Item; end; class Type; end; class Ability; end
end
class Object
  def self.const_missing(n); Object.const_set(n, Class.new); end
end
def kif_load(path)
  raw = File.binread(path).bytes
  dec = raw.each_with_index.map { |b, i| b ^ KEY[i % 16] }.pack("C*")
  Marshal.load(dec)
end
