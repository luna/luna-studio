module NodeEditor.Action.Basic.SetNodeResult where

import           Empire.API.Graph.NodeResultUpdate           (NodeValue)
import           NodeEditor.Action.Command                  (Command)
import           NodeEditor.Action.State.NodeEditor         (modifyExpressionNode)
import           Common.Prelude
import           NodeEditor.React.Model.Node.ExpressionNode (NodeLoc, execTime, value)
import           NodeEditor.State.Global                    (State)


setNodeValue :: NodeLoc -> NodeValue -> Command State ()
setNodeValue nl val = modifyExpressionNode nl $ value ?= val

setNodeProfilingData :: NodeLoc -> Integer -> Command State ()
setNodeProfilingData nl t = modifyExpressionNode nl $ execTime ?= t