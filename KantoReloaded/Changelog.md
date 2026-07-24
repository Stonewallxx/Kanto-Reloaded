══════════════════════════════════════════════
KANTO RELOADED
Update #1 - Reloaded PC
v1.2.0
Release Date: July 23, 2026
══════════════════════════════════════════════

SUMMARY
-------
This update adds dynamic randomization, save management, and a Reloaded PC interface while improving existing QoL systems.

FEATURES
--------
• Added a Randomizer module with per-encounter wild Pokemon and per-pickup item randomization
• Added Wild Selection for switching between BST-matched and fully random encounters
• Added a Reloaded PC toggle with Reloaded-only animation, speed, and Pokemon art settings
• Added Reloaded PC Speed with Off, 2x, and 3x modes. Speed-Up button is disabled in the RLD PC.
• Added Reloaded PC controls with L/R box switching, X-button focus cycling, A-button Normal, Quick Swap, and Multi Select modes, and a Z-button Reloaded PC menu
• Added a Big Icons option for switching between icons and full sprites
• Added Reloaded PC mouse controls with click-or-drag Quick Swap pickup, carry-aware box-panel wheel navigation, clickable footer controls and adjacent-box headers, drag-hover box switching, drag-and-drop moving or swapping, and right-click action menus
• Added EBDX-compatible reverse fusion support
• Added Save Manager for safely archiving, restoring, inspecting, and permanently removing save files

IMPROVEMENTS
------------
• Updated the About screen and framework services to read Kanto Reloaded's version directly from `mod.json`
• Changed TM Vault's Relearn Moves control to Input Y

BUG FIXES
---------
• Fixed Autosort Bag legacy text export/import
• Fixed Upgraded PP to refill a move only when its maximum PP is first upgraded
• Fixed Interface settings to persist globally across saves and game restarts while keeping Battle Menu layout customization per-save
• Fixed File A Bug Report to open the dedicated Kanto Reloaded bug-report Discord thread
• Fixed Back input activating the highlighted row in shared popups

VISUALS & UI
------------
• Expanded About with Author and Discord Link rows
• Removed hint footers from category-only and action-only Options pages
• Aligned read-only option values with the value column used by adjustable options
• Rounded the type icons shown in TM Vault
• Updated standard shared confirmations to begin on Yes while serious prompts continue to begin on No

TECHNICAL
---------
• Added one-time migration for legacy Dynamic Randomiser wild and item settings

DEVELOPER
---------
• Added the stable `KantoReloaded::Randomizer` API contract and documented its guarded integration boundaries
• Added the stable `KantoReloaded::PCOrganization` menu-command registry contract
• Added Pokemon, box, and multi-selection action registries for extending Reloaded PC without replacing its menus
