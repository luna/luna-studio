{-# LANGUAGE OverloadedStrings #-}
module Luna.Studio.React.View.Port where

import           Luna.Studio.Prelude

import           Empire.API.Data.Port         (InPort (..), OutPort (..), PortId (..))

import qualified Numeric                      as Numeric

import           Object.Widget.Port           (Port (..))

import           React.Flux
import qualified React.Flux                   as React

import           Luna.Studio.Data.Color       (Color(Color))
import           Luna.Studio.Data.HSL         (color')
import           Luna.Studio.React.Model.Node (Node)
import           Luna.Studio.React.Store      (Ref)



showF :: Float -> String
showF a = Numeric.showFFloat (Just 1) a ""

name :: JSString
name = "port"

port :: Ref Node -> Int -> ReactView Port
port _ numOfPorts = React.defineView name $ \p -> do
    drawPort_ p numOfPorts False


port_ :: Ref Node -> Port -> Int -> ReactElementM ViewEventHandler ()
port_ ref p numOfPorts = React.view (port ref numOfPorts) p mempty


drawPort_ :: Port -> Int -> Bool -> ReactElementM ViewEventHandler ()
drawPort_ (Port _ (InPortId   Self         ) _ _) _          _     = drawPortSelf_
drawPort_ (Port _ (OutPortId  All          ) _ _) 1          True  = drawPortSingle_
drawPort_ (Port _ (OutPortId  All          ) _ _) numOfPorts _     = drawPortIO_ 0 numOfPorts (-1) "1" "0"
drawPort_ (Port _ (OutPortId (Projection i)) _ _) numOfPorts _     = drawPortIO_ i numOfPorts (-1) "1" "0"
drawPort_ (Port _ (InPortId  (Arg        i)) _ _) numOfPorts _     = drawPortIO_ i numOfPorts   1  "0" "1"

drawPortSelf_ :: ReactElementM ViewEventHandler ()
drawPortSelf_ = let color = color' $ Color 5 in
    circle_
        [ "className" $= "port port--self"
        , "fill"      $= color
        , "stroke"    $= color
        ] mempty

drawPortSingle_ :: ReactElementM ViewEventHandler ()
drawPortSingle_ = let color = color' $ Color 5 in
    circle_
        [ "className" $= "port port--o port--o--single"
        , "stroke"    $= color
        ] mempty

drawPortIO_ :: Int -> Int -> Float -> String -> String -> ReactElementM ViewEventHandler ()
drawPortIO_ number numOfPorts mod1 mod2 mod3 = do

    let color = color' $ Color 5 --TODO [Piotr Młodawski]: get color from model
        r1    = 20 :: Float
        line  = 3 :: Float
        gap   = 0.15 :: Float
        r2   = r1 - line
        gap' = gap * (r1/r2)
        number' = number + 1

        t   = pi / fromIntegral numOfPorts
        t1  = fromIntegral number' * t - pi - t + gap/2
        t2  = fromIntegral number' * t - pi - gap/2
        t1' = fromIntegral number' * t - pi - t + gap'/2
        t2' = fromIntegral number' * t - pi - gap'/2

        ax = showF $ r1 * sin(t1  * mod1) + r1
        ay = showF $ r1 * cos(t1  * mod1) + r1

        bx = showF $ r1 * sin(t2  * mod1) + r1
        by = showF $ r1 * cos(t2  * mod1) + r1

        cx = showF $ r2 * sin(t2' * mod1) + r1
        cy = showF $ r2 * cos(t2' * mod1) + r1

        dx = showF $ r2 * sin(t1' * mod1) + r1
        dy = showF $ r2 * cos(t1' * mod1) + r1

        svgPath = fromString $ "M" <> ax <> " " <> ay <> " A " <> show r1 <> " " <> show r1 <> " 1 0 " <> mod2 <> " " <> bx <> " " <> by <>
                              " L" <> cx <> " " <> cy <> " A " <> show r2 <> " " <> show r2 <> " 1 0 " <> mod3 <> " " <> dx <> " " <> dy <>
                              " L" <> ax <> " " <> ay

    path_
        [ "className" $= (fromString $ "port port--i port--i--" <> show number')
        , "fill"      $= color
        , "stroke"    $= color
        , "d"         $= svgPath
        ] mempty

--TODO[react] probably remove
-- displayPorts :: WidgetId -> Node -> Command Global.State ()
-- displayPorts wid node = do
--         portGroup <- inRegistry $ UICmd.get wid $ Model.elements . Model.portGroup
--         oldPorts  <- inRegistry $ UICmd.children portGroup
--         oldPortWidgets <- forM oldPorts $ \wid' -> inRegistry $ (UICmd.lookup wid')
--         let portRefs = (view PortModel.portRef) <$> oldPortWidgets
--         forM_ portRefs $ \wid' -> Global.graph . Graph.portWidgetsMap . at wid' .= Nothing
--         inRegistry $ mapM_ UICmd.removeWidget oldPorts
--
--         groupId      <- inRegistry $ Node.portControlsGroupId wid
--         portControls <- inRegistry $ UICmd.children groupId
--         inRegistry $ mapM_ UICmd.removeWidget portControls
--
--         inLabelsGroupId <- inRegistry $ Node.inLabelsGroupId wid
--         inLabels        <- inRegistry $ UICmd.children inLabelsGroupId
--         inRegistry $ mapM_ UICmd.removeWidget inLabels
--
--         outLabelsGroupId <- inRegistry $ Node.outLabelsGroupId wid
--         outLabels        <- inRegistry $ UICmd.children outLabelsGroupId
--         inRegistry $ mapM_ UICmd.removeWidget outLabels
--
--         forM_ (makePorts node    ) $ \p -> do
--             portWidgetId <- inRegistry $ UICmd.register portGroup p def
--             Global.graph . Graph.portWidgetsMap . at (p ^. PortModel.portRef) ?= portWidgetId
--         inRegistry $ forM_ (node ^. Node.ports) $ makePortControl groupId node
--         inRegistry $ forM_ (node ^. Node.ports) $ \p -> case p ^. Port.portId of
--             InPortId  Self -> return ()
--             InPortId  _    -> makePortLabel inLabelsGroupId  p
--             OutPortId _    -> makePortLabel outLabelsGroupId p

--TODO[react] probably remove
-- makePortLabel :: WidgetId -> Port -> Command UIRegistry.State ()
-- makePortLabel parent port = do
--     let align = case port ^. Port.portId of
--             InPortId  _ -> Label.Right
--             OutPortId _ -> Label.Left
--         label = Label.create (Vector2 360 15) text & Label.alignment .~ align
--         text  = (Text.pack $ port ^. Port.name) <> " :: " <> portType
--         portType = port ^. Port.valueType . ValueType.toText
--     UICmd.register_ parent label def
--
-- TODO[react]: handle this:
-- onMouseOver, onMouseOut :: WidgetId -> Command Global.State ()
-- onMouseOver wid = inRegistry $ do
--     UICmd.update_ wid $ Model.highlight .~ True
--     nodeId <- toNodeId wid
--     Node.showHidePortLabels True nodeId
-- onMouseOut  wid = inRegistry $ do
--     UICmd.update_ wid $ Model.highlight .~ False
--     nodeId <- toNodeId wid
--     Node.showHidePortLabels False nodeId
