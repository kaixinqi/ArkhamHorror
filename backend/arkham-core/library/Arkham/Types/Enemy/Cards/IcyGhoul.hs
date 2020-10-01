{-# LANGUAGE UndecidableInstances #-}
module Arkham.Types.Enemy.Cards.IcyGhoul where

import Arkham.Json
import Arkham.Types.Classes
import Arkham.Types.Enemy.Attrs
import Arkham.Types.Enemy.Runner
import Arkham.Types.EnemyId
import Arkham.Types.GameValue
import Arkham.Types.Message
import ClassyPrelude

newtype IcyGhoul = IcyGhoul Attrs
  deriving newtype (Show, ToJSON, FromJSON)

icyGhoul :: EnemyId -> IcyGhoul
icyGhoul uuid = IcyGhoul $ (baseAttrs uuid "01119")
  { enemyHealthDamage = 2
  , enemySanityDamage = 1
  , enemyFight = 3
  , enemyHealth = Static 4
  , enemyEvade = 4
  }

instance HasModifiersFor env investigator IcyGhoul where
  getModifiersFor _ _ = pure []

instance HasModifiers env IcyGhoul where
  getModifiers (IcyGhoul Attrs {..}) = pure . concat . toList $ enemyModifiers

instance (IsInvestigator investigator) => HasActions env investigator IcyGhoul where
  getActions i window (IcyGhoul attrs) = getActions i window attrs

instance (EnemyRunner env) => RunMessage env IcyGhoul where
  runMessage msg e@(IcyGhoul attrs@Attrs {..}) = case msg of
    InvestigatorDrawEnemy _ _ eid | eid == enemyId ->
      e <$ spawnAt enemyId "01114"
    _ -> IcyGhoul <$> runMessage msg attrs
