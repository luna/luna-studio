{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE TypeApplications #-}
module NodeEditor.Action.Connect
    ( handleConnectionMouseDown
    , handleMove
    , handleMouseUp
    , handlePortMouseUp
    , startConnecting
    , snapToPort
    , cancelSnapToPort
    , connectToPort
    , stopConnectingUnsafe
    ) where

import           Common.Prelude
import           Control.Monad.Trans.Maybe                  (MaybeT (MaybeT), runMaybeT)
import           Data.ScreenPosition                        (ScreenPosition)
import qualified JS.GoogleAnalytics                         as GA
import qualified LunaStudio.Data.Connection                 as ConnectionAPI
import           LunaStudio.Data.Port                       (AnyPortId (InPortId'), InPortIndex (Self))
import           LunaStudio.Data.PortRef                    (AnyPortRef (InPortRef', OutPortRef'))
import qualified LunaStudio.Data.PortRef                    as PortRef
import           NodeEditor.Action.Basic                    (connect, localAddConnection, localRemovePort, removeConnection,
                                                             updateAllPortsSelfVisibility)
import qualified NodeEditor.Action.Batch                    as Batch
import           NodeEditor.Action.Command                  (Command)
import           NodeEditor.Action.NodeDrag                 (startNodeDrag)
import           NodeEditor.Action.State.Action             (beginActionWithKey, continueActionWithKey, removeActionFromState,
                                                             updateActionWithKey)
import           NodeEditor.Action.State.Model              (createHalfConnectionModel, createHalfConnectionModel')
import           NodeEditor.Action.State.NodeEditor         (getConnection, getNode, modifyNodeEditor)
import           NodeEditor.Action.State.Scene              (translateToWorkspace)
import           NodeEditor.Event.Mouse                     (mousePosition, workspacePosition)
import           NodeEditor.React.Event.Connection          (ModifiedEnd (Destination, Source))
import           NodeEditor.React.Model.Connection          (ConnectionId, toValidEmpireConnection)
import qualified NodeEditor.React.Model.Connection          as Connection
import           NodeEditor.React.Model.Node                (Node (Expression))
import           NodeEditor.React.Model.Node.ExpressionNode (isCollapsed)
import qualified NodeEditor.React.Model.NodeEditor          as NodeEditor
import           NodeEditor.State.Action                    (Action (begin, continue, end, update), Connect (Connect), Mode (Click, Drag),
                                                             connectAction, connectIsArgumentConstructor, connectMode, connectSnappedPort,
                                                             connectSourcePort, connectStartPos)
import           NodeEditor.State.Global                    (State, actions, currentConnectAction)
import           React.Flux                                 (MouseEvent)


instance Action (Command State) Connect where
    begin action = beginActionWithKey    connectAction action >> actions . currentConnectAction ?= action
    continue     = continueActionWithKey connectAction
    update       = updateActionWithKey   connectAction
    end action   = do
        stopConnectingUnsafe action
        when (action ^. connectIsArgumentConstructor) $ case action ^. connectSourcePort of
            OutPortRef' outPortRef -> void $ localRemovePort outPortRef
            _                      -> return ()


handleConnectionMouseDown :: MouseEvent -> ConnectionId -> ModifiedEnd -> Command State ()
handleConnectionMouseDown evt connId modifiedEnd = do
    withJustM (getConnection connId) $ \connection -> do
        let portRef = case modifiedEnd of
                Destination -> OutPortRef' (connection ^. Connection.src)
                Source      -> InPortRef'  (connection ^. Connection.dst)
        mousePos <- mousePosition evt
        startConnecting mousePos portRef (Just connId) False Drag

startConnecting :: ScreenPosition -> AnyPortRef -> Maybe ConnectionId -> Bool -> Mode -> Command State ()
startConnecting screenMousePos anyPortRef mayModifiedConnId isArgumentConstructor connectMode' = do
    let nodeLoc = anyPortRef ^. PortRef.nodeLoc
        portId  = anyPortRef ^. PortRef.portId
    mousePos <- translateToWorkspace screenMousePos
    maySuccess <- runMaybeT $ do
        node <- MaybeT $ getNode nodeLoc
        let shouldDoNodeDrag = case node of
                Expression node' -> isNothing mayModifiedConnId
                                 && portId == InPortId' [Self]
                                 && isCollapsed node'
                _                -> False
        if shouldDoNodeDrag
        then lift $ when (connectMode' == Drag) $ startNodeDrag mousePos nodeLoc True
        else do
            halfConnectionModel <- MaybeT $ createHalfConnectionModel anyPortRef mousePos
            let action = Connect screenMousePos anyPortRef (isJust mayModifiedConnId) Nothing isArgumentConstructor connectMode'
            lift $ do
                withJust mayModifiedConnId removeConnection
                begin action
                void $ updateAllPortsSelfVisibility
                modifyNodeEditor $ do
                    withJust mayModifiedConnId $ \connId ->
                        NodeEditor.connections . at connId .= Nothing
                    NodeEditor.halfConnections .= [halfConnectionModel]
    when (isNothing maySuccess && isArgumentConstructor) $ case anyPortRef of
        OutPortRef' outPortRef -> void $ localRemovePort outPortRef
        _                      -> return ()

handleMove :: MouseEvent -> Connect -> Command State ()
handleMove evt action = when (isNothing $ action ^. connectSnappedPort) $ do
    mousePos                  <- workspacePosition evt
    mayHalfConnectionModel <- createHalfConnectionModel (action ^. connectSourcePort) mousePos
    modifyNodeEditor $ NodeEditor.halfConnections .= maybeToList mayHalfConnectionModel
    when (isNothing mayHalfConnectionModel) $ end action

handlePortMouseUp :: AnyPortRef -> Connect -> Command State ()
handlePortMouseUp portRef action = when (action ^. connectMode == Drag) $
    connectToPort portRef action

snapToPort :: AnyPortRef -> Connect -> Command State ()
snapToPort portRef action =
    withJust (toValidEmpireConnection (action ^. connectSourcePort) portRef) $ \conn -> do
        mayConnModel <- createHalfConnectionModel' (conn ^. ConnectionAPI.src) (conn ^. ConnectionAPI.dst)
        withJust mayConnModel $ \connModel -> do
            update $ action & connectSnappedPort ?~ portRef
            modifyNodeEditor $ NodeEditor.halfConnections .= [connModel]

cancelSnapToPort :: AnyPortRef -> Connect -> Command State ()
cancelSnapToPort portRef action = when (Just portRef == action ^. connectSnappedPort) $
    update $ action & connectSnappedPort .~ Nothing

handleMouseUp :: MouseEvent -> Connect -> Command State ()
handleMouseUp evt action = when (action ^. connectMode == Drag) $ do
    mousePos <- mousePosition evt
    if (mousePos == action ^. connectStartPos) then
        update $ action & connectMode .~ Click
    else end action

stopConnectingUnsafe :: Connect -> Command State ()
stopConnectingUnsafe _ = do
    modifyNodeEditor $ NodeEditor.halfConnections .= def
    actions . currentConnectAction .= Nothing
    removeActionFromState connectAction
    void $ updateAllPortsSelfVisibility

connectToPort :: AnyPortRef -> Connect -> Command State ()
connectToPort dst action = do
    withJust (toValidEmpireConnection dst $ action ^. connectSourcePort) $ \newConn -> do
        case (action ^. connectIsArgumentConstructor, action ^. connectSourcePort) of
            (True, OutPortRef' outPortRef) -> do
                void . localAddConnection outPortRef $ newConn ^. ConnectionAPI.dst
                Batch.addPort outPortRef $ Just $ newConn ^. ConnectionAPI.dst
            _ -> connect (Left $ newConn ^. ConnectionAPI.src) (Left $ newConn ^. ConnectionAPI.dst)
        GA.sendEvent $ GA.Connect GA.Manual
    stopConnectingUnsafe action
