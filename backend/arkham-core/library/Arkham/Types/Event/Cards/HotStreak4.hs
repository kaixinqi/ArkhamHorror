{-# LANGUAGE UndecidableInstances #-}
module Arkham.Types.Event.Cards.HotStreak4 where

import Arkham.Json
import Arkham.Types.Classes
import Arkham.Types.Event.Attrs
import Arkham.Types.Event.Runner
import Arkham.Types.EventId
import Arkham.Types.InvestigatorId
import Arkham.Types.Message
import Arkham.Types.Target
import Lens.Micro

import ClassyPrelude

newtype HotStreak4 = HotStreak4 Attrs
  deriving newtype (Show, ToJSON, FromJSON)

hotStreak4 :: InvestigatorId -> EventId -> HotStreak4
hotStreak4 iid uuid = HotStreak4 $ baseAttrs iid uuid "01057"

instance HasActions env investigator HotStreak4 where
  getActions i window (HotStreak4 attrs) = getActions i window attrs

instance (EventRunner env) => RunMessage env HotStreak4 where
  runMessage msg (HotStreak4 attrs@Attrs {..}) = case msg of
    InvestigatorPlayEvent iid eid | eid == eventId -> do
      unshiftMessages [TakeResources iid 10 False, Discard (EventTarget eid)]
      HotStreak4 <$> runMessage msg (attrs & resolved .~ True)
    _ -> HotStreak4 <$> runMessage msg attrs
