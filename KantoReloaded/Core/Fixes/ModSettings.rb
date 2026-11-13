# encoding: utf-8
#==============================================================================
# Fix: KIF's Mod Settings with Kanto Reloaded installed (990_KIF/F-CORE-09_
# ModCompat/ModSettingsMenu.rb), found 2026-11-01
#==============================================================================
#   ModSettingsMenu is the settings API catalog mods use (KIF-ER, Megas,
#   Alpha Encounters, GhostNPC Wandering Trainers...). KIF provides it,
#   except when a mod with the id KantoReloaded is installed: the old Kanto
#   Reloaded brought its own. This one doesn't, so with it installed no
#   mod's settings had a row anywhere (KIF Settings > Mods had no Settings
#   part) and every mod ran on its defaults.
#   At boot, KIF's own install runs again with its Kanto Reloaded check
#   answered No: ModSettingsMenu is KIF's, so are its values file
#   (KIF_ModSettings.kro, all saves) and its rows in KIF Settings > Mods.
#   Registrations mods queued while it was missing ($MOD_SETTINGS_PENDING_
#   REGISTRATIONS: KIF-ER's) run then, each as the mod whose file queued it
#   (KIF::Mods.current), so its rows list under that mod. Mods loading after
#   Kanto Reloaded (Megas, Alpha Encounters) register as usual.
#   A mod that loaded before Kanto Reloaded and registers only when the API
#   is already there (GhostNPC Wandering Trainers: `if defined?
#   (ModSettingsMenu) ... end` at the top level of its main.rb) skipped that
#   block as it loaded. For each mod that loaded first and has no settings
#   yet, every such block in the files KIF loaded for it (no else: a block
#   with one already took its other way) runs now, once, as that mod: what
#   it would have done with the API there. Its own code, from its own file:
#   nothing is copied.
#   Once KIF drops its Kanto Reloaded check, this fix finds ModSettingsMenu
#   already made and stays off.
#==============================================================================

