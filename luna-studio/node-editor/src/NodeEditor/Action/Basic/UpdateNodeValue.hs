{-# LANGUAGE OverloadedStrings #-}
module NodeEditor.Action.Basic.UpdateNodeValue where

import           Common.Action.Command                      (Command)
import           Common.Prelude
import qualified Data.Text                                  as Text
import           LunaStudio.Data.Error                      (errorContent)
import           LunaStudio.Data.NodeValue                  (NodeValue (NodeError, NodeValue))
import           NodeEditor.Action.State.NodeEditor         (getExpressionNodeType, getVisualizersForType, modifyExpressionNode,
                                                             setVisualizationData)
import           NodeEditor.React.Model.Node.ExpressionNode (NodeLoc, Value (Error, ShortValue), value)
import           NodeEditor.React.Model.NodeEditor          (VisualizationBackup (ErrorBackup, MessageBackup, StreamBackup, ValueBackup))
import           NodeEditor.React.Model.Visualization       (VisualizationValue (StreamDataPoint, StreamStart, Value), noDataMsg, noVisMsg)
import           NodeEditor.State.Global                    (State)


updateNodeValueAndVisualization :: NodeLoc -> NodeValue -> Command State ()
updateNodeValueAndVisualization nl = \case
    NodeValue sv (Just (StreamDataPoint visVal)) -> do
        modifyExpressionNode nl $ value .= ShortValue (Text.take 100 sv)
        setVisualizationData nl (StreamBackup [visVal]) False
    NodeValue sv (Just (Value visVal)) -> do
        modifyExpressionNode nl $ value .= ShortValue (Text.take 100 sv)
        setVisualizationData nl (ValueBackup visVal) True
    NodeValue sv (Just StreamStart) -> do
        modifyExpressionNode nl $ value .= ShortValue (Text.take 100 sv)
        setVisualizationData nl (StreamBackup []) True
    NodeValue sv Nothing -> do
        modifyExpressionNode nl $ value .= ShortValue (Text.take 100 sv)
        noVisualizers <- maybe (return False) (fmap isNothing . getVisualizersForType) =<< getExpressionNodeType nl
        let msg = if noVisualizers then noVisMsg else noDataMsg
        setVisualizationData nl (MessageBackup msg) True
    NodeError e -> do
        modifyExpressionNode nl $ value .= Error e
        setVisualizationData nl (ErrorBackup $ e ^. errorContent) True
