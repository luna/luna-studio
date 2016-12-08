{-# LANGUAGE OverloadedStrings #-}

module UI.Handlers.Node where

import           Utils.PreludePlus                        hiding (stripPrefix)

import           Control.Monad.Trans.State                (get)
import qualified Data.HashMap.Strict                      as HashMap
import           Data.HMap.Lazy                           (HTMap, TypeKey (..))
import qualified Data.Text.Lazy                           as Text
import           Utils.Vector

import           Object.Widget                            (CompositeWidget, KeyPressedHandler, ResizableWidget, UIHandlers, WidgetId,
                                                           createWidget, keyDown, mouseOut, mouseOver, updateWidget)

import           React.Store                              (Ref, WRef)
import qualified React.Store                              as Store
import           React.Store.Node                         (Node)
import qualified React.Store.Node                         as Node
import qualified React.Store.NodeEditor                   as NodeEditor

import qualified Object.Widget.CodeEditor                 as CodeEditor
import qualified Object.Widget.Group                      as Group
import qualified Object.Widget.Label                      as Label
import qualified Object.Widget.LabeledTextBox             as LabeledTextBox
import qualified Object.Widget.Node                       as Model
import qualified Object.Widget.TextBox                    as TextBox
import qualified Object.Widget.Toggle                     as Toggle
import           Reactive.Commands.Batch                  (cancelCollaborativeTouch, collaborativeTouch)
import           Reactive.Commands.Command                (Command)
import           Reactive.Commands.Graph.SelectionHistory (dropSelectionHistory, modifySelectionHistory)
import qualified Reactive.Commands.UIRegistry             as UICmd
import           Reactive.State.Global                    (inRegistry)
import qualified Reactive.State.Global                    as Global
import           Reactive.State.UIRegistry                (addHandler)
import qualified Reactive.State.UIRegistry                as UIRegistry

import qualified Style.Node                               as Style
import           UI.Generic                               (whenChanged)
import           UI.Handlers.Button                       (DblClickedHandler (..), MousePressedHandler (..))
import           UI.Handlers.Generic                      (ValueChangedHandler (..))
import           UI.Handlers.LabeledTextBox               ()
import           UI.Layout                                as Layout
import           UI.Widget.CodeEditor                     ()
import           UI.Widget.Group                          ()
import           UI.Widget.Label                          ()
import           UI.Widget.LabeledTextBox                 ()
import           UI.Widget.Node                           ()
import           UI.Widget.TextBox                        ()
import           UI.Widget.Toggle                         ()

import           Empire.API.Data.Node                     (NodeId)



nameHandlers :: WidgetId -> HTMap
nameHandlers wid = addHandler (ValueChangedHandler $ nameValueChangedHandler wid)
                $ addHandler (UICmd.LostFocus $ inRegistry . flip UICmd.update_ (TextBox.isEditing .~ False))
                $ mempty

visualizationToggleHandlers :: WidgetId -> HTMap
visualizationToggleHandlers wid = addHandler (ValueChangedHandler $ visualizationToggledHandler wid)
                                 $ mempty

nameValueChangedHandler :: WidgetId -> Text -> WidgetId -> Command Global.State ()
nameValueChangedHandler parent val _ = do
    model <- inRegistry $ UICmd.update parent $ Model.name .~ val
    triggerRenameNodeHandler parent model

visualizationToggledHandler :: WidgetId -> Bool -> WidgetId -> Command Global.State ()
visualizationToggledHandler parent val _ = do
    model <- inRegistry $ UICmd.update parent $ Model.visualizationsEnabled .~ val
    triggerVisualizationsToggledHandler parent model

typeHandlers :: WidgetId -> HTMap
typeHandlers wid = addHandler (ValueChangedHandler $ typeValueChangedHandler wid)
                $ addHandler (UICmd.LostFocus $ inRegistry . flip UICmd.update_ (TextBox.isEditing .~ False))
                $ mempty where

typeValueChangedHandler :: WidgetId -> Text -> WidgetId -> Command Global.State ()
typeValueChangedHandler parent val _tbId = do
    model <- inRegistry $ UICmd.update parent $ Model.tpe ?~ val
    triggerChangeInputNodeTypeHandler parent model

codeEditorChangedHandler :: WidgetId -> Text -> WidgetId -> Command Global.State ()
codeEditorChangedHandler nodeWidgetId newCode _ = triggerCodeChangedHandler nodeWidgetId newCode

codeHandlers :: WidgetId -> HTMap
codeHandlers wid = addHandler (ValueChangedHandler $ codeEditorChangedHandler wid)
                $ mempty

newtype RemoveNodeHandler = RemoveNodeHandler (Command Global.State ())
removeNodeHandler = TypeKey :: TypeKey RemoveNodeHandler

newtype FocusNodeHandler = FocusNodeHandler (WidgetId -> Command Global.State ())
focusNodeHandler = TypeKey :: TypeKey FocusNodeHandler

newtype RenameNodeHandler = RenameNodeHandler (WidgetId -> NodeId -> Text -> Command Global.State ())
renameNodeHandler = TypeKey :: TypeKey RenameNodeHandler

newtype VisualizationsToggledHandler = VisualizationsToggledHandler (WidgetId -> NodeId -> Bool -> Command Global.State ())
visualizationsToggledHandler = TypeKey :: TypeKey VisualizationsToggledHandler

newtype ChangeInputNodeTypeHandler = ChangeInputNodeTypeHandler (WidgetId -> NodeId -> Text -> Command Global.State ())
changeInputNodeTypeHandler = TypeKey :: TypeKey ChangeInputNodeTypeHandler

newtype ExpandNodeHandler = ExpandNodeHandler (Command Global.State ())
expandNodeHandler = TypeKey :: TypeKey ExpandNodeHandler

newtype EditNodeExpressionHandler = EditNodeExpressionHandler (NodeId -> Command Global.State ())
editNodeExpressionHandler = TypeKey :: TypeKey EditNodeExpressionHandler

newtype CodeChangedHandler = CodeChangedHandler (NodeId -> Text -> Command Global.State ())
codeChangedHandler = TypeKey :: TypeKey CodeChangedHandler

triggerRemoveHandler :: WidgetId -> Command Global.State ()
triggerRemoveHandler wid = do
    maybeHandler <- inRegistry $ UICmd.handler wid removeNodeHandler
    withJust maybeHandler $ \(RemoveNodeHandler handler) -> handler

triggerFocusNodeHandler :: WidgetId -> Command Global.State ()
triggerFocusNodeHandler wid = do
    maybeHandler <- inRegistry $ UICmd.handler wid focusNodeHandler
    withJust maybeHandler $ \(FocusNodeHandler handler) -> handler wid

triggerRenameNodeHandler :: WidgetId -> Model.Node -> Command Global.State ()
triggerRenameNodeHandler wid model = do
    maybeHandler <- inRegistry $ UICmd.handler wid renameNodeHandler
    withJust maybeHandler $ \(RenameNodeHandler handler) -> handler wid (model ^. Model.nodeId) (model ^. Model.name)

triggerVisualizationsToggledHandler :: WidgetId -> Model.Node -> Command Global.State ()
triggerVisualizationsToggledHandler wid model = do
    maybeHandler <- inRegistry $ UICmd.handler wid visualizationsToggledHandler
    withJust maybeHandler $ \(VisualizationsToggledHandler handler) -> handler wid (model ^. Model.nodeId) (model ^. Model.visualizationsEnabled)

triggerChangeInputNodeTypeHandler :: WidgetId -> Model.Node -> Command Global.State ()
triggerChangeInputNodeTypeHandler wid model = do
    withJust (model ^. Model.tpe) $ \tpe -> do
        maybeHandler <- inRegistry $ UICmd.handler wid changeInputNodeTypeHandler
        withJust maybeHandler $ \(ChangeInputNodeTypeHandler handler) -> handler wid (model ^. Model.nodeId) tpe

triggerExpandNodeHandler :: WidgetId -> Command Global.State ()
triggerExpandNodeHandler wid = do
    maybeHandler <- inRegistry $ UICmd.handler wid expandNodeHandler
    withJust maybeHandler $ \(ExpandNodeHandler handler) -> handler

triggerEditNodeExpressionHandler :: WidgetId -> Model.Node -> Command Global.State ()
triggerEditNodeExpressionHandler wid model = do
    maybeHandler <- inRegistry $ UICmd.handler wid editNodeExpressionHandler
    withJust maybeHandler $ \(EditNodeExpressionHandler handler) -> handler (model ^. Model.nodeId)

triggerCodeChangedHandler :: WidgetId -> Text -> Command Global.State ()
triggerCodeChangedHandler wid newCode = do
    nodeId       <- inRegistry $ UICmd.get wid Model.nodeId
    maybeHandler <- inRegistry $ UICmd.handler wid codeChangedHandler
    withJust maybeHandler $ \(CodeChangedHandler handler) -> handler nodeId newCode

keyDownHandler :: KeyPressedHandler Global.State
keyDownHandler '\r'   _ _ wid = triggerExpandNodeHandler wid
keyDownHandler '\x08' _ _ wid = triggerRemoveHandler wid
keyDownHandler '\x2e' _ _ wid = triggerRemoveHandler wid
keyDownHandler _      _ _ _  = return ()

-- TODO[react]: Unused code. Handled by Reactive.Commands.Graph.Selection
-- selectNode :: Bool -> Ref Node -> Command Global.State ()
-- selectNode combine wid = do
--     let action = handleSelection combine
--     selectNode' action wid
--
-- selectNode' :: (Ref Node -> Command Global.State ()) -> Ref Node -> Command Global.State ()
-- selectNode' action wid = do
--     -- triggerFocusNodeHandler wid --TODO[react]
--     -- UICmd.takeFocus wid
--     action wid
--
-- handleSelection :: Bool -> (Ref Node -> Command Global.State ())
-- handleSelection False = performSelect
-- handleSelection True  = toggleSelect
--
-- performSelect :: Ref Node -> Command Global.State ()
-- performSelect nodeRef = do
--     node <- Store.get nodeRef
--     let isSelected = node ^. Model.isSelected
--         nodeId     = node ^. Model.nodeId
--     unless isSelected $ do
--         unselectAll
--         Store.modify_ (Model.isSelected .~ True) nodeRef
--         modifySelectionHistory [nodeId]
--         collaborativeTouch [nodeId]
--
-- toggleSelect :: Ref Node -> Command Global.State ()
-- toggleSelect nodeRef = do
--     newNode <- flip Store.modifyM nodeRef $ do
--         Model.isSelected %= not
--         get
--     let nodeId = newNode ^. Model.nodeId
--     if newNode ^. Model.isSelected then
--         modifySelectionHistory [nodeId] >> collaborativeTouch [nodeId]
--     else
--         dropSelectionHistory >> cancelCollaborativeTouch [nodeId]
--
--
-- unselectAll :: Command Global.State ()
-- unselectAll = do
--     nodeRefs <- allNodes
--     nodesToCancelTouch <- forM nodeRefs $
--         Store.modifyIf (view Node.isSelected)
--             (\node -> ( node & Node.isSelected .~ False
--                       , Just $ node ^. Node.nodeId))
--             (const Nothing)
--
--     cancelCollaborativeTouch $ catMaybes nodesToCancelTouch

showHidePortLabels :: Bool -> WidgetId -> Command UIRegistry.State ()
showHidePortLabels show wid = do
    inLabels <- inLabelsGroupId wid
    UICmd.update_ inLabels $ Group.visible .~ show
    outLabels <- outLabelsGroupId wid
    UICmd.update_ outLabels $ Group.visible .~ show

onMouseOver, onMouseOut :: WidgetId -> Command Global.State ()
onMouseOver wid = inRegistry $ do
    UICmd.update_ wid $ Model.highlight .~ True
    showHidePortLabels True wid
onMouseOut  wid = inRegistry $ do
    UICmd.update_ wid $ Model.highlight .~ False
    showHidePortLabels False wid

widgetHandlers :: UIHandlers Global.State
widgetHandlers = def & keyDown      .~ keyDownHandler
                     & mouseOver .~ const onMouseOver
                     & mouseOut  .~ const onMouseOut

allNodes :: Command Global.State [Ref Node]
allNodes = Global.withNodeEditor $
    Store.use (NodeEditor.nodes . to HashMap.elems)

allNodes' :: Command Global.State [WRef Node]
allNodes' = mapM Store.get' =<< allNodes

-- TODO[react]: Unused code. Handled by Reactive.Commands.Graph.Selection
-- unselectNode :: WidgetId -> Command UIRegistry.State ()
-- unselectNode = flip UICmd.update_ (Model.isSelected .~ False)

onClicked h = addHandler (MousePressedHandler h) mempty

displayCodeEditor :: WidgetId -> WidgetId -> Text -> Command UIRegistry.State WidgetId
displayCodeEditor nodeWidgetId nodeGroupId code = do
    let widget = CodeEditor.create Style.codeEditorSize code
    UICmd.register nodeGroupId widget $ codeHandlers nodeWidgetId

instance ResizableWidget Model.Node
instance CompositeWidget Model.Node where
    createWidget wid model = do
        let grp    = Group.create & Group.size .~ Vector2 1 1
        portGroup <- UICmd.register wid grp def

        let label = Style.expressionLabel $ trimExpression $ model ^. Model.expression
        expressionLabelId <- UICmd.register wid label $ addHandler (DblClickedHandler $ const $ triggerEditNodeExpressionHandler wid model) def

        let group  = Group.create & Group.position .~ Style.controlsPosition
        controlGroups <- UICmd.register wid group Style.controlsLayout

        let inLabelsGroup  = Group.create & Group.position .~ Vector2 (-400) (-30)
                                          & Group.visible .~ False
        inLabelsGroupId <- UICmd.register wid inLabelsGroup Style.inLabelsLayout

        let outLabelsGroup  = Group.create & Group.position .~ Vector2 40 (-30)
                                           & Group.visible .~ False
        outLabelsGroupId <- UICmd.register wid outLabelsGroup Style.inLabelsLayout

        let grp    = Group.create & Group.style   .~ Style.expandedGroupStyle
                                  & Group.visible .~ (model ^. Model.isExpanded)
        expandedGroup <- UICmd.register controlGroups grp Style.expandedGroupLayout

        let label  = Style.execTimeLabel "Execution time: --"
        execTimeLabelId <- UICmd.register expandedGroup label def

        nodeGroupId <- UICmd.register expandedGroup Group.create Style.expandedGroupLayout

        let widget = LabeledTextBox.create Style.portControlSize "Name" $ model ^. Model.name
        nameTextBoxId <- UICmd.register nodeGroupId widget $ nameHandlers wid

        codeEditorId <- mapM (displayCodeEditor wid nodeGroupId) $ model ^. Model.code

        let widget = Toggle.create Style.portControlSize "Display result" $ model ^. Model.visualizationsEnabled
        visualizationToggleId <- UICmd.register nodeGroupId widget $ visualizationToggleHandlers wid

        withJust (model ^. Model.tpe) $ \_tpe -> do
            let widget = LabeledTextBox.create Style.portControlSize "Type" (fromMaybe "" $ model ^. Model.tpe)
            nodeTpeId <- UICmd.register nodeGroupId widget $ typeHandlers wid
            void $ UIRegistry.updateWidgetM wid $ Model.elements . Model.nodeType     ?~ nodeTpeId

        let grp    = Group.create
        portControlsGroupId <- UICmd.register expandedGroup grp Style.expandedGroupLayout

        let label  = Style.valueLabel ""
        valueLabelId <- UICmd.register controlGroups label def

        let group  = Group.create & Group.style   .~ Style.visualizationGroupStyle
                                  & Group.visible .~ (model ^. Model.isExpanded)
                                  & Group.size    . y .~ 0
        visualizationGroupId <- UICmd.register controlGroups group (Layout.verticalLayoutHandler 0.0)

        void $ UIRegistry.updateWidgetM wid $ Model.elements %~ ( (Model.expressionLabel     .~ expressionLabelId          )
                                                               . (Model.expandedGroup       .~ expandedGroup              )
                                                               . (Model.nodeGroup           .~ nodeGroupId                )
                                                               . (Model.portGroup           .~ portGroup                  )
                                                               . (Model.portControls        .~ portControlsGroupId        )
                                                               . (Model.inLabelsGroup       .~ inLabelsGroupId            )
                                                               . (Model.outLabelsGroup      .~ outLabelsGroupId           )
                                                               . (Model.nameTextBox         .~ nameTextBoxId              )
                                                               . (Model.valueLabel          .~ valueLabelId               )
                                                               . (Model.visualizationGroup  .~ visualizationGroupId       )
                                                               . (Model.execTimeLabel       .~ execTimeLabelId            )
                                                               . (Model.visualizationToggle .~ Just visualizationToggleId )
                                                               . (Model.codeEditor          .~ codeEditorId               )
                                                               )

    updateWidget wid old model = do
        whenChanged old model Model.isExpanded $ do
            let controlsId = model ^. Model.elements . Model.expandedGroup
                valueVisId = model ^. Model.elements . Model.visualizationGroup
            UICmd.update_ controlsId $ Group.visible .~ (model ^. Model.isExpanded)
            UICmd.update_ valueVisId $ Group.visible .~ (model ^. Model.isExpanded)

        whenChanged old model Model.expression $ do
            let exprId = model ^. Model.elements . Model.expressionLabel
            UICmd.update_ exprId     $ Label.label   .~ trimExpression (model ^. Model.expression)

        whenChanged old model Model.name  $ do
            let nameTbId = model ^. Model.elements . Model.nameTextBox
            UICmd.update_ nameTbId   $ LabeledTextBox.value .~ (model ^. Model.name)

        whenChanged old model Model.visualizationsEnabled  $ do
            let visTgId = model ^. Model.elements . Model.visualizationToggle
            withJust visTgId $ \visTgId -> UICmd.update_ visTgId $ Toggle.value .~ (model ^. Model.visualizationsEnabled)

        whenChanged old model Model.value $ do
            let valueId = model ^. Model.elements . Model.valueLabel
            UICmd.update_ valueId    $ Label.label   .~ (model ^. Model.value)

        whenChanged old model Model.tpe   $ withJust (model ^. Model.tpe) $ \tpe -> do
            let typeTbId = model ^. Model.elements . Model.nodeType
            withJust typeTbId $ \typeTbId -> UICmd.update_ typeTbId $ LabeledTextBox.value .~ tpe

        whenChanged old model Model.execTime $ do
            let etId = model ^. Model.elements . Model.execTimeLabel
            UICmd.update_ etId $ Label.label     .~ (fromMaybe "Execution time: --" $ (\v -> "Execution time: " <> v <> " ms") <$> (Text.pack . show) <$> model ^. Model.execTime)

        whenChanged old model Model.isExpanded $ do
            let valueId = model ^. Model.elements . Model.valueLabel
            UICmd.update_ valueId  $ Label.alignment .~ (if model ^. Model.isExpanded then Label.Left else Label.Center)
            UICmd.moveX   valueId  $ if model ^. Model.isExpanded then 0.0 else -25.0

        withJust (model ^. Model.code) $ \codeBody -> do
            let nodeGroupId = model ^. Model.elements . Model.nodeGroup

            when (isNothing $ model ^. Model.elements . Model.codeEditor) $ do
                codeEditorId <- displayCodeEditor wid nodeGroupId codeBody
                void $ UIRegistry.updateWidgetM wid $ Model.elements . Model.codeEditor .~ Just codeEditorId

            withJust (model ^. Model.elements . Model.codeEditor) $ \codeEditorId ->
                UICmd.update_ codeEditorId $ CodeEditor.value .~ codeBody

        when (isNothing $ model ^. Model.code) $
            withJust (model ^. Model.elements . Model.codeEditor) $ \codeEditorId -> do
                UICmd.removeWidget codeEditorId
                void $ UIRegistry.updateWidgetM wid $ Model.elements . Model.codeEditor .~ Nothing


portControlsGroupId :: WidgetId -> Command UIRegistry.State WidgetId
portControlsGroupId wid = UICmd.get wid $ Model.elements . Model.portControls

inLabelsGroupId :: WidgetId -> Command UIRegistry.State WidgetId
inLabelsGroupId wid = UICmd.get wid $ Model.elements . Model.inLabelsGroup

outLabelsGroupId :: WidgetId -> Command UIRegistry.State WidgetId
outLabelsGroupId wid = UICmd.get wid $ Model.elements . Model.outLabelsGroup

expressionId :: WidgetId -> Command UIRegistry.State WidgetId
expressionId wid = UICmd.get wid $ Model.elements . Model.expressionLabel

valueGroupId :: WidgetId -> Command UIRegistry.State WidgetId
valueGroupId wid = UICmd.get wid $ Model.elements . Model.visualizationGroup

trimExpression :: Text -> Text
trimExpression expr
    | Text.length expr < 20 = expr
    | otherwise             = Text.take 20 expr <> "…"