module Reloaded
  module Fixes
    module ModSettings
      GUARD = /\Aif\s+defined\?\(\s*(?:::)?ModSettingsMenu\s*\)/   # a block that runs only with the API there
      BLOCK_END = /\A(?:end|else|elsif)\b/
      END_LINE = /\Aend\b/

      module_function

      def apply
        return false if defined?(::ModSettingsMenu)        # KIF's own (or the original mod) is already there
        ms = defined?(::KIF::ModSettings) ? ::KIF::ModSettings : nil
        return false unless ms && ms.respond_to?(:install) && ms.respond_to?(:kanto_reloaded_installed?)
        Reloaded::Hooks.around(nil, ms.singleton_class, :kanto_reloaded_installed?, :id => :fix_mod_settings) { |_original, *_args| false }
        queued = take_queued
        unless ms.install(folder) && defined?(::ModSettingsMenu)
          requeue(queued)
          return false
        end
        run_queued(queued)
        run_skipped
        return true
      end

      def folder
        return defined?(::KIF::Mods::FOLDER) ? ::KIF::Mods::FOLDER : "Mods"
      end

      # The queue, taken out before KIF's install runs it (it would run them
      # all as Kanto Reloaded, the mod loading now)
      def take_queued
        list = $MOD_SETTINGS_PENDING_REGISTRATIONS
        return [] unless list.is_a?(Array)
        out = list.dup
        list.clear
        return out
      end

      def requeue(list)
        return if list.empty?
        ($MOD_SETTINGS_PENDING_REGISTRATIONS ||= []).unshift(*list)
      end

      # Each one as the mod whose file queued it
      def run_queued(list)
        return if list.empty?
        mods = defined?(::KIF::Mods) && ::KIF::Mods.respond_to?(:current=) ? ::KIF::Mods : nil
        was = mods ? mods.current : nil
        roots = mod_roots
        list.each do |pr|
          begin
            mods.current = owner(pr, roots) if mods
            pr.call
          rescue StandardError => e
            Reloaded::Log.exception("A mod's queued settings didn't register", e, :fixes)
          end
        end
      ensure
        mods.current = was if mods
      end

      # [folder, mod id] of every installed mod with a folder
      def mod_roots
        return [] unless defined?(::KIF::Mods) && ::KIF::Mods.respond_to?(:entries)
        return Array(::KIF::Mods.entries).filter_map do |e|
          next nil unless e.respond_to?(:path) && e.respond_to?(:id) && e.path && !e.path.to_s.empty?
          [File.expand_path(e.path.to_s).downcase, e.id]
        end
      rescue StandardError => e
        Reloaded::Log.exception("The installed mods couldn't be listed", e, :fixes)
        return []
      end

      # The mod whose folder holds the file the block was written in, or nil
      def owner(pr, roots)
        loc = pr.respond_to?(:source_location) ? pr.source_location : nil
        return nil unless loc && loc[0]
        path = File.expand_path(loc[0].to_s).downcase
        hit = roots.find { |root, _id| path.start_with?(root + "/") }
        return hit ? hit[1] : nil
      end

      # The guarded blocks of the mods that loaded first and have no settings
      def run_skipped
        have = ::KIF::ModSettings.registry.map { |e| e[:mod].to_s }
        loaded_first.each do |id, files|
          next if have.include?(id.to_s)
          files.each { |file| guarded_blocks(file).each { |line, code| run_block(id, file, line, code) } }
        end
      end

      # [[mod id, files KIF loaded for it], ...]: the folders and the loose
      # .rb files that loaded before Kanto Reloaded
      def loaded_first
        m = defined?(::KIF::Mods) ? ::KIF::Mods : nil
        return [] unless m && [:loaded_dirs, :loaded_root, :loaded_file?, :entries].all? { |s| m.respond_to?(s) }
        entries = Array(m.entries)
        out = []
        Array(m.loaded_dirs).each do |dir|
          root = File.expand_path(dir.to_s)
          e = entries.find { |x| x.respond_to?(:path) && x.path && File.expand_path(x.path.to_s).casecmp?(root) }
          next unless e
          files = Dir.glob("**/*.rb", :base => root).sort.map { |f| File.join(root, f) }.select { |f| m.loaded_file?(f) }
          out << [e.id, files]
        end
        Array(m.loaded_root).each do |id|
          e = entries.find { |x| x.id == id }
          out << [id, [File.expand_path(e.path.to_s)]] if e && e.path
        end
        return out
      rescue StandardError => e
        Reloaded::Log.exception("The mods loaded before Kanto Reloaded couldn't be listed", e, :fixes)
        return []
      end

      # [[line, code], ...]: each top-level `if defined?(ModSettingsMenu)`
      # block with no else, to its `end` at the start of a line
      def guarded_blocks(file)
        lines = File.readlines(file, :encoding => "UTF-8")
        lines[0] = lines[0].sub(/\A﻿/, "") unless lines.empty?
        out = []
        i = 0
        while i < lines.length
          if lines[i] =~ GUARD
            j = ((i + 1)...lines.length).find { |k| lines[k] =~ BLOCK_END }
            break unless j
            if lines[j] =~ END_LINE
              out << [i + 1, lines[i..j].join]
            else
              j = (j...lines.length).find { |k| lines[k] =~ END_LINE } || lines.length   # past its else
            end
            i = j
          end
          i += 1
        end
        return out
      rescue StandardError => e
        Reloaded::Log.exception("#{File.basename(file.to_s)} couldn't be read for its settings", e, :fixes)
        return []
      end

      # One block, as its mod, from its own file and line
      def run_block(id, file, line, code)
        m = ::KIF::Mods
        was = m.current
        m.current = id
        eval(code, TOPLEVEL_BINDING, file, line)
        Reloaded::Log.info("#{id}'s settings registered now (#{File.basename(file)}:#{line}): it loaded before Kanto Reloaded", :fixes)
      rescue StandardError => e
        Reloaded::Log.exception("#{id}'s settings couldn't be registered (#{File.basename(file)}:#{line})", e, :fixes)
      ensure
        m.current = was if m
      end
    end
  end
end

Reloaded::Fixes.register(:kif_mod_settings, "Other mods' settings (KIF-ER, Megas, Alpha Encounters...) have their rows in KIF Settings > Mods again") do
  next Reloaded::Fixes::ModSettings.apply
end
