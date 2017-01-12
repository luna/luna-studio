{-# LANGUAGE OverloadedStrings #-}
module Luna.Studio.React.View.Node where

import qualified Data.Aeson                             as Aeson
import qualified Data.Map.Lazy                          as Map
import qualified Data.Text                              as Text
import           Empire.API.Data.Node                   (NodeId)
import           Empire.API.Data.Port                   (InPort (..), PortId (..))
import qualified Event.UI                               as UI
import           Luna.Studio.Action.Geometry            (countSameTypePorts, isPortSingle)
import           Luna.Studio.Data.Matrix                (transformTranslateToSvg)
import           Luna.Studio.Data.Vector                (x, y)
import           Luna.Studio.Prelude
import qualified Luna.Studio.React.Event.Node           as Node
import           Luna.Studio.React.Model.Node           (Node)
import qualified Luna.Studio.React.Model.Node           as Node
import qualified Luna.Studio.React.Model.NodeProperties as Properties
import           Luna.Studio.React.Model.Port           (Port (..))
import qualified Luna.Studio.React.Model.Port           as Port
import           Luna.Studio.React.Store                (Ref, dispatch, dt)
import           Luna.Studio.React.View.NodeProperties  (nodeProperties_)
import           Luna.Studio.React.View.Port            (portExpanded_, port_)
import           Luna.Studio.React.View.Visualization   (visualization_)
import           React.Flux
import qualified React.Flux                             as React


objName :: JSString
objName = "node"


makePorts :: Ref Node -> [Port] -> ReactElementM ViewEventHandler ()
makePorts nodeRef ports = forM_ ports $ \port -> port_ nodeRef port (countSameTypePorts port ports) (isPortSingle port ports)


makePortsExpanded :: Ref Node -> [Port] -> ReactElementM ViewEventHandler ()
makePortsExpanded nodeRef ports = forM_ ports $ \port -> portExpanded_ nodeRef port


node :: Ref Node -> ReactView ()
node ref = React.defineControllerView
    objName ref $ \store () ->
        let n         = store ^. dt
            nodeId    = n ^. Node.nodeId
            pos       = n ^. Node.position
            ports     = Map.elems $ n ^. Node.ports
            offsetX   = show (pos ^. x)
            offsetY   = show (pos ^. y)
            nodeLimit = 10000::Int
            zIndex    = 1::Int -- FIXME, Leszek!
            z         = if n ^. Node.isExpanded then zIndex + nodeLimit else zIndex
        in  div_
                [ "key"       $= fromString (show nodeId)
                , onClick       $ \_ m -> dispatch ref $ UI.NodeEvent $ Node.Select m nodeId
                , onDoubleClick $ \_ _ -> dispatch ref $ UI.NodeEvent $ Node.Enter nodeId
                , onMouseDown   $ \e m -> stopPropagation e : dispatch ref (UI.NodeEvent $ Node.MouseDown m nodeId)
                , "className" $= (fromString $ "node" <> (if n ^. Node.isExpanded then " node--expanded" else " node--collapsed")
                                                      <> (if n ^. Node.isSelected then " node--selected" else []))
                , "style"     @= Aeson.object [ "transform" Aeson..= (transformTranslateToSvg offsetX offsetY)
                                              , "zIndex"   Aeson..= (show z)
                                              ]
                ] $ do

                svg_ [ "key"     $= "viewbox"
                     , "viewBox" $= "0 0 10 10" ] $
                    rect_ [ "key"       $= "selection-mark"
                          , "className" $= "node__selection-mark" ] mempty

                nodeProperties_ ref $ Properties.fromNode n

                div_ [ "key"       $= "visualization"
                     , "className" $= "node__visualization"] $ do
                    forM_ (n ^. Node.value) visualization_

                svg_ [ "key" $= "viewbox2"
                     , "viewBox" $= "0 0 10 10"] $ do
                    text_
                        [ "key"         $= "name"
                        , onDoubleClick $ \e _ -> stopPropagation e : dispatch ref (UI.NodeEvent $ Node.EditExpression nodeId)
                        , "className"   $= "node__name"
                        , "y"           $= "-40"
                        ] $ elemString $ Text.unpack $ n ^. Node.expression
                    if n ^. Node.isExpanded then do
                        makePorts ref $ filter (\port -> (port ^. Port.portId) == InPortId Self) ports
                        makePortsExpanded ref $ filter (\port -> (port ^. Port.portId) /= InPortId Self) ports
                        makePortsExpanded ref $ filter (\port -> (port ^. Port.portId) /= InPortId Self) ports
                    else do
                        makePorts ref $ filter (\port -> (port ^. Port.portId) /= InPortId Self) ports
                        makePorts ref $ filter (\port -> (port ^. Port.portId) == InPortId Self) ports



node_ :: NodeId -> Ref Node -> ReactElementM ViewEventHandler ()
node_ nodeId ref = React.viewWithSKey (node ref) (fromString $ show nodeId) () mempty
