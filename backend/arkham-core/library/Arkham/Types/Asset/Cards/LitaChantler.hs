module Arkham.Types.Asset.Cards.LitaChantler where

import Arkham.Import

import Arkham.Types.Asset.Attrs
import Arkham.Types.Asset.Helpers
import Arkham.Types.Asset.Runner
import Arkham.Types.Trait

newtype LitaChantler = LitaChantler Attrs
  deriving newtype (Show, ToJSON, FromJSON)

litaChantler :: AssetId -> LitaChantler
litaChantler uuid = LitaChantler $ (baseAttrs uuid "01117")
  { assetSlots = [AllySlot]
  , assetHealth = Just 3
  , assetSanity = Just 3
  }

instance HasId LocationId env InvestigatorId => HasModifiersFor env LitaChantler where
  getModifiersFor _ (InvestigatorTarget iid) (LitaChantler a@Attrs {..}) = do
    locationId <- getId @LocationId iid
    case assetInvestigator of
      Nothing -> pure []
      Just ownerId -> do
        sameLocation <- (== locationId) <$> getId ownerId
        pure [ toModifier a (SkillModifier SkillCombat 1) | sameLocation ]
  getModifiersFor _ _ _ = pure []

ability :: EnemyId -> Attrs -> Ability
ability eid a = (mkAbility (toSource a) 1 (ReactionAbility Free))
  { abilityMetadata = Just $ TargetMetadata (EnemyTarget eid)
  }

instance HasSet Trait env EnemyId => HasActions env LitaChantler where
  getActions i (WhenSuccessfulAttackEnemy who eid) (LitaChantler a)
    | ownedBy a i && who `elem` [You, InvestigatorAtYourLocation] = do
      traits <- getSetList eid
      pure
        [ ActivateCardAbilityAction i (ability eid a) | Monster `elem` traits ]
  getActions i window (LitaChantler a) = getActions i window a

instance (AssetRunner env) => RunMessage env LitaChantler where
  runMessage msg a@(LitaChantler attrs@Attrs {..}) = case msg of
    UseCardAbility _ source (Just (TargetMetadata target)) 1 _
      | isSource attrs source -> do
        a <$ unshiftMessage
          (CreateWindowModifierEffect
            EffectSkillTestWindow
            (EffectModifiers [toModifier attrs (DamageTaken 1)])
            source
            target
          )
    _ -> LitaChantler <$> runMessage msg attrs

