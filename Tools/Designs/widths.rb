PREVIEW = File.join(ARGV[0], "Mods/KantoReloaded/Tools/UIPreview/preview.rb")
src = File.read(PREVIEW, :encoding => "UTF-8")
eval(src.split("#---------------------------------------------------------------- A: Ocean Blue")[0], binding, PREVIEW)
PF = KIF::PixelFont
["Trainer Card", "Kuray Shop", "PokeVial", "TM Vault", "Pokédex", "Cerulean City", "Wednesday 3:42 PM"].each do |s|
  puts "#{s}: TEXT #{PF.width(PF::TEXT, s)} TINY #{PF.width(PF::TINY, s)} ROW #{PF.width(PF::ROW, s)}"
end
