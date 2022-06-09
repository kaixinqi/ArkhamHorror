module Arkham.Asset.Cards.Burglary
  ( Burglary(..)
  , burglary
  ) where

import Arkham.Prelude

import Arkham.Ability
import Arkham.Action qualified as Action
import Arkham.Asset.Cards qualified as Cards
import Arkham.Asset.Runner
import Arkham.Cost
import Arkham.Criteria
import Arkham.Investigator.Attrs ( Field (..) )
import Arkham.Projection
import Arkham.SkillType

newtype Burglary = Burglary AssetAttrs
  deriving anyclass (IsAsset, HasModifiersFor)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

burglary :: AssetCard Burglary
burglary = asset Burglary Cards.burglary

instance HasAbilities Burglary where
  getAbilities (Burglary a) =
    [ restrictedAbility a 1 OwnsThis
        $ ActionAbility (Just Action.Investigate)
        $ Costs [ActionCost 1, ExhaustCost (toTarget a)]
    ]

instance RunMessage Burglary where
  runMessage msg a@(Burglary attrs) = case msg of
    UseCardAbility iid source _ 1 _ | isSource attrs source -> do
      lid <- fieldF
        InvestigatorLocation
        (fromJustNote "must be at a location")
        iid
      push $ Investigate
        iid
        lid
        source
        (Just $ toTarget attrs)
        SkillIntellect
        False
      pure a
    Successful (Action.Investigate, _) iid _ target _ | isTarget attrs target ->
      a <$ pushAll [TakeResources iid 3 False]
    _ -> Burglary <$> runMessage msg attrs
