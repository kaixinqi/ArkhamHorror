{-# LANGUAGE DefaultSignatures #-}
{-# LANGUAGE TemplateHaskell #-}
module Arkham.Types.Classes
  ( module Arkham.Types.Classes
  , module X
  ) where

import Arkham.Prelude hiding (to)

import Arkham.Types.Ability
import Arkham.Types.Action hiding (Ability)
import Arkham.Types.Card
import Arkham.Types.Card.Id
import Arkham.Types.Classes.Entity as X
import Arkham.Types.Classes.HasQueue as X
import Arkham.Types.Classes.HasRecord as X
import Arkham.Types.Classes.HasTokenValue as X
import Arkham.Types.Classes.RunMessage as X
import Arkham.Types.History
import Arkham.Types.Id
import Arkham.Types.Keyword
import Arkham.Types.Matcher
import Arkham.Types.Message
import Arkham.Types.Modifier
import Arkham.Types.Name
import Arkham.Types.Phase
import Arkham.Types.Query
import Arkham.Types.SkillType
import Arkham.Types.Source
import Arkham.Types.Stats
import Arkham.Types.Target
import Arkham.Types.Trait
import Arkham.Types.Window (Window)
import qualified Data.Char as C
import qualified Data.HashSet as HashSet
import GHC.Generics
import Language.Haskell.TH.Syntax hiding (Name)
import qualified Language.Haskell.TH.Syntax as TH

newtype Distance = Distance { unDistance :: Int }

class HasPhase env where
  getPhase :: MonadReader env m => m Phase

class HasStep step env a where
  getStep :: MonadReader env m => a -> m step

class HasHistory env where
  getHistory :: MonadReader env m => HistoryType -> InvestigatorId -> m History

class (Hashable set, Eq set) => HasSet set env a where
  getSet :: (HasCallStack, MonadReader env m) => a -> m (HashSet set)
  getSetList :: (HasCallStack, MonadReader env m) => a -> m [set]
  getSetList a = setToList <$> getSet a

getSetListMap
  :: (HasSet set env a, MonadReader env m) => (set -> set') -> a -> m [set']
getSetListMap f a = map f <$> getSetList a

type family QueryElement a where
  QueryElement AssetMatcher = AssetId
  QueryElement InvestigatorMatcher = InvestigatorId
  QueryElement LocationMatcher = LocationId
  QueryElement EnemyMatcher = EnemyId
  QueryElement TreacheryMatcher = TreacheryId
  QueryElement ExtendedCardMatcher = Card
  QueryElement ActionMatcher = Ability
  QueryElement SkillMatcher = SkillId

selectCount :: (HasCallStack, MonadReader env m, Query a env) => a -> m Int
selectCount = fmap HashSet.size . select

selectList
  :: (HasCallStack, MonadReader env m, Query a env) => a -> m [QueryElement a]
selectList = selectListMap id

selectListMap
  :: (HasCallStack, MonadReader env m, Query a env)
  => (QueryElement a -> b)
  -> a
  -> m [b]
selectListMap f = fmap (map f . setToList) . select

selectOne
  :: (HasCallStack, MonadReader env m, Query a env)
  => a
  -> m (Maybe (QueryElement a))
selectOne matcher = do
  result <- selectList matcher
  pure $ case result of
    [] -> Nothing
    x : _ -> Just x

class (Hashable (QueryElement a), Eq (QueryElement a)) => Query a env where
  select :: (HasCallStack, MonadReader env m) => a -> m (HashSet (QueryElement a))

class HasList list env a where
  getList :: MonadReader env m => a -> m [list]

class HasId id env a where
  getId :: MonadReader env m => a -> m id

class HasCount count env a where
  getCount :: MonadReader env m => a -> m count

class HasName env a where
  getName :: MonadReader env m => a -> m Name

class HasPlayerCard env a where
  getPlayerCard :: MonadReader env m => a -> m (Maybe PlayerCard)

type HasCostPayment env
  = ( HasCount ActionRemainingCount env (Maybe Action, [Trait], InvestigatorId)
    , HasCount PlayerCount env ()
    , HasCount ResourceCount env InvestigatorId
    , HasCount SpendableClueCount env ()
    , HasCount SpendableClueCount env InvestigatorId
    , HasCount UsesCount env AssetId
    , HasId (Maybe LocationId) env LocationMatcher
    , HasList HandCard env InvestigatorId
    , HasList TakenAction env InvestigatorId
    , Query AssetMatcher env
    , HasSet InvestigatorId env LocationId
    )

class HasStats env a where
  getStats :: MonadReader env m => a -> Source -> m Stats

class HasSkillValue env a where
  getSkillValue :: (HasModifiersFor env (), MonadReader env m) => SkillType -> a -> m Int

class HasVictoryPoints a where
  getVictoryPoints :: a -> Maybe Int

class HasDamage a where
  getDamage :: a -> (Int, Int)

class HasTrauma a where
  getTrauma :: a -> (Int, Int)

instance HasVictoryPoints Card where
  getVictoryPoints (PlayerCard card) = getVictoryPoints card
  getVictoryPoints (EncounterCard card) = getVictoryPoints card

instance HasVictoryPoints EncounterCard where
  getVictoryPoints = cdVictoryPoints . toCardDef

instance HasVictoryPoints PlayerCard where
  getVictoryPoints = cdVictoryPoints . toCardDef

type ActionRunner env
  = ( HasTokenValue env ()
    , HasSet LocationId env LocationMatcher
    , HasSet TreacheryId env LocationId
    , HasSet FarthestLocationId env (InvestigatorId, LocationMatcher)
    , HasList TakenAction env InvestigatorId
    , Query AssetMatcher env
    , Query LocationMatcher env
    , GetCardDef env EnemyId
    , HasAbilities env ActionType
    , HasCostPayment env
    , ( HasCount
          ActionRemainingCount
          env
          (Maybe Action, [Trait], InvestigatorId)
      , HasCount ActionRemainingCount env InvestigatorId
      , HasCount ActionTakenCount env InvestigatorId
      , HasCount AssetCount env (InvestigatorId, [Trait])
      , HasCount CardCount env InvestigatorId
      , HasCount ClueCount env InvestigatorId
      , HasCount ClueCount env LocationId
      , HasCount DamageCount env InvestigatorId
      , HasCount DoomCount env AssetId
      , HasCount DoomCount env InvestigatorId
      , HasCount HorrorCount env InvestigatorId
      , HasCount SetAsideCount env CardCode
      )
    , HasId (Maybe LocationId) env AssetId
    , HasId (Maybe OwnerId) env AssetId
    , HasId (Maybe StoryEnemyId) env CardCode
    , HasId CardCode env EnemyId
    , HasId LeadInvestigatorId env ()
    , HasId LocationId env EnemyId
    , HasId LocationId env InvestigatorId
    , HasList CommittedCard env InvestigatorId
    , HasList CommittedSkillIcon env InvestigatorId
    , HasList DiscardedPlayerCard env InvestigatorId
    , HasList InPlayCard env InvestigatorId
    , HasList UnderneathCard env InvestigatorId
    , HasList UsedAbility env ()
    , HasModifiersFor env ()
    , HasSet AccessibleLocationId env LocationId
    , HasSet CommittedCardId env InvestigatorId
    , HasSet ConnectedLocationId env LocationId
    , HasSet EnemyId env ([Trait], LocationId)
    , HasSet EnemyId env CardCode
    , HasSet EnemyId env EnemyMatcher
    , HasSet EnemyId env InvestigatorId
    , HasSet EnemyId env LocationId
    , HasSet ExhaustedEnemyId env LocationId
    , HasSet FightableEnemyId env (InvestigatorId, Source)
    , HasSet InvestigatorId env ()
    , HasSet InvestigatorId env (HashSet LocationId)
    , HasSet InvestigatorId env EnemyId
    , HasSet Keyword env EnemyId
    , HasSet LocationId env ()
    , HasSet LocationId env [Trait]
    , HasSet StoryEnemyId env CardCode
    , HasSet Trait env (InvestigatorId, CardId)
    , HasSet Trait env EnemyId
    , HasSet Trait env LocationId
    , HasSet Trait env Source
    , HasStep ActStep env ()
    )

class HasAbilities1 env f where
  getAbilities1 :: (HasCallStack, MonadReader env m) => InvestigatorId -> Window -> f p -> m [Ability]

instance HasAbilities1 env f => HasAbilities1 env (M1 i c f) where
  getAbilities1 iid window (M1 x) = getAbilities1 iid window x

instance (HasAbilities1 env l, HasAbilities1 env r) => HasAbilities1 env (l :+: r) where
  getAbilities1 iid window (L1 x) = getAbilities1 iid window x
  getAbilities1 iid window (R1 x) = getAbilities1 iid window x

instance (HasAbilities env p) => HasAbilities1 env (K1 R p) where
  getAbilities1 iid window (K1 x) = getAbilities iid window x

genericGetAbilities
  :: (HasCallStack, Generic a, HasAbilities1 env (Rep a), MonadReader env m)
  => InvestigatorId
  -> Window
  -> a
  -> m [Ability]
genericGetAbilities iid window = getAbilities1 iid window . from

class HasAbilities env a where
  getAbilities :: (HasCallStack, MonadReader env m) => InvestigatorId -> Window -> a -> m [Ability]
  getAbilities _ _ _ = pure []

class HasModifiersFor1 env f where
  getModifiersFor1 :: (HasCallStack, MonadReader env m) => Source -> Target -> f p -> m [Modifier]

instance HasModifiersFor1 env f => HasModifiersFor1 env (M1 i c f) where
  getModifiersFor1 source target (M1 x) = getModifiersFor1 source target x

instance (HasModifiersFor1 env l, HasModifiersFor1 env r) => HasModifiersFor1 env (l :+: r) where
  getModifiersFor1 source target (L1 x) = getModifiersFor1 source target x
  getModifiersFor1 source target (R1 x) = getModifiersFor1 source target x

instance (HasModifiersFor env p) => HasModifiersFor1 env (K1 R p) where
  getModifiersFor1 source target (K1 x) = getModifiersFor source target x

genericGetModifiersFor
  :: (HasCallStack, Generic a, HasModifiersFor1 env (Rep a), MonadReader env m)
  => Source
  -> Target
  -> a
  -> m [Modifier]
genericGetModifiersFor source target = getModifiersFor1 source target . from

getModifiers
  :: (HasModifiersFor env (), MonadReader env m)
  => Source
  -> Target
  -> m [ModifierType]
getModifiers source target =
  map modifierType <$> getModifiersFor source target ()

class HasModifiersFor env a where
  getModifiersFor :: (HasCallStack, MonadReader env m) => Source -> Target -> a -> m [Modifier]
  getModifiersFor _ _ _ = pure []

class Discardable a where
  canBeDiscarded :: a -> Bool

class CanBeWeakness env a where
  getIsWeakness :: MonadReader env m => a -> m Bool

class Exhaustable a where
  isExhausted :: a -> Bool
  isReady :: a -> Bool

  isExhausted = not . isReady
  isReady = not . isExhausted
  {-# MINIMAL isExhausted | isReady #-}

buildEntity :: String -> Q [Dec]
buildEntity nm = do
  ClassI _ instances <- reify (TH.mkName $ "Is" ++ nm)
  let conz = mapMaybe extractCon instances
  pure
    [ DataD
        []
        (TH.mkName nm)
        []
        Nothing
        conz
        [ DerivClause (Just StockStrategy) (map ConT [''Show, ''Generic, ''Eq])
        , DerivClause (Just AnyclassStrategy) (map ConT [''ToJSON, ''FromJSON])
        ]
    ]
 where
  extractCon (InstanceD _ _ (AppT _ con@(ConT name)) _) = Just $ NormalC
    (TH.mkName $ nameBase name ++ "'")
    [(Bang TH.NoSourceUnpackedness TH.NoSourceStrictness, con)]
  extractCon _ = Nothing

buildEntityLookupList :: String -> Q Exp
buildEntityLookupList nm = do
  ClassI _ instances <- reify (TH.mkName $ "Is" ++ nm)
  let conz = mapMaybe extractCon instances
  pure $ ListE conz
 where
  extractCon (InstanceD _ _ (AppT _ (ConT name)) _) = Just $ AppE
    (AppE (VarE $ TH.mkName "fmap") (ConE $ TH.mkName $ nameBase name ++ "'"))
    (VarE $ toFunName $ nameBase name)
  extractCon _ = Nothing
  toFunName [] = TH.mkName ""
  toFunName (x : xs) = TH.mkName $ C.toLower x : xs
