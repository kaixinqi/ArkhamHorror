module Arkham.Event.Cards.AChanceEncounter
  ( aChanceEncounter
  , AChanceEncounter(..)
  ) where

import Arkham.Prelude

import Arkham.Card
import Arkham.Classes
import Arkham.Event.Cards qualified as Cards
import Arkham.Event.Helpers
import Arkham.Event.Runner
import Arkham.Investigator.Attrs ( Field (..) )
import Arkham.Message
import Arkham.Modifier
import Arkham.Projection
import Arkham.Source
import Arkham.Target
import Arkham.Trait

newtype AChanceEncounter = AChanceEncounter EventAttrs
  deriving anyclass (IsEvent, HasModifiersFor, HasAbilities)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

aChanceEncounter :: EventCard AChanceEncounter
aChanceEncounter = event AChanceEncounter Cards.aChanceEncounter

instance RunMessage AChanceEncounter where
  runMessage msg e@(AChanceEncounter attrs) = case msg of
    InvestigatorPlayEvent iid eid _ _ _ | eid == toId attrs -> do
      investigatorIds <-
        filterM
            (fmap (notElem CardsCannotLeaveYourDiscardPile)
            . getModifiers GameSource
            . InvestigatorTarget
            )
          =<< getInvestigatorIds
      discards <-
        concat
          <$> traverse (fieldF InvestigatorDiscard (map PlayerCard)) investigatorIds
      let filteredDiscards = filter (elem Ally . toTraits) discards
      e <$ pushAll
        [ FocusCards filteredDiscards
        , chooseOne
          iid
          [ TargetLabel
              (CardIdTarget $ toCardId card)
              [ PutCardIntoPlay iid card Nothing
              , RemoveFromDiscard iid (toCardId card)
              , CreateEffect
                "02270"
                Nothing
                (toSource attrs)
                (CardIdTarget $ toCardId card)
              ]
          | card <- filteredDiscards
          ]
        , UnfocusCards
        , Discard (toTarget attrs)
        ]
    _ -> AChanceEncounter <$> runMessage msg attrs
