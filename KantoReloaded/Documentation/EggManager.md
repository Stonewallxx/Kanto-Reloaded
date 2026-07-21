# Egg Manager

Egg Manager is a Kanto Reloaded Quality of Life action implemented by
`Modules/QualityAssurance/EggManager.rb`.

It is available from KR's Quality of Life category and as an optional Overworld
Menu command. The Overworld Menu command is disabled in the page editor by
default.

## Eggs View

The Eggs view indexes:

- Every Egg in the current party.
- Every Egg in every box of the active KIF PC storage.

The list displays each Egg's location, remaining hatch steps, and progress.
Eggs stored in the PC are marked as paused because KIF only advances party Egg
incubation.

Available actions:

- Inspect Egg.
- Move a party Egg to the PC.
- Move a PC Egg to the party.
- Release an Egg after two confirmations.
- Filter the list by All, Party, or PC.

Inspect Egg reveals the generated Pokemon's species and form, shiny status,
nature, ability, IVs, current inherited moves, Poke Ball, location, and hatch
progress. These details are not shown in the normal Egg list.

## Day Care View

The Day Care view displays:

- Both deposited parents.
- Each parent with its full out-of-battle Pokemon sprite rather than its party
  icon.
- Name, species, gender, current level, levels gained, held item, and current
  withdrawal cost.
- Breeding compatibility and the current per-check Egg chance.
- Oval Charm status.
- Progress toward the next 256-step breeding check.
- Whether an Egg is waiting for collection.

Available actions:

- Open KIF's native storage interface and deposit a non-Egg Pokemon from either
  the party or any PC box. The native selector retains Summary, item, marking,
  and Store/Withdraw commands.
- Withdraw either parent to the party or PC and pay KIF's current withdrawal
  cost.
- Collect a waiting Egg into the party or PC.
- Discard a waiting Egg after two confirmations.

Withdrawing a parent while an Egg is waiting warns that KIF will discard the
waiting Egg.

## Runtime Boundaries

Egg Manager does not replace, copy, or alias KIF's breeding implementation.
It calls the current:

- `pbDayCareDeposit`
- `pbDayCareWithdraw`
- `pbDayCareGenerateEgg`

Calling the native Day Care generation method preserves current KIF and
compatible mod behavior. KR clears the waiting state only after the generated
Egg is confirmed in the party. Production forced-Egg generation and
breeding-timer manipulation are not provided.

Party-origin deposits call KIF's current `pbDayCareDeposit`. KIF has no native
PC-to-Day-Care operation, so PC-origin deposits use a KR-owned transactional
transfer into the first open Day Care slot. The exact source box slot, Day Care
destination, and waiting-Egg fields are restored if the transfer raises. No
storage or Day Care base method is replaced.

Withdrawals and Egg collection continue to call KIF's current
`pbDayCareWithdraw` and `pbDayCareGenerateEgg`, including any compatible
wrappers around those methods. When a PC destination is selected and the party
is full, KR temporarily holds the last party member, lets KIF complete the
operation in the open slot, transfers the result to PC storage, and restores
the held party member in its original position. A failed transfer restores the
party, Day Care slot, waiting-Egg state, breeding-step counter, and withdrawal
money.

Party-to-PC transfers remove the party source only after the PC accepts the
Egg. PC-to-party transfers roll back the party append if clearing the source
slot fails. Withdrawal money is restored if native withdrawal raises an error.

When Instant Hatch is enabled, an Egg collected from the Day Care or moved into
the party is immediately prepared to hatch on the next step.

## Controls

- `Up`/`Down`: move one Egg.
- `Left`/`Right`: jump three Eggs.
- `Confirm`: open Egg or Day Care actions.
- `Back`: close the manager or return from Inspect Egg.
- `Action`: switch between Eggs and Day Care.
- `Special`: open the controls reference.
- Mouse wheel: scroll the Egg list.

Mouse hover changes selection only while the mouse is actively moving or
clicking. A stationary cursor does not override keyboard or controller input.
