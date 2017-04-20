{-# LANGUAGE OverloadedStrings #-}
module NodeEditor.React.View.ExpressionNode where

import qualified Data.Aeson                                            as Aeson
import qualified Data.HashMap.Strict                                   as HashMap
import qualified Data.Map.Lazy                                         as Map
import           Data.Matrix                                           (Matrix)
import qualified Empire.API.Data.MonadPath                             as MonadPath
import           Empire.API.Data.PortRef                               (toAnyPortRef)
import qualified JS.Config                                             as Config
import qualified JS.UI                                                 as UI
import           NodeEditor.Data.Matrix                               (showNodeMatrix, showNodeTranslate)
import qualified NodeEditor.Event.Mouse                               as Mouse
import qualified NodeEditor.Event.UI                                  as UI
import           Common.Prelude
import qualified NodeEditor.React.Event.Node                          as Node
import           NodeEditor.React.Model.App                           (App)
import qualified NodeEditor.React.Model.Field                         as Field
import           NodeEditor.React.Model.Node.ExpressionNode           (ExpressionNode, NodeLoc, Subgraph, countArgPorts, countOutPorts,
                                                                        isCollapsed, returnsError)
import qualified NodeEditor.React.Model.Node.ExpressionNode           as Node
import qualified NodeEditor.React.Model.Node.ExpressionNodeProperties as Prop
import           NodeEditor.React.Model.Port                          (AnyPortId (InPortId'), InPortIndex (Arg, Self), isInPort, isOutAll,
                                                                        withOut)
import qualified NodeEditor.React.Model.Port                          as Port
import           NodeEditor.React.Store                               (Ref, dispatch)
import           NodeEditor.React.View.ExpressionNode.Properties      (nodeProperties_)
import           NodeEditor.React.View.Field                          (singleField_)
import           NodeEditor.React.View.Field                          (multilineField_)
import           NodeEditor.React.View.Monad                          (monads_)
import           NodeEditor.React.View.Plane                          (planeMonads_, svgPlanes_)
import           NodeEditor.React.View.Port                           (portExpanded_, portPhantom_, port_)
import           NodeEditor.React.View.Style                          (blurBackground_, errorMark_, selectionMark_)
import qualified NodeEditor.React.View.Style                          as Style
import           NodeEditor.React.View.Visualization                  (nodeShortValue_, nodeVisualizations_)
import           React.Flux
import qualified React.Flux                                            as React


name, objNameBody, objNamePorts :: JSString
name            = "node"
objNameBody     = "node-body"
objNamePorts    = "node-ports"

nodePrefix :: JSString
nodePrefix = Config.prefix "node-"

nameLabelId :: JSString
nameLabelId = Config.prefix "focus-nameLabel"

focusNameLabel :: IO ()
focusNameLabel = UI.focus nameLabelId

handleMouseDown :: Ref App -> NodeLoc -> Event -> MouseEvent -> [SomeStoreAction]
handleMouseDown ref nodeLoc e m =
    if Mouse.withoutMods m Mouse.leftButton || Mouse.withShift m Mouse.leftButton
    then stopPropagation e : dispatch ref (UI.NodeEvent $ Node.MouseDown m nodeLoc)
    else []

node_ :: Ref App -> ExpressionNode -> ReactElementM ViewEventHandler ()
node_ ref model = React.viewWithSKey node (jsShow $ model ^. Node.nodeId) (ref, model) mempty

node :: ReactView (Ref App, ExpressionNode)
node = React.defineView name $ \(ref, n) -> case n ^. Node.mode of
    Node.Expanded (Node.Function fs) -> nodeContainer_ ref $ Map.elems fs
    _ -> do
        let nodeId          = n ^. Node.nodeId
            nodeLoc         = n ^. Node.nodeLoc
            nodeLimit       = 10000::Int
            zIndex          = n ^. Node.zPos
            z               = if isCollapsed n then zIndex else zIndex + nodeLimit
            isVisualization = Prop.fromNode n ^. Prop.visualizationsEnabled
        div_
            [ "key"       $= (nodePrefix <> fromString (show nodeId))
            , "id"        $= (nodePrefix <> fromString (show nodeId))
            , "className" $= Style.prefixFromList ( [ "node", (if isCollapsed n then "node--collapsed" else "node--expanded") ]
                                                           ++ (if returnsError n then ["node--error"] else [])
                                                           ++ (if n ^. Node.isSelected then ["node--selected"] else []) )
            , "style"     @= Aeson.object [ "zIndex" Aeson..= show z ]
            , onMouseDown   $ handleMouseDown ref nodeLoc
            , onClick       $ \_ m -> dispatch ref $ UI.NodeEvent $ Node.Select m nodeLoc
            , onDoubleClick $ \e _ -> stopPropagation e : (dispatch ref $ UI.NodeEvent $ Node.Enter nodeLoc)
            ] $ do
            svg_
                [ "className" $= Style.prefix "node__text"
                , "key"       $= "nodeText"
                ] $
                g_
                    [ "className" $= Style.prefix "node-translate"
                    ] $ do
                    text_
                        [ "key"         $= "expressionText"
                        , onDoubleClick $ \e _ -> stopPropagation e : dispatch ref (UI.NodeEvent $ Node.EditExpression nodeLoc)
                        , "className"   $= Style.prefixFromList [ "node__name", "node__name--expression", "noselect" ]
                        , "y"           $= "-16"
                        ] $ elemString . convert $ n ^. Node.expression

                    if n ^. Node.isNameEdited then
                        term "foreignObject"
                            [ "key"    $= "nameEdit"
                            , "width"  $= "200"
                            , "height" $= "30"
                            ] $ singleField_ ["id"  $= nameLabelId] "name-label"
                                $ Field.mk ref (fromMaybe def $ n ^. Node.name)
                                & Field.onCancel .~ Just (const $ UI.NodeEvent $ Node.NameEditDiscard nodeLoc)
                                & Field.onAccept .~ Just (UI.NodeEvent . Node.NameEditApply nodeLoc)
                    else
                        text_
                            [ "key"         $= "nameText"
                            , onDoubleClick $ \e _ -> stopPropagation e : dispatch ref (UI.NodeEvent $ Node.NameEditStart nodeLoc)
                            , "className"   $= Style.prefixFromList [ "node__name", "noselect" ]
                            ] $ elemString $ convert $ fromMaybe def $ n ^. Node.name
                    g_
                        [ "key"       $= "icons"
                        , "className" $= Style.prefix "node__icons"
                        ] $ do
                        rect_
                            [ "key" $= "ctrlSwitch"
                            , "className" $= Style.prefixFromList (["icon", "icon--show"] ++ if isVisualization then ["icon--show--on"] else ["icon--show--off"])
                            , onClick $ \_ _ -> dispatch ref $ UI.NodeEvent $ Node.DisplayResultChanged (not isVisualization) nodeLoc
                            ] mempty
            nodeBody_ ref n
            div_
                [ "key"       $= "results"
                , "className" $= Style.prefixFromList ["node__results", "node-translate"]
                ] $ do
                nodeShortValue_ n
                if isVisualization then nodeVisualizations_ ref n else return ()
            nodePorts_ ref n

nodeDynamicStyles_ :: Matrix Double -> ExpressionNode -> ReactElementM ViewEventHandler ()
nodeDynamicStyles_ camera n = do
    let nodeId  = n ^. Node.nodeId
        nodePos = n ^. Node.position
    elemString $ "#" <> Config.mountPoint <> "-node-" <> fromString (show nodeId) <> " .luna-node-translate--name { transform: " <> showNodeTranslate camera nodePos <> " }"
    elemString $ "#" <> Config.mountPoint <> "-node-" <> fromString (show nodeId) <> " .luna-node-translate { transform: "       <> showNodeTranslate camera nodePos <> " }"
    elemString $ "#" <> Config.mountPoint <> "-node-" <> fromString (show nodeId) <> " .luna-node-transform { transform: "       <> showNodeMatrix    camera nodePos <> " }"
    elemString $ "#" <> Config.mountPoint <> "-node-" <> fromString (show nodeId) <> " path.luna-port__shape { clip-path: url(#port-io-shape-mask-"   <> show nodeId <> ") }"
    elemString $ "#" <> Config.mountPoint <> "-node-" <> fromString (show nodeId) <> " path.luna-port__select { clip-path: url(#port-io-select-mask-" <> show nodeId <> ") }"

nodeBody_ :: Ref App -> ExpressionNode -> ReactElementM ViewEventHandler ()
nodeBody_ ref model = React.viewWithSKey nodeBody "node-body" (ref, model) mempty

nodeBody :: ReactView (Ref App, ExpressionNode)
nodeBody = React.defineView objNameBody $ \(ref, n) -> do
    let nodeLoc = n ^. Node.nodeLoc
    div_
        [ "key"       $= "nodeBody"
        , "className" $= Style.prefixFromList [ "node__body", "node-translate" ]
        ] $ do
        errorMark_
        selectionMark_
        div_
            [ "key"       $= "properties-crop"
            , "className" $= Style.prefix "node__properties-crop"
            ] $ do
            blurBackground_
            case n ^. Node.mode of
                Node.Expanded Node.Controls      -> nodeProperties_ ref $ Prop.fromNode n
                Node.Expanded Node.Editor        -> multilineField_ [] "editor"
                    $ Field.mk ref (fromMaybe def $ n ^. Node.code)
                    & Field.onCancel .~ Just (UI.NodeEvent . Node.SetCode nodeLoc)
                _                                -> ""

nodePorts_ :: Ref App -> ExpressionNode -> ReactElementM ViewEventHandler ()
nodePorts_ ref model = React.viewWithSKey nodePorts objNamePorts (ref, model) mempty

nodePorts :: ReactView (Ref App, ExpressionNode)
nodePorts = React.defineView objNamePorts $ \(ref, n) -> do
    let nodeId     = n ^. Node.nodeId
        nodeLoc    = n ^. Node.nodeLoc
        nodePorts' = Node.portsList n
        ports p   = forM_ p $ \port -> port_ ref
                                             nodeLoc
                                             port
                                            (if isInPort $ port ^. Port.portId then countArgPorts n else countOutPorts n)
                                            (withOut isOutAll (port ^. Port.portId) && countArgPorts n + countOutPorts n == 1)
    svg_
        [ "key"       $= "nodePorts"
        , "className" $= Style.prefixFromList [ "node__ports" ]
        ] $ do
        defs_
            [ "key" $= "defs" ] $ do
            clipPath_
                [ "id"  $= fromString ("port-io-shape-mask-" <> show nodeId)
                , "key" $= "portIoShapeMask"
                ] $
                circle_
                    [ "className" $= Style.prefix "port-io-shape-mask"
                    ] mempty
            clipPath_
                [ "id"  $= fromString ("port-io-shape-mask-" <> show nodeId)
                , "key" $= "portIoSelectMask"
                ] $
                circle_
                    [ "className" $= Style.prefix "port-io-select-mask"
                    ] mempty
        g_
            [ "className" $= Style.prefix "node-transform"
            , "key"       $= "nodeTransform"
            ] $ do
            if isCollapsed n then do
                ports $ filter (\port -> (port ^. Port.portId) /= InPortId' [Self]) nodePorts'
                ports $ filter (\port -> (port ^. Port.portId) == InPortId' [Self]) nodePorts'
            else do
                ports $ filter (\port -> (port ^. Port.portId) == InPortId' [Self]) nodePorts'
                forM_  (filter (\port -> (port ^. Port.portId) /= InPortId' [Self]) nodePorts') $ \port -> portExpanded_ ref nodeLoc port
            portPhantom_ ref $ toAnyPortRef nodeLoc $ InPortId' [Arg $ countArgPorts n]

nodeContainer_ :: Ref App -> [Subgraph] -> ReactElementM ViewEventHandler ()
nodeContainer_ ref subgraphs = React.viewWithSKey nodeContainer "node-container" (ref, subgraphs) mempty

nodeContainer :: ReactView (Ref App, [Subgraph])
nodeContainer = React.defineView name $ \(ref, subgraphs) -> do
    div_
        [ "className" $= Style.prefix "subgraphs"
        ] $ forM_ subgraphs $ \subgraph -> do
        let input        = subgraph ^. Node.inputNode
            output       = subgraph ^. Node.outputNode
            nodes        = subgraph ^. Node.expressionNodes . to HashMap.elems
            lookupNode m = ( m ^. MonadPath.monadType
                           , m ^. MonadPath.path . to (mapMaybe $ flip HashMap.lookup $ subgraph ^. Node.expressionNodes))
            monads       = map lookupNode $ subgraph ^. Node.monads
        div_
            [ "className" $= Style.prefix "subgraph"
            ] $ do
            forM_ nodes $ node_ ref
            svgPlanes_ $ planeMonads_ $ monads_ monads