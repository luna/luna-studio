{-# LANGUAGE OverloadedStrings #-}
module React.View.Node where

import           React.Flux
import qualified React.Flux        as React

import qualified Event.UI          as UI
import           React.Store       (Ref, dt)
import qualified React.Store       as Store
import           React.Store.Node  (Node)
import qualified React.Store.Node  as Node
import           Utils.PreludePlus
import           Utils.Vector      (x, y)


name :: JSString
name = "node-editor"

--FIXME: move all styles to CSS
node :: Ref Node -> ReactView ()
node nodeRef = React.defineControllerView
    name nodeRef $ \nodeStore () -> do
        let n = nodeStore ^. dt
            pos = n ^. Node.position
            translate = fromString $ "translate(" <> show (pos ^. x) <> "," <> show (pos ^. y) <> ")"
        g_
            [ onClick       $ \_ _ -> Store.dispatch nodeRef $ UI.NodeEvent Node.OnClick
            , onDoubleClick $ \_ _ -> Store.dispatch nodeRef $ UI.NodeEvent $ Node.Enter $ n ^. Node.nodeId
            , onDrag        $ \_ e -> Store.dispatch nodeRef $ UI.NodeEvent $ Node.Drag e $ n ^. Node.nodeId
            , "className" $= "node"
            , "viewbox"   $= "0 0 40 40"
            , "transform" $= translate
            ] $ do
                circle_
                    [ "className"   $= "self"
                    , "cx"          $= "20"
                    , "cy"          $= "20"
                    , "r"           $= "5"
                    , "fill"        $= "#8ABEB7"
                    ] $ mempty
                circle_
                    [ "className"   $= "input"
                    , "cx"          $= "20"
                    , "cy"          $= "20"
                    , "r"           $= "18.5"
                    , "strokeWidth" $= "3px"
                    , "stroke"      $= "#8ABEB7"
                    , "fill"        $= "none"
                    , "clipPath"    $= "url(#clipInput)"
                    ] $ mempty
                circle_
                    [ "className"   $= "output"
                    , "cx"          $= "20"
                    , "cy"          $= "20"
                    , "r"           $= "18.5"
                    , "strokeWidth" $= "3px"
                    , "stroke"      $= "#B294BB"
                    , "fill"        $= "none"
                    , "clipPath"    $= "url(#clipOutput)"
                    ] $ mempty


node_ :: Ref Node -> ReactElementM ViewEventHandler ()
node_ nodeRef = React.view (node nodeRef) () mempty
