{-# LANGUAGE OverloadedStrings #-}
module Luna.Studio.React.View.NodeEditor where

import qualified Data.HashMap.Strict                 as HashMap
import           Luna.Studio.Data.Vector
import           Luna.Studio.Prelude
import           React.Flux
import qualified React.Flux                          as React

import qualified Event.UI                            as UI
import qualified Luna.Studio.React.Event.NodeEditor  as NE
import           Luna.Studio.React.Model.NodeEditor  (NodeEditor)
import qualified Luna.Studio.React.Model.NodeEditor  as NodeEditor
import           Luna.Studio.React.Store             (Ref, dispatch, dt)
import           Luna.Studio.React.View.Connection   (connection_, currentConnection_)
import           Luna.Studio.React.View.Node         (node_)
import           Luna.Studio.React.View.SelectionBox (selectionBox_)


name :: JSString
name = "node-editor"


nodeEditor :: Ref NodeEditor -> ReactView ()
nodeEditor ref = React.defineControllerView name ref $ \store () -> do
    let ne = store ^. dt
        panX   = show $ ne ^. NodeEditor.pan . x
        panY   = show $ ne ^. NodeEditor.pan . y
        factor = show $ ne ^. NodeEditor.factor
        transform' = "matrix(" <> factor <> " , 0, 0, " <> factor <> " , " <> panX <> " , " <> panY <> " )"
    svg_
        [ "className"   $= "graph"
        , "xmlns"       $= "http://www.w3.org/2000/svg"
        , "xmlnsXlink"  $= "http://www.w3.org/1999/xlink"
        , onMouseDown   $ \_ e -> dispatch ref $ UI.NodeEditorEvent $ NE.MouseDown e
        ]
        $ do
        g_
            [ "className" $= "scene"
            , "transform" $= fromString transform'
            ] $ do
                forM_ (store ^. dt . NodeEditor.nodes . to HashMap.elems) $ \nodeRef -> do
                    node_ nodeRef
                forM_ (store ^. dt . NodeEditor.connections . to HashMap.elems) $ \connectionRef -> do
                    connection_ connectionRef
                forM_ (store ^. dt . NodeEditor.currentConnection) $ \connectionRef -> do
                    currentConnection_ connectionRef

                selectionBox_ (store ^. dt . NodeEditor.selectionBox)

nodeEditor_ :: Ref NodeEditor -> ReactElementM ViewEventHandler ()
nodeEditor_ ref = React.view (nodeEditor ref) () mempty
