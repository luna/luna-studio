module Luna.Studio.Action.State.Action where

import qualified Data.Map                   as Map
import qualified Data.Set                   as Set
import           Luna.Studio.Action.Command (Command)
import           Luna.Studio.Prelude
import           Luna.Studio.State.Action   (Action (end, update), ActionRep, SomeAction, fromSomeAction, overlappingActions, someAction)
import           Luna.Studio.State.Global   (State, currentActions)


checkSomeAction :: ActionRep -> Command State (Maybe (SomeAction (Command State)))
checkSomeAction actionRep = Map.lookup actionRep <$> use currentActions

checkAction :: Action (Command State) a => ActionRep -> Command State (Maybe a)
checkAction actionRep = do
    maySomeAction <- checkSomeAction actionRep
    return $ join $ fromSomeAction <$> maySomeAction

checkIfActionPerfoming :: ActionRep -> Command State Bool
checkIfActionPerfoming actionRep = Map.member actionRep <$> use currentActions

runningActions :: Command State [ActionRep]
runningActions = Map.keys <$> use currentActions

getCurrentOverlappingActions :: ActionRep -> Command State [SomeAction (Command State)]
getCurrentOverlappingActions a = do
    let checkOverlap :: ActionRep -> ActionRep -> Bool
        checkOverlap a1 a2 = any (Set.isSubsetOf (Set.fromList [a1, a2])) overlappingActions
        overlappingActionReps = filter (checkOverlap a) <$> runningActions
    ca <- use currentActions
    catMaybes <$> map (flip Map.lookup ca) <$> overlappingActionReps

beginActionWithKey :: Action (Command State) a => ActionRep -> a -> Command State ()
beginActionWithKey key action = do
    currentOverlappingActions <- getCurrentOverlappingActions key
    mapM_ end currentOverlappingActions
    update action

continueActionWithKey :: Action (Command State) a => ActionRep -> (a -> Command State ()) -> Command State ()
continueActionWithKey key run = do
    maySomeAction <- use $ currentActions . at key
    mapM_ run $ maySomeAction >>= fromSomeAction

updateActionWithKey :: Action (Command State) a => ActionRep -> a -> Command State ()
updateActionWithKey key action = currentActions . at key ?= someAction action

removeActionFromState :: ActionRep -> Command State ()
removeActionFromState key = currentActions %= Map.delete key

endAll :: Command State ()
endAll = mapM_ end =<< use currentActions
