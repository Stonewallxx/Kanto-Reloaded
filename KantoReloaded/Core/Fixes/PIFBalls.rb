# encoding: utf-8
#==============================================================================
# Fixes: PIF's Pure Ball and Status Ball (052_InfiniteFusion/Gameplay/Items/
# New Balls.rb:99-107), found by Quick Throw's prep (his pick, 2026-10-29:
# fixed for everyone, Quick Throw on or off)
#==============================================================================
#   pif_pure_status_balls  Both compared a status with 0, but a status is a
#                          symbol (:NONE when there's none): the Pure Ball
#                          ("works better on a Pokémon with no status") never
#                          got its x3.5 and the Status Ball ("works better on
#                          a Pokémon with a status") always got its x2.5.
#                          Now each works as its description says.
#==============================================================================

module Reloaded
  module Fixes
    PURE_BALL_CRC = 4112649643         # New Balls.rb:99-102 as PIF has it
    STATUS_BALL_CRC = 326228735        # New Balls.rb:104-107
  end
end

Reloaded::Fixes.register(:pif_pure_status_balls, "PIF's Pure Ball works on a Pokémon with no status and its Status Ball on one with a status") do
  next false unless defined?(::BallHandlers::ModifyCatchRate)
  rates = ::BallHandlers::ModifyCatchRate
  fx = Reloaded::Fixes
  pure = rates[:PUREBALL]
  status = rates[:STATUSBALL]
  next false unless pure && status
  next false unless fx.handler_crc(pure) == fx::PURE_BALL_CRC && fx.handler_crc(status) == fx::STATUS_BALL_CRC
  rates.add(:PUREBALL, proc { |_ball, catchRate, _battle, battler|
    next battler.status == :NONE ? (catchRate * 7 / 2).floor : catchRate
  })
  rates.add(:STATUSBALL, proc { |_ball, catchRate, _battle, battler|
    next battler.status != :NONE ? (catchRate * 5 / 2).floor : catchRate
  })
  next true
end
