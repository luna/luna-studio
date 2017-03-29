{-# OPTIONS_GHC -fno-warn-orphans #-}
module Luna.Studio.Action.Visualization
    ( pin
    , unpin
    , startDrag
    , stopDrag
    , drag
    ) where

import           React.Flux                                  (MouseEvent)

import           Data.Position                               (Position)
import           Empire.API.Data.NodeLoc                     (NodeLoc)
import           Luna.Studio.Action.Command                  (Command)
import           Luna.Studio.Action.State.Action             (beginActionWithKey, continueActionWithKey, removeActionFromState,
                                                              updateActionWithKey)
import           Luna.Studio.Action.State.NodeEditor         (getExpressionNode, modifyNodeEditor)
import           Luna.Studio.Event.Mouse                     (workspacePosition)
import           Luna.Studio.Prelude
import           Luna.Studio.React.Model.Node.ExpressionNode (position)
import           Luna.Studio.React.Model.NodeEditor          (visualizations)
import           Luna.Studio.State.Action                    (Action (begin, continue, end, update), VisualizationDrag (VisualizationDrag),
                                                              visualizationDragAction)
import           Luna.Studio.State.Global                    (State)


instance Action (Command State) VisualizationDrag where
    begin    = beginActionWithKey    visualizationDragAction
    continue = continueActionWithKey visualizationDragAction
    update   = updateActionWithKey   visualizationDragAction
    end _    = removeActionFromState visualizationDragAction


pin :: NodeLoc -> Int -> Command State ()
pin nl visIx = do
    mayNode <- getExpressionNode nl
    withJust mayNode $ \node ->
        modifyNodeEditor $
            visualizations %= ((nl, visIx, node ^. position) :)

unpin :: NodeLoc -> Int -> Position -> Command State ()
unpin nl visIx pos =
    modifyNodeEditor $ visualizations %= delete (nl, visIx, pos)

startDrag :: NodeLoc -> Int -> Position -> MouseEvent -> Command State ()
startDrag nl visIx pos evt = do
    begin $ VisualizationDrag nl visIx pos
    moveTo evt nl visIx pos

drag :: MouseEvent -> VisualizationDrag -> Command State ()
drag evt (VisualizationDrag nl visIx pos) = moveTo evt nl visIx pos

stopDrag :: MouseEvent -> VisualizationDrag ->  Command State ()
stopDrag evt (VisualizationDrag nl visIx pos) = do
    moveTo evt nl visIx pos
    removeActionFromState visualizationDragAction

moveTo :: MouseEvent -> NodeLoc -> Int -> Position -> Command State ()
moveTo evt nl visIx oldPos = do
    pos <- workspacePosition evt
    update $ VisualizationDrag nl visIx pos
    modifyNodeEditor $ do
        visualizations %= delete (nl, visIx, oldPos)
        visualizations %= ((nl, visIx, pos) :)
