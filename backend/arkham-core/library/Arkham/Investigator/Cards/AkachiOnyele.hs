module Arkham.Investigator.Cards.AkachiOnyele where

import Arkham.Prelude

import Arkham.Asset.Attrs ( Field (..) )
import Arkham.Asset.Uses
import Arkham.Game.Helpers
import Arkham.Investigator.Cards qualified as Cards
import Arkham.Investigator.Runner
import Arkham.Message
import Arkham.Modifier
import Arkham.Projection
import Arkham.Source
import Arkham.Target

newtype AkachiOnyele = AkachiOnyele InvestigatorAttrs
  deriving anyclass (IsInvestigator, HasAbilities)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

instance HasModifiersFor AkachiOnyele where
  getModifiersFor (InvestigatorSource iid) (AssetTarget aid) (AkachiOnyele attrs)
    | toId attrs == iid
    = do
      startingChargesCount <- fieldF
        AssetStartingUses
        (\u -> if useType u == Just Charge then useCount u else 0)
        aid
      pure $ toModifiers
        attrs
        [ AdditionalStartingUses 1 | startingChargesCount > 0 ]
  getModifiersFor _ _ _ = pure []

akachiOnyele :: InvestigatorCard AkachiOnyele
akachiOnyele = investigator
  AkachiOnyele
  Cards.akachiOnyele
  Stats
    { health = 6
    , sanity = 8
    , willpower = 5
    , intellect = 2
    , combat = 3
    , agility = 3
    }

instance HasTokenValue AkachiOnyele where
  getTokenValue iid ElderSign (AkachiOnyele attrs)
    | iid == investigatorId attrs = pure
    $ TokenValue ElderSign (PositiveModifier 1)
  getTokenValue _ token _ = pure $ TokenValue token mempty

instance RunMessage AkachiOnyele where
  runMessage msg i@(AkachiOnyele attrs) = case msg of
    ResolveToken _ ElderSign iid | iid == toId attrs -> do
      targets <- map AssetTarget <$> filterM
        (fieldF
          AssetUses
          (\u -> useType u == Just Charge && useCount u > 0)
        )
        (setToList $ investigatorAssets attrs)
      i <$ when
        (notNull targets)
        (push $ chooseOne
          iid
          (Done "Do not use Elder Sign ability"
          : [ TargetLabel target [AddUses target Charge 1]
            | target <- targets
            ]
          )
        )
    _ -> AkachiOnyele <$> runMessage msg attrs
