{-# OPTIONS_GHC -Wno-orphans #-}
module Arkham.Event where

import Arkham.Prelude

import Arkham.Card
import Arkham.Classes
import Arkham.Event.Events
import Arkham.Event.Runner
import Arkham.Id

createEvent :: IsCard a => a -> InvestigatorId -> EventId -> Event
createEvent a iid eid = lookupEvent (toCardCode a) iid eid (toCardId a)

instance RunMessage Event where
  runMessage msg (Event a) = Event <$> runMessage msg a

lookupEvent :: CardCode -> InvestigatorId -> EventId -> CardId -> Event
lookupEvent cardCode = case lookup cardCode allEvents of
  Nothing -> error $ "Unknown event: " <> show cardCode
  Just (SomeEventCard a) -> \i e c -> Event $ cbCardBuilder a c (i, e)

instance FromJSON Event where
  parseJSON = withObject "Event" $ \o -> do
    cCode <- o .: "cardCode"
    withEventCardCode cCode
      $ \(_ :: EventCard a) -> Event <$> parseJSON @a (Object o)

withEventCardCode
  :: CardCode -> (forall a . IsEvent a => EventCard a -> r) -> r
withEventCardCode cCode f = case lookup cCode allEvents of
  Nothing -> error $ "Unknown event: " <> show cCode
  Just (SomeEventCard a) -> f a

allEvents :: HashMap CardCode SomeEventCard
allEvents = mapFrom
  someEventCardCode
  [ -- Night of the Zealot
  --- signature [notz]
    SomeEventCard onTheLam
  , SomeEventCard darkMemory
  --- guardian [notz]
  , SomeEventCard evidence
  , SomeEventCard dodge
  , SomeEventCard dynamiteBlast
  , SomeEventCard extraAmmunition1
  --- seeker [notz]
  , SomeEventCard mindOverMatter
  , SomeEventCard workingAHunch
  , SomeEventCard barricade
  , SomeEventCard crypticResearch4
  --- rogue [notz]
  , SomeEventCard elusive
  , SomeEventCard backstab
  , SomeEventCard sneakAttack
  , SomeEventCard sureGamble3
  , SomeEventCard hotStreak4
  --- mystic [notz]
  , SomeEventCard drawnToTheFlame
  , SomeEventCard wardOfProtection
  , SomeEventCard blindingLight
  , SomeEventCard mindWipe1
  , SomeEventCard blindingLight2
  --- survivor [notz]
  , SomeEventCard cunningDistraction
  , SomeEventCard lookWhatIFound
  , SomeEventCard lucky
  , SomeEventCard closeCall2
  , SomeEventCard lucky2
  , SomeEventCard willToSurvive3
  --- neutral [notz]
  , SomeEventCard emergencyCache
  -- The Dunwich Legacy
  --- signature [tdl]
  , SomeEventCard searchForTheTruth
  --- guardian [tdl]
  , SomeEventCard taunt
  , SomeEventCard teamwork
  , SomeEventCard taunt2
  --- seeker [tdl]
  , SomeEventCard shortcut
  , SomeEventCard seekingAnswers
  --- rogue [tdl]
  , SomeEventCard thinkOnYourFeet
  --- mystic [tdl]
  , SomeEventCard bindMonster2
  --- survivor [tdl]
  , SomeEventCard baitAndSwitch
  -- The Miskatonic Museum
  --- guardian [tmm]
  , SomeEventCard emergencyAid
  --- seeker [tmm]
  , SomeEventCard iveGotAPlan
  --- rogue [tmm]
  , SomeEventCard contraband
  --- mystic [tmm]
  , SomeEventCard delveTooDeep
  --- survivor [tmm]
  , SomeEventCard oops
  , SomeEventCard flare1
  -- The Essex County Express
  --- guardian [tece]
  , SomeEventCard standTogether3
  --- rogue [tece]
  , SomeEventCard imOuttaHere
  --- mystic [tece]
  , SomeEventCard hypnoticGaze
  --- survivor [tece]
  , SomeEventCard lure1
  -- Blood on the Altar
  --- guardian [bota]
  , SomeEventCard preparedForTheWorst
  --- seeker [bota]
  , SomeEventCard preposterousSketches
  --- neutral [bota]
  , SomeEventCard emergencyCache2
  -- Undimensioned and Unseen
  --- guardian [uau]
  , SomeEventCard ifItBleeds
  --- seeker [uau]
  , SomeEventCard exposeWeakness1
  -- Where Doom Awaits
  --- guardian [wda]
  , SomeEventCard iveHadWorse4
  --- rogue [wda]
  , SomeEventCard aceInTheHole3
  --- mystic [wda]
  , SomeEventCard moonlightRitual
  --- survivor [wda]
  , SomeEventCard aChanceEncounter
  --- neutral [wda]
  , SomeEventCard momentOfRespite3
  -- Lost in Time and Space
  --- guardian [litas]
  , SomeEventCard monsterSlayer5
  --- seeker [litas]
  , SomeEventCard decipheredReality5
  --- mystic [litas]
  , SomeEventCard wardOfProtection5
  -- The Path to Carcosa
  --- signature [ptc]
  , SomeEventCard thePaintedWorld
  , SomeEventCard buryThemDeep
  , SomeEventCard improvisation
  --- guardian [ptc]
  , SomeEventCard letMeHandleThis
  , SomeEventCard everVigilant1
  --- seeker [ptc]
  , SomeEventCard noStoneUnturned
  --- rogue [ptc]
  , SomeEventCard sleightOfHand
  , SomeEventCard daringManeuver
  --- mystic [ptc]
  , SomeEventCard uncageTheSoul
  , SomeEventCard astralTravel
  --- survivor [ptc]
  , SomeEventCard hidingSpot
  -- Echoes of the Past
  --- guardian [eotp]
  , SomeEventCard heroicRescue
  --- seeker [eotp]
  , SomeEventCard anatomicalDiagrams
  -- The Unspeakable Oath
  --- guardian [tuo]
  , SomeEventCard ambush1
  --- seeker [tuo]
  , SomeEventCard forewarned1
  --- rogue [tuo]
  , SomeEventCard sneakAttack2
  --- mystic [tuo]
  , SomeEventCard stormOfSpirits
  --- survivor [tuo]
  , SomeEventCard fightOrFlight
  , SomeEventCard aTestOfWill1
  , SomeEventCard devilsLuck
  --- neutral [tuo]
  , SomeEventCard callingInFavors
  -- A Phantom of Truth
  --- guardian [apot]
  , SomeEventCard illSeeYouInHell
  --- seeker [apot]
  , SomeEventCard logicalReasoning
  --- rogue [apot]
  , SomeEventCard cheapShot
  --- mystic [apot]
  , SomeEventCard quantumFlux
  , SomeEventCard recharge2
  --- survivor [apot]
  , SomeEventCard snareTrap2
  -- The Pallid Mask
  --- guardian [tpm]
  , SomeEventCard manoAMano1
  --- seeker [tpm]
  , SomeEventCard shortcut2
  --- survivor [tpm]
  , SomeEventCard waylay
  , SomeEventCard aChanceEncounter2
  --- neutral [tpm]
  , SomeEventCard emergencyCache3
  -- Black Stars Rise
  --- guardian [bsr]
  , SomeEventCard onTheHunt
  --- seeker [bsr]
  , SomeEventCard guidance
  --- rogue [bsr]
  , SomeEventCard narrowEscape
  --- mystic [bsr]
  , SomeEventCard wardOfProtection2
  --- survivor [bsr]
  , SomeEventCard trueSurvivor3
  -- Dim Carcosa
  --- guardian [dca]
  , SomeEventCard eatLead2
  --- seeker [dca]
  , SomeEventCard eideticMemory3
  , SomeEventCard noStoneUnturned5
  --- rogue [dca]
  , SomeEventCard cheatDeath5
  --- mystic [dca]
  , SomeEventCard timeWarp2
  --- survivor [dca]
  , SomeEventCard infighting3
  -- The Forgotten Age
  --- signature [tfa]
  , SomeEventCard smuggledGoods
  --- guardian [tfa]
  , SomeEventCard trusted
  , SomeEventCard reliable1
  --- seeker [tfa]
  , SomeEventCard unearthTheAncients
  --- rogue [tfa]
  , SomeEventCard eavesdrop
  , SomeEventCard youHandleThisOne
  --- mystic [tfa]
  , SomeEventCard darkProphecy
  --- survivor [tfa]
  , SomeEventCard improvisedWeapon
  , SomeEventCard dumbLuck
  --- weakness [tfa]
  , SomeEventCard darkPact
  -- Thread of Fate
  --- guardian [tof]
  , SomeEventCard sceneOfTheCrime
  , SomeEventCard marksmanship1
  --- seeker [tof]
  , SomeEventCard persuasion
  --- mystic [tof]
  , SomeEventCard counterspell2
  --- survivor [tof]
  , SomeEventCard perseverance
  -- The Boundary Beyond
  --- guardian [tbb]
  , SomeEventCard secondWind
  --- seeker [tbb]
  , SomeEventCard truthFromFiction
  -- Heart of the Elders
  --- guardian [hote]
  , SomeEventCard customAmmunition3
  --- seeker [hote]
  , SomeEventCard exposeWeakness3
  --- mystic [hote]
  , SomeEventCard premonition
  --- survivor [hote]
  , SomeEventCard liveAndLearn
  , SomeEventCard againstAllOdds2
  -- The City of Archives
  --- rogue [tcoa]
  , SomeEventCard slipAway
  , SomeEventCard payDay1
  --- mystic [tcoa]
  , SomeEventCard sacrifice1
  -- The Depths of Yoth
  --- guardian [tdoy]
  , SomeEventCard bloodEclipse3
  --- rogue [tdoy]
  , SomeEventCard coupDeGrace
  --- survivor [tdoy]
  , SomeEventCard wingingIt
  --- Shattered Aeons
  --- seeker [sha]
  , SomeEventCard vantagePoint
  --- survivor [sha]
  , SomeEventCard impromptuBarrier
  , SomeEventCard alterFate3
  -- The Circle Undone
  --- signature [tcu]
  , SomeEventCard unsolvedCase
  , SomeEventCard lodgeDebts
  , SomeEventCard darkInsight
  , SomeEventCard imDoneRunnin
  , SomeEventCard mystifyingSong
  --- guardian [tcu]
  , SomeEventCard interrogate
  , SomeEventCard delayTheInevitable
  --- seeker [tcu]
  , SomeEventCard connectTheDots
  --- rogue [tcu]
  , SomeEventCard moneyTalks
  --- mystic [tcu]
  , SomeEventCard denyExistence
  , SomeEventCard eldritchInspiration
  --- survivor [tcu]
  , SomeEventCard actOfDesperation
  -- The Secret Name
  --- seeker [tsn]
  , SomeEventCard crackTheCase
  --- rogue [tsn]
  , SomeEventCard intelReport
  -- In the Clutches of Chaos
  --- mystic [icc]
  , SomeEventCard denyExistence5
  --- survivor [icc]
  , SomeEventCard trialByFire
  -- Before the Black Throne
  --- seeker [bbt]
  , SomeEventCard bloodRite
  --- survivor [bbt]
  , SomeEventCard eucatastrophe3
  -- The Dream-Eaters
  --- seeker [tde]
  , SomeEventCard astoundingRevelation
  -- The Search for Kadath
  --- guardian [sfk]
  , SomeEventCard firstWatch
  -- A Thousand Shapes of Horror
  --- survivor [tsh]
  , SomeEventCard scroungeForSupplies
  -- Edge of the Earth
  --- guardian [eote]
  , SomeEventCard dodge2
  --- seeker [eote]
  , SomeEventCard unearthTheAncients2
  --- rogue [eote]
  , SomeEventCard moneyTalks2
  -- Return to Night of the Zealot
  --- guardian [rtnotz]
  , SomeEventCard dynamiteBlast2
  --- seeker [rtnotz]
  , SomeEventCard barricade3
  --- rogue [rtnotz]
  , SomeEventCard hotStreak2
  --- mystic [rtnotz]
  , SomeEventCard mindWipe3
  -- Return to the Dunwich Legacy
  --- seeker [rtdwl]
  , SomeEventCard preposterousSketches2
  --- rogue [rtdwl]
  , SomeEventCard contraband2
  -- Return to the Forgotten Age
  --- guardian [rttfa]
  , SomeEventCard bloodEclipse1
  -- Investigator Starter Decks
  --- Nathaniel Cho
  , SomeEventCard cleanThemOut
  , SomeEventCard counterpunch
  , SomeEventCard getOverHere
  , SomeEventCard glory
  , SomeEventCard monsterSlayer
  , SomeEventCard oneTwoPunch
  , SomeEventCard standTogether
  , SomeEventCard evidence1
  , SomeEventCard galvanize1
  , SomeEventCard counterpunch2
  , SomeEventCard getOverHere2
  , SomeEventCard lessonLearned2
  , SomeEventCard manoAMano2
  , SomeEventCard dynamiteBlast3
  , SomeEventCard taunt3
  , SomeEventCard oneTwoPunch5
  --- Harvel Walters
  , SomeEventCard burningTheMidnightOil
  , SomeEventCard crypticWritings
  , SomeEventCard extensiveResearch
  , SomeEventCard occultInvocation
  , SomeEventCard glimpseTheUnthinkable1
  , SomeEventCard crypticWritings2
  , SomeEventCard iveGotAPlan2
  , SomeEventCard mindOverMatter2
  , SomeEventCard seekingAnswers2
  --- Jacqueline Fine
  , SomeEventCard eldritchInspiration1
  --- Stella Clark
  , SomeEventCard willToSurvive
  , SomeEventCard aTestOfWill
  , SomeEventCard gritYourTeeth
  , SomeEventCard aTestOfWill2
  , SomeEventCard lookWhatIFound2
  , SomeEventCard dumbLuck2
  , SomeEventCard lucky3
  ]
