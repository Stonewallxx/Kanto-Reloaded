# encoding: utf-8
# Dumps an RMXP map's tiles and its tileset's image names to JSON, for
# map_render.py (a backdrop for the pause menu mockups).
# Usage: ruby map_dump.rb "<KIF Beta>" <map id or name> <out.json>
require "json"

class Table
  attr_reader :xsize, :ysize, :zsize, :data
  def self._load(s)
    t = allocate
    _dim, x, y, z, _n = s[0, 20].unpack("l5")
    t.instance_variable_set(:@xsize, x); t.instance_variable_set(:@ysize, y); t.instance_variable_set(:@zsize, z)
    t.instance_variable_set(:@data, s[20..-1].unpack("s*"))
    t
  end
end
class Color; def self._load(s); allocate; end; end
class Tone; def self._load(s); allocate; end; end
module RPG
  class MapInfo; end; class Map; end; class Tileset; end; class AudioFile; end
  class MoveRoute; end; class MoveCommand; end; class EventCommand; end
  class Event; class Page; class Condition; end; class Graphic; end; end; end
  class CommonEvent; end
end

root = ARGV[0]
infos = Marshal.load(File.binread(File.join(root, "Data/MapInfos.rxdata")))
want = ARGV[1]
id = want =~ /\A\d+\z/ ? want.to_i : infos.find { |_, i| i.instance_variable_get(:@name) == want }&.first
abort "no map #{want}" unless id
map = Marshal.load(File.binread(File.join(root, format("Data/Map%03d.rxdata", id))))
tilesets = Marshal.load(File.binread(File.join(root, "Data/Tilesets.rxdata")))
ts = tilesets[map.instance_variable_get(:@tileset_id)]
d = map.instance_variable_get(:@data)
out = {
  "name" => infos[id].instance_variable_get(:@name),
  "w" => d.xsize, "h" => d.ysize, "z" => d.zsize, "data" => d.data,
  "tileset" => ts.instance_variable_get(:@tileset_name),
  "autotiles" => ts.instance_variable_get(:@autotile_names),
  "priorities" => ts.instance_variable_get(:@priorities).data
}
File.write(ARGV[2], JSON.generate(out))
puts "#{id} #{out['name']} #{out['w']}x#{out['h']} tileset #{out['tileset']}"
