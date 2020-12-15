{-# LANGUAGE UndecidableInstances #-}
module Arkham.Types.Act.Cards.AllIn
  ( AllIn(..)
  , allIn
  )
where

import Arkham.Import

import Arkham.Types.Act.Attrs
import Arkham.Types.Act.Helpers
import Arkham.Types.Act.Runner
import Arkham.Types.Action
import Arkham.Types.Trait

newtype AllIn = AllIn Attrs
  deriving newtype (Show, ToJSON, FromJSON)

allIn :: AllIn
allIn = AllIn $ baseAttrs "02068" "All In" "Act 3a"

instance
  ( HasCount SpendableClueCount env InvestigatorId
  , HasCount ActionRemainingCount env (Maybe Action, [Trait], InvestigatorId)
  , HasModifiersFor env ()
  , HasId (Maybe LocationId) env AssetId
  , HasId (Maybe OwnerId) env AssetId
  , HasId (Maybe StoryAssetId) env CardCode
  , HasId LocationId env InvestigatorId
  )
  => HasActions env AllIn where
  getActions iid NonFast (AllIn attrs) = do
    baseActions <- getActions iid NonFast attrs
    investigatorLocationId <- getId @LocationId iid
    maid <- fmap unStoryAssetId <$> getId (CardCode "02080")
    case maid of
      Nothing -> pure baseActions
      Just aid -> do
        miid <- fmap unOwnerId <$> getId aid
        assetLocationId <- getId aid
        hasParleyActionsRemaining <- getCanAffordCost
          iid
          (toSource attrs)
          (ActionCost 1 (Just Parley) mempty)
        pure
          $ baseActions
          <> [ ActivateCardAbilityAction
                 iid
                 (mkAbility
                   (ProxySource (AssetSource aid) (toSource attrs))
                   1
                   (ActionAbility 1 (Just Parley))
                 )
             | isNothing miid
               && Just investigatorLocationId
               == assetLocationId
               && hasParleyActionsRemaining
             ]
  getActions i window (AllIn x) = getActions i window x

instance ActRunner env => RunMessage env AllIn where
  runMessage msg a@(AllIn attrs@Attrs {..}) = case msg of
    AdvanceAct aid | aid == actId && not actFlipped -> do
      investigatorIds <- getInvestigatorIds
      requiredClueCount <- getPlayerCountValue (PerPlayer 2)
      unshiftMessages
        (SpendClues requiredClueCount investigatorIds
        : [ Ask iid $ ChooseOne [AdvanceAct aid] | iid <- investigatorIds ]
        )
      pure $ AllIn $ attrs & sequenceL .~ "Act 3b" & flippedL .~ True
    AdvanceAct aid | aid == actId && actFlipped -> do
      maid <- fmap unStoryAssetId <$> getId (CardCode "02080")
      a <$ case maid of
        Nothing -> unshiftMessage (Resolution 1)
        Just assetId -> do
          miid <- fmap unOwnerId <$> getId assetId
          unshiftMessage (maybe (Resolution 1) (const (Resolution 2)) miid)
    UseCardAbility iid (ProxySource _ source) _ 1
      | isSource attrs source && actSequence == "Act 3a" -> do
        maid <- fmap unStoryAssetId <$> getId (CardCode "02080")
        case maid of
          Nothing -> error "this ability should not be able to be used"
          Just aid -> a <$ unshiftMessage
            (BeginSkillTest
              iid
              source
              (AssetTarget aid)
              (Just Parley)
              SkillWillpower
              3
            )
    PassedSkillTest iid _ source _ _
      | isSource attrs source && actSequence == "Act 3a" -> do
        maid <- fmap unStoryAssetId <$> getId (CardCode "02080")
        case maid of
          Nothing -> error "this ability should not be able to be used"
          Just aid -> do
            currentClueCount <- unClueCount <$> getCount aid
            requiredClueCount <- getPlayerCountValue (PerPlayer 1)
            unshiftMessage (PlaceClues (AssetTarget aid) 1)
            a <$ when
              (currentClueCount + 1 >= requiredClueCount)
              (unshiftMessage $ TakeControlOfAsset iid aid)
    _ -> AllIn <$> runMessage msg attrs
