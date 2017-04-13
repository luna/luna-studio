module Luna.Studio.Action.Port.Actions
    ( handleMouseDown
    , handleClick
    ) where

import           Empire.API.Data.PortRef             (AnyPortRef (OutPortRef'), OutPortRef, nodeLoc, srcPortId)
import           Luna.Studio.Action.Basic            (localAddPort)
import           Luna.Studio.Action.Command          (Command)
import           Luna.Studio.Action.Connect          (connectToPort, startConnecting)
import           Luna.Studio.Action.Sidebar          (startPortDrag)
import           Luna.Studio.Event.Mouse             (mousePosition)
import           Luna.Studio.Prelude
import           Luna.Studio.React.Model.Node        (countProjectionPorts, hasPort)
import           Luna.Studio.React.Model.Port        (getPortNumber)
import           Luna.Studio.State.Action            (Action (continue), Mode (Click, Drag), connectAction, connectMode, portDragAction,
                                                      portDragMode)

import           Luna.Studio.Action.State.Action     (checkAction, checkIfActionPerfoming)
import           Luna.Studio.Action.State.NodeEditor (getInputNode)
import           Luna.Studio.State.Global            (State)
import           React.Flux                          (MouseEvent)


handleMouseDown :: MouseEvent -> OutPortRef -> Command State ()
handleMouseDown evt portRef = do
    mayConnect  <- checkAction connectAction
    mayPortDrag <- checkAction portDragAction
    when ( Just Click /= (view connectMode  <$> mayConnect)
        && Just Click /= (view portDragMode <$> mayPortDrag) ) $
        startPortDragOrConnect evt portRef Drag

handleClick :: MouseEvent -> OutPortRef -> Command State ()
handleClick evt portRef = do
    mayConnect <- checkAction connectAction
    newAction  <- not <$> checkIfActionPerfoming portDragAction
    if Just Click == (view connectMode <$> mayConnect) then continue $ connectToPort $ OutPortRef' portRef
    else if newAction                                  then startPortDragOrConnect evt portRef Click
    else return ()

startPortDragOrConnect :: MouseEvent -> OutPortRef -> Mode -> Command State ()
startPortDragOrConnect evt portRef mode = do
    mousePos <- mousePosition evt
    getInputNode (portRef ^. nodeLoc) >>= \case
        Nothing -> startConnecting mousePos (OutPortRef' portRef) Nothing False mode
        Just _  -> do
            isPhantom <- addPhantomPortIfPossibleAndNeeded portRef
            startPortDrag mousePos portRef isPhantom mode

addPhantomPortIfPossibleAndNeeded :: OutPortRef -> Command State Bool
addPhantomPortIfPossibleAndNeeded portRef = do
    let nid = portRef ^. nodeLoc
        pid = portRef ^. srcPortId
    getInputNode nid >>= \case
        Nothing   -> return False
        Just node -> if hasPort pid node || countProjectionPorts node /= getPortNumber pid
            then return False
            else localAddPort portRef
