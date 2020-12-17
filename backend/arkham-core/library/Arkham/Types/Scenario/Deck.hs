module Arkham.Types.Scenario.Deck where

import Arkham.Import

data ScenarioDeck = CultistDeck [EncounterCard] | ExhibitDeck [EncounterCard]
  deriving stock (Show, Generic)
  deriving anyclass (ToJSON, FromJSON)
