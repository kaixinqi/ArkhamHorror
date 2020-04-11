module Handler.Api.Arkham.Scenarios where

import qualified Data.Map.Monoidal    as MonoidalMap
import Data.Map.Monoidal    ( MonoidalMap)
import           Database.Esqueleto
import           Import             hiding (Value, groupBy, on, (==.))

-- brittany-disable-next-binding

getApiV1ArkhamScenariosR :: Handler (MonoidalMap Int64 [Entity ArkhamHorrorScenario])
getApiV1ArkhamScenariosR = do
    groups <- runDB $ (map convert <$>) . select . from $ \(cycles `InnerJoin` scenarios) -> do
      on $ cycles ^.  ArkhamHorrorCycleId ==. scenarios ^.  ArkhamHorrorScenarioCycleId
      pure (cycles ^. ArkhamHorrorCycleId, scenarios)
    pure $ mconcat $ map (uncurry MonoidalMap.singleton) groups
 where
   convert = bimap (fromSqlKey . unValue) pure

getApiV1ArkhamScenariosScenarioR :: ArkhamHorrorScenarioId -> Handler ArkhamHorrorScenario
getApiV1ArkhamScenariosScenarioR scenarioId = runDB $ get404 scenarioId
