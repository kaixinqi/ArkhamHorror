module Arkham.Types.Location.Cards.ScienceBuilding where

import Arkham.Prelude

import qualified Arkham.Location.Cards as Cards (scienceBuilding)
import Arkham.Types.Ability
import Arkham.Types.Classes
import Arkham.Types.Criteria
import Arkham.Types.Game.Helpers
import Arkham.Types.GameValue
import Arkham.Types.Location.Attrs
import Arkham.Types.Matcher
import Arkham.Types.Message hiding (RevealLocation)
import Arkham.Types.SkillType
import qualified Arkham.Types.Timing as Timing

newtype ScienceBuilding = ScienceBuilding LocationAttrs
  deriving anyclass (IsLocation, HasModifiersFor env)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

scienceBuilding :: LocationCard ScienceBuilding
scienceBuilding = location
  ScienceBuilding
  Cards.scienceBuilding
  2
  (PerPlayer 1)
  Hourglass
  [Plus, Squiggle]

instance HasAbilities ScienceBuilding where
  getAbilities (ScienceBuilding x) =
    withBaseAbilities x $ if locationRevealed x
      then
        [ restrictedAbility x 1 Here
        $ ForcedAbility
        $ RevealLocation Timing.After You
        $ LocationWithId
        $ toId x
        , restrictedAbility x 2 Here $ ForcedAbility $ SkillTestResult
          Timing.When
          You
          (SkillTestWithSkillType SkillWillpower)
          (FailureResult AnyValue)
        ]
      else []

instance (LocationRunner env) => RunMessage env ScienceBuilding where
  runMessage msg l@(ScienceBuilding attrs) = case msg of
    UseCardAbility _ source _ 1 _ | isSource attrs source ->
      l <$ push (PlaceLocationMatching $ CardWithTitle "Alchemy Labs")
    UseCardAbility iid source _ 2 _ | isSource attrs source ->
      l <$ push (InvestigatorAssignDamage iid source DamageAny 1 0)
    _ -> ScienceBuilding <$> runMessage msg attrs
