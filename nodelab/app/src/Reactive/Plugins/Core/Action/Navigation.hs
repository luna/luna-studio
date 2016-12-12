module Reactive.Plugins.Core.Action.Navigation where

import qualified Data.HashMap.Strict        as HashMap

import           Utils.PreludePlus
import           Utils.Vector

import           React.Flux                 (KeyboardEvent)

import qualified Empire.API.Data.Connection as C
import           Empire.API.Data.Node       (NodeId)
import qualified Empire.API.Data.Port       as P
import qualified Empire.API.Data.PortRef    as R
import           Event.Event                (Event (UI))
import qualified Event.Keys                 as Keys
import           Event.UI                   (UIEvent (AppEvent))
import           Object.Widget              (Position)
import qualified Object.Widget.Node         as Model
import qualified React.Event.App            as App
import           React.Store                (Ref, WRef (..), ref, widget)
import qualified React.Store                as Store
import           React.Store.Node           (Node)
import qualified React.Store.Node           as Node
import           Reactive.Commands.Batch    (cancelCollaborativeTouch, collaborativeTouch)
import           Reactive.Commands.Command  (Command)
import           Reactive.Commands.Graph    (allNodes')
import           Reactive.State.Global      (State)
import qualified Reactive.State.Global      as Global
import qualified Reactive.State.Graph       as Graph



toAction :: Event -> Maybe (Command State ())
toAction (UI (AppEvent (App.KeyDown e))) = Just $ handleKey e
toAction _ = Nothing

handleKey :: KeyboardEvent -> Command State ()
handleKey evt
    | Keys.withShift     evt Keys.leftArrow  = goPrev
    | Keys.withShift     evt Keys.rightArrow = goNext
    | Keys.withoutMods   evt Keys.leftArrow  = goLeft
    | Keys.withoutMods   evt Keys.upArrow    = goUp
    | Keys.withoutMods   evt Keys.rightArrow = goRight
    | Keys.withoutMods   evt Keys.downArrow  = goDown
    | Keys.withCtrlShift evt Keys.leftArrow  = goConeLeft
    | Keys.withCtrlShift evt Keys.upArrow    = goConeUp
    | Keys.withCtrlShift evt Keys.rightArrow = goConeRight
    | Keys.withCtrlShift evt Keys.downArrow  = goConeDown
    | otherwise                              = return ()

goPrev :: Command State ()
goPrev = do
    nodes <- allNodes'
    let selectedNodes = findSelected nodes
    unless (null selectedNodes) $ do
        let nodeSrc = findLeftMost selectedNodes
            nodeId = nodeSrc ^. widget . Model.nodeId
            inPortRefSelf      = R.InPortRef nodeId P.Self
            inPortRefFirstPort = R.InPortRef nodeId $ P.Arg 0
        prevSelfNodeIdMay <- preuse $ Global.graph . Graph.connectionsMap . ix inPortRefSelf . C.src . R.srcNodeId
        case prevSelfNodeIdMay of
            Just prevSelfNodeId -> goToNodeId selectedNodes prevSelfNodeId
            Nothing -> do
                prevFirstPortNodeIdMay <- preuse $ Global.graph . Graph.connectionsMap . ix inPortRefFirstPort . C.src . R.srcNodeId
                withJust prevFirstPortNodeIdMay $ \prevFirstPortNodeId -> goToNodeId selectedNodes prevFirstPortNodeId

goNext :: Command State ()
goNext = do
    nodes <- allNodes'
    let selectedNodes = findSelected nodes
    unless (null selectedNodes) $ do
        let nodeSrc = findRightMost selectedNodes
            nodeId = nodeSrc ^. widget . Model.nodeId
        nextNodeIds <- getDstNodeIds nodeId
        nextNodes <- catMaybes <$> mapM toWidgetFile nextNodeIds
        unless (null nextNodes) $ do
            let nextNode = findUpMost nextNodes
            changeSelection selectedNodes nextNode

getDstNodeIds :: NodeId -> Command State [NodeId]
getDstNodeIds nodeId = do
    connMap <- use $ Global.graph . Graph.connectionsMap
    let connections = filter matchNodeId $ HashMap.elems connMap
    return $ (^. C.dst . R.dstNodeId) <$> connections
    where
        matchNodeId conn = conn ^. C.src . R.srcNodeId == nodeId

toWidgetFile :: NodeId -> Command State (Maybe (WRef Node))
toWidgetFile nodeId = do
    nodeRef <- Global.getNode nodeId
    mapM Store.get' nodeRef

goToNodeId :: [WRef Node] -> NodeId -> Command State ()
goToNodeId selectedNodes nodeId = do
    refNodeMay <- Global.getNode nodeId
    withJust refNodeMay $ \refNode ->
        changeSelection' selectedNodes nodeId refNode

goRight, goLeft, goDown, goUp :: Command State ()
goRight = go findRightMost findNodesOnRightSide findNearestRight
goLeft  = go findLeftMost  findNodesOnLeftSide  findNearestLeft
goDown  = go findDownMost  findNodesOnDownSide  findNearestDown
goUp    = go findUpMost    findNodesOnUpSide    findNearestUp

go :: ([WRef Node] -> WRef Node) ->
      (Position -> [WRef Node] -> [WRef Node]) ->
      (Position -> [WRef Node] -> WRef Node) ->
      Command State ()
go findMost findNodesOnSide findNearest = do
    nodes <- allNodes'
    let selectedNodes = findSelected nodes
    unless (null selectedNodes) $ do
        let nodeSrc = findMost selectedNodes
            pos = nodeSrc ^. widget . Model.position
            nodesSide = findNodesOnSide pos nodes
        unless (null nodesSide) $ do
            let nearest = findNearest pos nodesSide
            changeSelection selectedNodes nearest

closenestPow :: Double
closenestPow = 2.5

axisDistanceRight, axisDistanceLeft, axisDistanceDown, axisDistanceUp :: Vector2 Double -> Double
axisDistanceRight (Vector2 x' _) =  x'
axisDistanceLeft  (Vector2 x' _) = -x'
axisDistanceDown  (Vector2 _ y') =  y'
axisDistanceUp    (Vector2 _ y') = -y'

findNearestRight, findNearestLeft, findNearestDown, findNearestUp :: Position -> [WRef Node] -> WRef Node
findNearestRight pos = maximumBy (compare `on` closenest pos axisDistanceRight)
findNearestLeft  pos = maximumBy (compare `on` closenest pos axisDistanceLeft)
findNearestDown  pos = maximumBy (compare `on` closenest pos axisDistanceDown)
findNearestUp    pos = maximumBy (compare `on` closenest pos axisDistanceUp)

closenest :: Position -> (Vector2 Double -> Double) -> WRef Node -> Double
closenest pos axisDistance wf = axisDist / (dist ** closenestPow) where
    pos' = wf ^. widget . Model.position
    vect = pos' - pos
    dist = magnitude vect
    axisDist = axisDistance vect

goConeRight, goConeLeft, goConeDown, goConeUp :: Command State ()
goConeRight = goCone findRightMost findNodesOnRight findNodesOnRightSide
goConeLeft  = goCone findLeftMost  findNodesOnLeft  findNodesOnLeftSide
goConeDown  = goCone findDownMost  findNodesOnDown  findNodesOnDownSide
goConeUp    = goCone findUpMost    findNodesOnUp    findNodesOnUpSide

goCone :: ([WRef Node] -> WRef Node) ->
          (Position -> [WRef Node] -> [WRef Node]) ->
          (Position -> [WRef Node] -> [WRef Node]) ->
          Command State ()
goCone findMost findNodesInCone findNodesOnSide = do
    nodes <- allNodes'
    let selectedNodes = findSelected nodes
    unless (null selectedNodes) $ do
        let nodeSrc = findMost selectedNodes
            pos = nodeSrc ^. widget . Model.position
            nodesCone = findNodesInCone pos nodes
            nodesSide = findNodesOnSide pos nodes
        if not $ null nodesCone
            then                           changeSelection selectedNodes $ findNearestNode pos nodesCone
            else unless (null nodesSide) $ changeSelection selectedNodes $ findNearestNode pos nodesSide

findRightMost, findLeftMost, findDownMost, findUpMost :: [WRef Node] -> WRef Node
findRightMost = maximumBy (compare `on` (^. widget . Model.position . x))
findLeftMost  = minimumBy (compare `on` (^. widget . Model.position . x))
findDownMost  = maximumBy (compare `on` (^. widget . Model.position . y))
findUpMost    = minimumBy (compare `on` (^. widget . Model.position . y))

findNodesOnRightSide, findNodesOnLeftSide, findNodesOnDownSide, findNodesOnUpSide :: Position -> [WRef Node] -> [WRef Node]
findNodesOnRightSide pos = filter $ \wf -> wf ^. widget . Model.position . x > pos ^. x
findNodesOnLeftSide  pos = filter $ \wf -> wf ^. widget . Model.position . x < pos ^. x
findNodesOnDownSide  pos = filter $ \wf -> wf ^. widget . Model.position . y > pos ^. y
findNodesOnUpSide    pos = filter $ \wf -> wf ^. widget . Model.position . y < pos ^. y

findNodesOnRight, findNodesOnLeft, findNodesOnDown, findNodesOnUp :: Position -> [WRef Node] -> [WRef Node]
findNodesOnRight = filter . isOnRight
findNodesOnLeft  = filter . isOnLeft
findNodesOnDown  = filter . isOnDown
findNodesOnUp    = filter . isOnUp

isOnRight, isOnLeft, isOnDown, isOnUp :: Position -> WRef Node -> Bool
isOnRight = isInCone (>)  skip (>=)
isOnLeft  = isInCone (<)  skip (>=)
isOnDown  = isInCone skip (>)  (<)
isOnUp    = isInCone skip (<)  (<)

skip :: Double -> Double -> Bool
skip _ _ = True

isInCone :: (Double -> Double -> Bool) -> (Double -> Double -> Bool) -> (Double -> Double -> Bool) -> Position -> WRef Node -> Bool
isInCone cmpDXZero cmpDYZero cmpDims pos wf = dx `cmpDXZero` 0.0 && dy `cmpDYZero` 0.0 && abs dx `cmpDims` abs dy where
    nodePos = wf ^. widget . Model.position
    dx = nodePos ^. x - pos ^. x
    dy = nodePos ^. y - pos ^. y

findSelected :: [WRef Node] -> [WRef Node]
findSelected = filter $ view (widget . Node.isSelected)

findNearestNode :: Position -> [WRef Node] -> WRef Node
findNearestNode pos = minimumBy (compare `on` distance pos)

distance :: Position -> WRef Node -> Double
distance pos wf = lengthSquared (wpos - pos) where
    wpos = wf ^. widget . Model.position

changeSelection :: [WRef Node] -> WRef Node -> Command State ()
changeSelection selectedNodes node = do
    unselectNodes selectedNodes
    selectNode node

changeSelection' :: [WRef Node] -> NodeId -> Ref Node -> Command State ()
changeSelection' selectedNodes nodeId nodeRef = do
    unselectNodes selectedNodes
    selectNode' nodeId nodeRef

unselectNodes :: [WRef Node] -> Command State ()
unselectNodes selectedNodes = do
    forM_ selectedNodes $
        Store.modify_ (Model.isSelected .~ False) . _ref
    cancelCollaborativeTouch $ view (widget . Model.nodeId) <$> selectedNodes

selectNode :: WRef Node -> Command State ()
selectNode node = selectNode' (node ^. widget . Model.nodeId) (node ^. ref)

selectNode' :: NodeId -> Ref Node -> Command State ()
selectNode' nodeId nodeRef = do
    Store.modify_ (Model.isSelected .~ True) nodeRef
    collaborativeTouch [nodeId]
