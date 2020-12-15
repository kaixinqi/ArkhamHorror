{-# LANGUAGE UndecidableInstances #-}
module Arkham.Types.Asset.Cards.FishingNet
  ( FishingNet(..)
  , fishingNet
  )
where

import Arkham.Import

import Arkham.Types.Asset.Attrs
import Arkham.Types.Asset.Runner
import Arkham.Types.Game.Helpers
import Arkham.Types.Keyword

newtype FishingNet = FishingNet Attrs
  deriving stock (Show, Generic)
  deriving anyclass (ToJSON, FromJSON)

fishingNet :: AssetId -> FishingNet
fishingNet uuid = FishingNet $ (baseAttrs uuid "81021") { assetIsStory = True }

instance HasModifiersFor env FishingNet where
  getModifiersFor _ (EnemyTarget eid) (FishingNet attrs) = pure $ toModifiers
    attrs
    [ RemoveKeyword Retaliate | assetEnemy attrs == Just eid ]
  getModifiersFor _ _ _ = pure []

ability :: Attrs -> Ability
ability attrs = mkAbility (toSource attrs) 1 (FastAbility FastPlayerWindow)

instance ActionRunner env => HasActions env FishingNet where
  getActions iid FastPlayerWindow (FishingNet attrs) | ownedBy attrs iid = do
    mrougarou <- fmap unStoryEnemyId <$> getId (CardCode "81028")
    case mrougarou of
      Nothing -> pure []
      Just eid -> do
        investigatorLocation <- getId @LocationId iid
        exhaustedEnemies <- map unExhaustedEnemyId
          <$> getSetList investigatorLocation
        pure
          [ ActivateCardAbilityAction iid (ability attrs)
          | eid `elem` exhaustedEnemies
          ]
  getActions iid window (FishingNet x) = getActions iid window x

instance AssetRunner env => RunMessage env FishingNet where
  runMessage msg a@(FishingNet attrs@Attrs {..}) = case msg of
    UseCardAbility _ source _ 1 | isSource attrs source -> do
      mrougarou <- fmap unStoryEnemyId <$> getId (CardCode "81028")
      case mrougarou of
        Nothing -> error "can not use this ability"
        Just eid -> a <$ unshiftMessage (AttachAsset assetId (EnemyTarget eid))
    _ -> FishingNet <$> runMessage msg attrs
