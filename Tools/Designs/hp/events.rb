require "json"
eval(File.read("map_dump.rb").split("root = ARGV[0]")[0])
root = ARGV[0]
map = Marshal.load(File.binread(File.join(root, format("Data/Map%03d.rxdata", ARGV[1].to_i))))
map.instance_variable_get(:@events).each do |id, e|
  pg = e.instance_variable_get(:@pages)[0]
  g = pg.instance_variable_get(:@graphic)
  puts [id, e.instance_variable_get(:@name), e.instance_variable_get(:@x), e.instance_variable_get(:@y),
        g.instance_variable_get(:@character_name), g.instance_variable_get(:@direction), g.instance_variable_get(:@pattern), g.instance_variable_get(:@tile_id)].inspect
end
