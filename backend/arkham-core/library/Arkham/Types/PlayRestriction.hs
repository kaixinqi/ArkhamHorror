module Arkham.Types.PlayRestriction where

import Arkham.Prelude

import Arkham.Types.Trait

data DiscardSignifier = AnyPlayerDiscard
  deriving stock (Show, Eq, Generic)
  deriving anyclass (ToJSON, FromJSON, Hashable)

data PlayRestriction
  = AnotherInvestigatorInSameLocation
  | ScenarioCardHasResignAbility
  | ClueOnLocation
  | FirstAction
  | EnemyAtYourLocation
  | NoEnemiesAtYourLocation
  | OwnCardWithDoom
  | CardInDiscard DiscardSignifier [Trait]
  | ReturnableCardInDiscard DiscardSignifier [Trait]
  deriving stock (Show, Eq, Generic)
  deriving anyclass (ToJSON, FromJSON, Hashable)
