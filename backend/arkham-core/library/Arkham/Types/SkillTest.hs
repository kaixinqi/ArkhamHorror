{-# LANGUAGE UndecidableInstances #-}
module Arkham.Types.SkillTest
  ( SkillTest(..)
  , SkillTestResult(..)
  , TokenResponse(..)
  , initSkillTest
  , skillTestToSource
  )
where

import Arkham.Import

import Arkham.Types.Action (Action)
import Arkham.Types.RequestedTokenStrategy
import Arkham.Types.SkillTestResult
import Arkham.Types.Stats
import Arkham.Types.Token
import Arkham.Types.TokenResponse
import qualified Data.HashMap.Strict as HashMap
import qualified Data.HashSet as HashSet
import qualified Data.List as L
import System.Environment

data SkillTest a = SkillTest
  { skillTestInvestigator    :: InvestigatorId
  , skillTestSkillType :: SkillType
  , skillTestDifficulty      :: Int
  , skillTestOnSuccess       :: [a]
  , skillTestOnFailure       :: [a]
  , skillTestOnTokenResponses :: [TokenResponse a]
  , skillTestSetAsideTokens  :: [Token]
  , skillTestRevealedTokens  :: [Token] -- tokens may change from physical representation
  , skillTestValueModifier :: Int
  , skillTestResult :: SkillTestResult
  , skillTestModifiers :: HashMap Source [Modifier]
  , skillTestCommittedCards :: HashMap CardId (InvestigatorId, Card)
  , skillTestSource :: Source
  , skillTestTarget :: Target
  , skillTestAction :: Maybe Action
  , skillTestSubscribers :: [Target]
  }
  deriving stock (Show, Generic)

skillTestToSource :: SkillTest a -> Source
skillTestToSource = toSource

toSource :: SkillTest a -> Source
toSource SkillTest {..} =
  SkillTestSource skillTestInvestigator skillTestSource skillTestAction

instance ToJSON a => ToJSON (SkillTest a) where
  toJSON = genericToJSON $ aesonOptions $ Just "skillTest"
  toEncoding = genericToEncoding $ aesonOptions $ Just "skillTest"

instance FromJSON a => FromJSON (SkillTest a) where
  parseJSON = genericParseJSON $ aesonOptions $ Just "skillTest"

-- TODO: Cursed Swamp would apply to anyone trying to commit skill cards
instance HasModifiersFor env (SkillTest a) where
  getModifiersFor _ (InvestigatorTarget iid) SkillTest {..}
    | iid == skillTestInvestigator = do
      pure $ concat (toList skillTestModifiers)
  getModifiersFor _ _ SkillTest{} = pure []

instance HasSet CommittedCardId InvestigatorId (SkillTest a) where
  getSet iid =
    HashSet.map CommittedCardId
      . keysSet
      . filterMap ((== iid) . fst)
      . skillTestCommittedCards

instance HasSet CommittedCardCode () (SkillTest a) where
  getSet _ =
    setFromList
      . map (CommittedCardCode . getCardCode . snd)
      . toList
      . skillTestCommittedCards

initSkillTest
  :: InvestigatorId
  -> Source
  -> Target
  -> Maybe Action
  -> SkillType
  -> Int
  -> Int
  -> [Message]
  -> [Message]
  -> [Modifier]
  -> [TokenResponse Message]
  -> SkillTest Message
initSkillTest iid source target maction skillType' _skillValue' difficulty' onSuccess' onFailure' modifiers' tokenResponses'
  = SkillTest
    { skillTestInvestigator = iid
    , skillTestSkillType = skillType'
    , skillTestDifficulty = difficulty'
    , skillTestOnSuccess = onSuccess'
    , skillTestOnFailure = onFailure'
    , skillTestOnTokenResponses = tokenResponses'
    , skillTestSetAsideTokens = mempty
    , skillTestRevealedTokens = mempty
    , skillTestValueModifier = 0
    , skillTestResult = Unrun
    , skillTestModifiers = mapFromList
      [(SkillTestSource iid source maction, modifiers')]
    , skillTestCommittedCards = mempty
    , skillTestSource = source
    , skillTestTarget = target
    , skillTestAction = maction
    , skillTestSubscribers = [SkillTestInitiatorTarget, InvestigatorTarget iid]
    }

modifiers :: Lens' (SkillTest a) (HashMap Source [Modifier])
modifiers = lens skillTestModifiers $ \m x -> m { skillTestModifiers = x }

subscribers :: Lens' (SkillTest a) [Target]
subscribers =
  lens skillTestSubscribers $ \m x -> m { skillTestSubscribers = x }

valueModifier :: Lens' (SkillTest a) Int
valueModifier =
  lens skillTestValueModifier $ \m x -> m { skillTestValueModifier = x }

setAsideTokens :: Lens' (SkillTest a) [Token]
setAsideTokens =
  lens skillTestSetAsideTokens $ \m x -> m { skillTestSetAsideTokens = x }

revealedTokens :: Lens' (SkillTest a) [Token]
revealedTokens =
  lens skillTestRevealedTokens $ \m x -> m { skillTestRevealedTokens = x }

committedCards :: Lens' (SkillTest a) (HashMap CardId (InvestigatorId, Card))
committedCards =
  lens skillTestCommittedCards $ \m x -> m { skillTestCommittedCards = x }

result :: Lens' (SkillTest a) SkillTestResult
result = lens skillTestResult $ \m x -> m { skillTestResult = x }

onTokenResponses :: Lens' (SkillTest a) [TokenResponse a]
onTokenResponses =
  lens skillTestOnTokenResponses $ \m x -> m { skillTestOnTokenResponses = x }

skillIconCount :: SkillTest a -> Int
skillIconCount SkillTest {..} = length . filter matches $ concatMap
  (iconsForCard . snd)
  (toList skillTestCommittedCards)
 where
  iconsForCard (PlayerCard MkPlayerCard {..}) = pcSkills
  iconsForCard _ = []
  matches SkillWild = True
  matches s = s == skillTestSkillType

getModifiedSkillTestDifficulty
  :: (MonadReader env m, MonadIO m, HasModifiersFor env env)
  => SkillTest a
  -> m Int
getModifiedSkillTestDifficulty s = do
  modifiers' <- getModifiersFor (toSource s) SkillTestTarget =<< ask
  pure $ foldr
    applyModifier
    (skillTestDifficulty s)
    (modifiers' <> concat (toList $ skillTestModifiers s))
 where
  applyModifier (Difficulty m) n = max 0 (n + m)
  applyModifier _ n = n

modifiedTokenValue :: Int -> SkillTest a -> Int
modifiedTokenValue baseValue SkillTest {..} = foldr
  applyModifier
  baseValue
  (concat . toList $ skillTestModifiers)
 where
  applyModifier DoubleNegativeModifiersOnTokens n =
    if baseValue < 0 then n + baseValue else n
  applyModifier _ n = n

type SkillTestRunner env
  = ( HasQueue env
    , HasCard InvestigatorId env
    , HasModifiers env InvestigatorId
    , HasStats (InvestigatorId, Maybe Action) env
    , HasSource ForSkillTest env
    , HasModifiersFor env env
    )

instance (SkillTestRunner env) => RunMessage env (SkillTest Message) where
  runMessage msg s@SkillTest {..} = case msg of
    TriggerSkillTest iid -> do
      modifiers' <- getModifiers (toSource s) iid
      if DoNotDrawChaosTokensForSkillChecks `elem` modifiers'
        then s <$ unshiftMessages
          [ RunSkillTestSourceNotification iid skillTestSource
          , RunSkillTest iid []
          ]
        else s <$ unshiftMessage (RequestTokens (toSource s) iid 1 SetAside)
    DrawAnotherToken iid valueModifier' -> do
      unshiftMessage (RequestTokens (toSource s) iid 1 SetAside)
      pure $ s & valueModifier +~ valueModifier'
    RequestedTokens (SkillTestSource siid source maction) iid tokens -> do
      unshiftMessage (RevealSkillTestTokens iid)
      for_ tokens $ \token -> unshiftMessages
        [ CheckWindow iid [WhenRevealToken You token]
        , When (RevealToken (SkillTestSource siid source maction) iid token)
        , RevealToken (SkillTestSource siid source maction) iid token
        ]
      pure $ s & (setAsideTokens %~ (tokens <>))
    RevealToken SkillTestSource{} _iid token -> do
      pure $ s & revealedTokens %~ (token :)
    RevealSkillTestTokens iid -> do
      onTokenResponses' <-
        (catMaybes <$>) . for skillTestOnTokenResponses $ \case
          OnAnyToken tokens' messages
            | not (null $ skillTestRevealedTokens `L.intersect` tokens')
            -> Nothing <$ unshiftMessages messages
          response -> pure (Just response)
      unshiftMessages
        [ ResolveToken token iid | token <- skillTestRevealedTokens ]
      pure
        $ s
        & (onTokenResponses .~ onTokenResponses')
        & (subscribers
          %~ (<> [ TokenTarget token' | token' <- skillTestRevealedTokens ])
          )
    AddSkillTestSubscriber target -> pure $ s & subscribers %~ (target :)
    SetAsideToken token -> pure $ s & (setAsideTokens %~ (token :))
    PassSkillTest -> do
      stats <-
        getStats (skillTestInvestigator, skillTestAction) (toSource s) =<< ask
      let
        currentSkillValue = statsSkillValue stats skillTestSkillType
        modifiedSkillValue' =
          max 0 (currentSkillValue + skillTestValueModifier + skillIconCount s)
      unshiftMessages
        [ Ask skillTestInvestigator $ ChooseOne [SkillTestApplyResults]
        , SkillTestEnds
        ]
      pure $ s & result .~ SucceededBy True modifiedSkillValue'
    FailSkillTest -> do
      unshiftMessages
        $ [ Will
              (FailedSkillTest
                skillTestInvestigator
                skillTestAction
                skillTestSource
                target
                skillTestDifficulty
              )
          | target <- skillTestSubscribers
          ]
        <> [ Ask skillTestInvestigator $ ChooseOne [SkillTestApplyResults]
           , SkillTestEnds
           ]
      pure $ s & result .~ FailedBy True skillTestDifficulty
    StartSkillTest _ -> s <$ unshiftMessages
      (HashMap.foldMapWithKey
          (\k (i, _) -> [CommitCard i k])
          skillTestCommittedCards
      <> [TriggerSkillTest skillTestInvestigator]
      )
    InvestigatorCommittedSkill _ skillId -> do
      pure $ s & subscribers %~ (SkillTarget skillId :)
    SkillTestCommitCard iid cardId -> do
      card <- asks (getCard iid cardId)
      pure $ s & committedCards %~ insertMap cardId (iid, card)
    SkillTestUncommitCard _ cardId ->
      pure $ s & committedCards %~ deleteMap cardId
    AddModifiers SkillTestTarget source modifiers' ->
      pure $ s & modifiers %~ insertWith (<>) source modifiers'
    ReturnSkillTestRevealedTokens -> do
      -- Rex's Curse timing keeps effects on stack so we do
      -- not want to remove them as subscribers from the stack
      unshiftMessage $ ResetTokens (toSource s)
      pure $ s & setAsideTokens .~ mempty & revealedTokens .~ mempty
    SkillTestEnds -> s <$ unshiftMessages
      [ RemoveAllModifiersOnTargetFrom
        (InvestigatorTarget skillTestInvestigator)
        (toSource s)
      , ResetTokens (toSource s)
      ]
    SkillTestResults -> do
      unshiftMessage
        (Ask skillTestInvestigator $ ChooseOne [SkillTestApplyResults])
      case skillTestResult of
        SucceededBy _ n -> unshiftMessages
          [ Will
              (PassedSkillTest
                skillTestInvestigator
                skillTestAction
                skillTestSource
                target
                n
              )
          | target <- skillTestSubscribers
          ]
        FailedBy _ n -> unshiftMessages
          [ Will
              (FailedSkillTest
                skillTestInvestigator
                skillTestAction
                skillTestSource
                target
                n
              )
          | target <- skillTestSubscribers
          ]
        Unrun -> pure ()
      pure s
    AddModifiers AfterSkillTestTarget source modifiers' -> do
      case skillTestResult of
        FailedBy True _ -> pure s
        _ -> do
          withQueue $ \queue ->
            let
              queue' = flip filter queue $ \case
                Will FailedSkillTest{} -> False
                Will PassedSkillTest{} -> False
                CheckWindow _ [WhenWouldFailSkillTest _] -> False
                Ask skillTestInvestigator' (ChooseOne [SkillTestApplyResults])
                  | skillTestInvestigator == skillTestInvestigator' -> False
                _ -> True
            in (queue', ())
          unshiftMessage (RunSkillTest skillTestInvestigator [])
          pure $ s & modifiers %~ insertWith (<>) source modifiers'
    SkillTestApplyResultsAfter -> do -- ST.7 -- apply results
      unshiftMessage SkillTestEnds -- -> ST.8 -- Skill test ends

      case skillTestResult of
        SucceededBy _ n ->
          unshiftMessages
            $ skillTestOnSuccess
            <> [ After
                   (PassedSkillTest
                     skillTestInvestigator
                     skillTestAction
                     skillTestSource
                     target
                     n
                   )
               | target <- skillTestSubscribers
               ]
        FailedBy _ n ->
          unshiftMessages
            $ skillTestOnFailure
            <> [ After
                   (FailedSkillTest
                     skillTestInvestigator
                     skillTestAction
                     skillTestSource
                     target
                     n
                   )
               | target <- skillTestSubscribers
               ]
        Unrun -> pure ()
      pure s
    SkillTestApplyResults -> do -- ST.7 Apply Results
      unshiftMessage SkillTestApplyResultsAfter
      s <$ case skillTestResult of
        SucceededBy _ n -> unshiftMessages
          [ PassedSkillTest
              skillTestInvestigator
              skillTestAction
              skillTestSource
              target
              n
          | target <- skillTestSubscribers
          ]
        FailedBy _ n -> unshiftMessages
          [ FailedSkillTest
              skillTestInvestigator
              skillTestAction
              skillTestSource
              target
              n
          | target <- skillTestSubscribers
          ]
        Unrun -> pure ()
    RunSkillTest _ tokenValues -> do
      stats <-
        getStats (skillTestInvestigator, skillTestAction) (toSource s) =<< ask
      modifiedSkillTestDifficulty <- getModifiedSkillTestDifficulty s
      let
        currentSkillValue = statsSkillValue stats skillTestSkillType
        incomingTokenValues = sum $ map tokenValue tokenValues
        totaledTokenValues =
          modifiedTokenValue incomingTokenValues s + skillTestValueModifier
        modifiedSkillValue' =
          max 0 (currentSkillValue + totaledTokenValues + skillIconCount s)
      unshiftMessage SkillTestResults
      liftIO $ whenM
        (isJust <$> lookupEnv "DEBUG")
        (putStrLn
        . pack
        $ "skill value: "
        <> show currentSkillValue
        <> "\n+ totaled token values: "
        <> show totaledTokenValues
        <> "\n+ skill icon count: "
        <> show (skillIconCount s)
        <> "\n-------------------------"
        <> "\n= Modified skill value: "
        <> show modifiedSkillValue'
        <> "\nDifficulty: "
        <> show skillTestDifficulty
        <> "\nModified Skill Difficulty: "
        <> show modifiedSkillTestDifficulty
        )
      if modifiedSkillValue' >= modifiedSkillTestDifficulty
        then
          pure
          $ s
          & (result .~ SucceededBy
              False
              (modifiedSkillValue' - modifiedSkillTestDifficulty)
            )
          & (valueModifier .~ totaledTokenValues)
        else
          pure
          $ s
          & (result .~ FailedBy
              False
              (modifiedSkillTestDifficulty - modifiedSkillValue')
            )
          & (valueModifier .~ totaledTokenValues)
    _ -> pure s
