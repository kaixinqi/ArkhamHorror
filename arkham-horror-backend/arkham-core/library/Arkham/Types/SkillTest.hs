module Arkham.Types.SkillTest
  ( SkillTest(..)
  , DrawStrategy(..)
  , ResolveStrategy(..)
  , SkillTestResult(..)
  , initSkillTest
  )
where

import Arkham.Types.Card
import Arkham.Types.Classes
import Arkham.Types.InvestigatorId
import Arkham.Types.Message
import Arkham.Types.Modifier
import Arkham.Types.SkillTestResult
import Arkham.Types.SkillType
import Arkham.Types.Source
import Arkham.Types.Target
import Arkham.Types.Token
import ClassyPrelude
import Data.Aeson
import Lens.Micro

data DrawStrategy
  = DrawOne
  | DrawX Int
  deriving stock (Show, Generic)
  deriving anyclass (ToJSON, FromJSON)

data ResolveStrategy
  = ResolveAll
  | ResolveOne
  deriving stock (Show, Generic)
  deriving anyclass (ToJSON, FromJSON)

data SkillTest = SkillTest
  { skillTestInvestigator    :: InvestigatorId
  , skillTestSkillType :: SkillType
  , skillTestDifficulty      :: Int
  , skillTestOnSuccess       :: [Message]
  , skillTestOnFailure       :: [Message]
  , skillTestDrawStrategy    :: DrawStrategy
  , skillTestResolveStrategy :: ResolveStrategy
  , skillTestSetAsideTokens  :: [Token]
  , skillTestResult :: SkillTestResult
  , skillTestModifiers :: [Modifier]
  , skillTestCommittedCards :: [(InvestigatorId, Card)]
  }
  deriving stock (Show, Generic)
  deriving anyclass (ToJSON, FromJSON)

initSkillTest
  :: InvestigatorId -> SkillType -> Int -> [Message] -> [Message] -> SkillTest
initSkillTest iid skillType' difficulty' onSuccess' onFailure' = SkillTest
  { skillTestInvestigator = iid
  , skillTestSkillType = skillType'
  , skillTestDifficulty = difficulty'
  , skillTestOnSuccess = onSuccess'
  , skillTestOnFailure = onFailure'
  , skillTestDrawStrategy = DrawOne
  , skillTestResolveStrategy = ResolveAll
  , skillTestSetAsideTokens = mempty
  , skillTestResult = Unrun
  , skillTestModifiers = mempty
  , skillTestCommittedCards = mempty
  }

modifiers :: Lens' SkillTest [Modifier]
modifiers = lens skillTestModifiers $ \m x -> m { skillTestModifiers = x }

setAsideTokens :: Lens' SkillTest [Token]
setAsideTokens =
  lens skillTestSetAsideTokens $ \m x -> m { skillTestSetAsideTokens = x }

committedCards :: Lens' SkillTest [(InvestigatorId, Card)]
committedCards =
  lens skillTestCommittedCards $ \m x -> m { skillTestCommittedCards = x }

result :: Lens' SkillTest SkillTestResult
result = lens skillTestResult $ \m x -> m { skillTestResult = x }

onFailure :: Lens' SkillTest [Message]
onFailure = lens skillTestOnFailure $ \m x -> m { skillTestOnFailure = x }

onSuccess :: Lens' SkillTest [Message]
onSuccess = lens skillTestOnSuccess $ \m x -> m { skillTestOnSuccess = x }

skillIconCount :: SkillTest -> Int
skillIconCount SkillTest {..} = length . filter matches $ concatMap
  (iconsForCard . snd)
  skillTestCommittedCards
 where
  iconsForCard (PlayerCard MkPlayerCard {..}) = pcSkills
  iconsForCard _ = []
  matches SkillWild = True
  matches s = s == skillTestSkillType


instance (HasQueue env) => RunMessage env SkillTest where
  runMessage msg s@SkillTest {..} = case msg of
    AddOnFailure m -> pure $ s & onFailure %~ (m :)
    AddOnSuccess m -> pure $ s & onSuccess %~ (m :)
    HorrorPerPointOfFailure iid -> case skillTestResult of
      FailedBy n ->
        s <$ unshiftMessage (InvestigatorDamage iid SkillTestSource 0 n)
      _ -> error "Should not be called when not failed"
    DamagePerPointOfFailure iid -> case skillTestResult of
      FailedBy n ->
        s <$ unshiftMessage (InvestigatorDamage iid SkillTestSource n 0)
      _ -> error "Should not be called when not failed"
    DrawToken token -> pure $ s & setAsideTokens %~ (token :)
    FailSkillTest -> do
      unshiftMessage SkillTestEnds
      unshiftMessages skillTestOnFailure
      pure $ s & result .~ FailedBy skillTestDifficulty
    StartSkillTest -> s <$ unshiftMessage
      (InvestigatorStartSkillTest
        skillTestInvestigator
        skillTestSkillType
        skillTestModifiers
      )
    SkillTestCommitCard iid (_, card) ->
      pure $ s & committedCards %~ ((iid, card) :)
    AddModifier SkillTestTarget modifier ->
      pure $ s & modifiers %~ (modifier :)
    SkillTestEnds -> s <$ unshiftMessages
      [ InvestigatorRemoveAllModifiersFromSource
        skillTestInvestigator
        SkillTestSource
      , ReturnTokens skillTestSetAsideTokens
      ]
    SkillTestResults -> do
      unshiftMessage SkillTestApplyResults
      for_ skillTestCommittedCards $ \(iid, card) -> case card of
        PlayerCard MkPlayerCard {..} -> when
          (pcCardType == SkillType)
          (unshiftMessage (RunSkill iid pcCardCode skillTestResult))
        _ -> pure ()
      pure s
    SkillTestApplyResults -> do
      unshiftMessage SkillTestEnds

      case skillTestResult of
        SucceededBy _ -> unshiftMessages skillTestOnSuccess
        FailedBy _ -> unshiftMessages skillTestOnFailure
        Unrun -> pure ()

      unshiftMessages $ map
        (AddModifier (InvestigatorTarget skillTestInvestigator)
        . replaceModifierSource SkillTestSource
        )
        skillTestModifiers

      pure s
    RunSkillTest modifiedSkillValue -> do
      let modifiedSkillValue' = modifiedSkillValue + skillIconCount s
      unshiftMessage SkillTestResults
      putStrLn
        . pack
        $ "Modified skill value: "
        <> show modifiedSkillValue'
        <> "\nDifficulty: "
        <> show skillTestDifficulty
      if modifiedSkillValue' >= skillTestDifficulty
        then pure $ s & result .~ SucceededBy
          (modifiedSkillValue' - skillTestDifficulty)
        else pure $ s & result .~ FailedBy
          (skillTestDifficulty - modifiedSkillValue')
    _ -> pure s
