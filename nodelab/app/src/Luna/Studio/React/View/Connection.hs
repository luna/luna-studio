{-# LANGUAGE OverloadedStrings #-}
module Luna.Studio.React.View.Connection where

import qualified Data.Map.Lazy                      as Map
import           React.Flux
import qualified React.Flux                         as React
import           Empire.API.Data.PortRef            (AnyPortRef (InPortRef', OutPortRef'), InPortRef, OutPortRef, toAnyPortRef)
import qualified Empire.API.Data.PortRef            as PortRef
import qualified Event.UI                           as UI
import           Luna.Studio.Commands.Command       (Command)
import           Luna.Studio.Commands.Graph         (getNode, getPort)
import           Luna.Studio.Data.Angle             (Angle)
import           Luna.Studio.Data.Color             (Color, toJSString)
import           Luna.Studio.Data.Vector            --(Position, Vector2 (Vector2), x, y)
import qualified Luna.Studio.Prelude                as Prelude
import           Luna.Studio.Prelude
import           Luna.Studio.React.Event.Connection (ModifiedEnd (Destination, Source))
import qualified Luna.Studio.React.Event.Connection as Connection
import           Luna.Studio.React.Model.Connection (Connection, CurrentConnection)
import qualified Luna.Studio.React.Model.Connection as Connection
import qualified Luna.Studio.React.Model.Node       as Node
import qualified Luna.Studio.React.Model.Port       as Port
import           Luna.Studio.React.Store            (Ref, dispatch, dt)
import qualified Luna.Studio.React.Store            as Store
import           Luna.Studio.React.View.Global
import           Luna.Studio.State.Global           (State)


name :: JSString
name = "connection-editor"


connectionSrc :: Position -> Position -> Bool -> Bool -> Int -> Int -> IsSingle -> Position
connectionSrc src dst isSrcExpanded isDstExpanded _ _ True =
    let t  = nodeToNodeAngle src dst
        x' = portRadius * cos t + src ^. x
        y' = portRadius * sin t + src ^. y
    in  Position (Vector2 x' y')
connectionSrc src dst isSrcExpanded isDstExpanded num numOfPorts _    =
    let a  = portAngleStop  num numOfPorts portRadius
        b  = portAngleStart num numOfPorts portRadius
        t  = nodeToNodeAngle src dst
        a' = if a < pi then a + (2 * pi) else a
        b' = if b < pi then b + (2 * pi) else b
        t' = if t < pi then t + (2 * pi) else t
        g  = portGap portRadius / 4

        t''= if t' > a'- pi/2 - g then a - pi/2 - g else
             if t' < b'- pi/2 + g then b - pi/2 + g else t --TODO: determine why the pi/2 offset is necessary
        x' = portRadius * cos t'' + src ^. x
        y' = portRadius * sin t'' + src ^. y
    in  Position (Vector2 x' y')


connectionDst :: Position -> Position -> Bool -> Bool -> Int -> Int -> IsSelf -> Position
connectionDst src dst isSrcExpanded isDstExpanded _   _          True = dst
connectionDst src dst isSrcExpanded isDstExpanded num numOfPorts _    =
    let a  = portAngleStop  num numOfPorts portRadius
        b  = portAngleStart num numOfPorts portRadius
        t  = nodeToNodeAngle src dst

        a' = if a < pi then a + (2 * pi) else a
        b' = if b < pi then b + (2 * pi) else b
        t' = if t < pi then t + (2 * pi) else t

        g = portGap portRadius / 4

        t''= if t' > a'- pi/2 - g then a - pi/2 - g else
             if t' < b'- pi/2 + g then b - pi/2 + g else t --TODO: determine why the pi/2 offset is necessary
        x' = portRadius * (-cos t'') + dst ^. x
        y' = portRadius * (-sin t'') + dst ^. y
    in  Position (Vector2 x' y')


getConnectionPosition :: OutPortRef -> InPortRef -> Command State (Maybe (Position, Position))
getConnectionPosition srcPortRef dstPortRef = do
    maySrcNode <- getNode $ srcPortRef ^. PortRef.srcNodeId
    mayDstNode <- getNode $ dstPortRef ^. PortRef.dstNodeId
    -- TODO[react]: Function getPort should work for InPortRef and OutPortRef as well
    maySrcPort <- getPort $ OutPortRef' srcPortRef
    mayDstPort <- getPort $ InPortRef'  dstPortRef

    case (maySrcNode, maySrcPort, mayDstNode, mayDstPort) of
        (Just srcNode, Just srcPort, Just dstNode, Just dstPort) -> do
            let srcPorts      = Map.elems $ srcNode ^. Node.ports
                dstPorts      = Map.elems $ dstNode ^. Node.ports
                srcPos        = srcNode ^. Node.position
                dstPos        = dstNode ^. Node.position
                isSrcExpanded = srcNode ^. Node.isExpanded
                isDstExpanded = dstNode ^. Node.isExpanded
                srcConnPos    = connectionSrc srcPos dstPos isSrcExpanded isDstExpanded (getPortNumber srcPort) (countSameTypePorts srcPort srcPorts) (isPortSingle srcPort srcPorts)
                dstConnPos    = connectionDst srcPos dstPos isSrcExpanded isDstExpanded (getPortNumber dstPort) (countSameTypePorts dstPort dstPorts) (isPortSelf dstPort)
            return $ Just (srcConnPos, dstConnPos)
        _ -> return Nothing


getCurrentConnectionSrcPosition :: AnyPortRef -> Position -> Command State (Maybe Position)
getCurrentConnectionSrcPosition srcPortRef dstPos = do
    maySrcNode <- getNode $ srcPortRef ^. PortRef.nodeId
    maySrcPort <- getPort srcPortRef

    case (maySrcNode, maySrcPort) of
        (Just srcNode, Just srcPort) -> do
            let srcPorts      = Map.elems $ srcNode ^. Node.ports
                srcPos        = srcNode ^. Node.position
                isSrcExpanded = srcNode ^. Node.isExpanded
                srcConnPos    = connectionSrc srcPos dstPos isSrcExpanded False (getPortNumber srcPort) (countSameTypePorts srcPort srcPorts) (isPortSingle srcPort srcPorts)
            return $ Just srcConnPos
        _ -> return Nothing


getConnectionColor :: OutPortRef -> Command State (Maybe Color)
-- TODO[react]: Function getPort should work for InPortRef and OutPortRef as well
getConnectionColor portRef = (fmap $ Prelude.view Port.color) <$> (getPort $ OutPortRef' portRef)


getCurrentConnectionColor :: AnyPortRef -> Command State (Maybe Color)
getCurrentConnectionColor portRef = (fmap $ Prelude.view Port.color) <$> (getPort portRef)


connection :: Ref Connection -> ReactView ()
connection connectionRef = React.defineControllerView
    name connectionRef $ \connectionStore () -> do
        let connection = connectionStore ^. dt
            connId     = connection ^. Connection.connectionId
            src        = connection ^. Connection.from
            dst        = connection ^. Connection.to
            color      = connection ^. Connection.color
            srcX       = src ^. x
            srcY       = src ^. y
            dstX       = dst ^. x
            dstY       = dst ^. y
            midX       = (srcX + dstX) / 2
            midY       = (srcY + dstY) / 2

            width      = fromString $ show connectionWidth
        g_ [ "className" $= "connection" ] $ do
            line_
                [ onMouseDown $ \e m -> stopPropagation e : dispatch connectionRef (UI.ConnectionEvent $ Connection.ModifyConnection m connId Source)
                , "className"   $= "connection__src"
                , "x1"          $= (fromString $ showSvg srcX)
                , "y1"          $= (fromString $ showSvg srcY)
                , "x2"          $= (fromString $ showSvg midX)
                , "y2"          $= (fromString $ showSvg midY)
                , "stroke"      $= toJSString color
                , "strokeWidth" $= width
                ] mempty
            line_
                [ onMouseDown $ \e m -> stopPropagation e : dispatch connectionRef (UI.ConnectionEvent $ Connection.ModifyConnection m connId Destination)
                , "className"   $= "connection__dst"
                , "x1"          $= (fromString $ showSvg midX)
                , "y1"          $= (fromString $ showSvg midY)
                , "x2"          $= (fromString $ showSvg dstX)
                , "y2"          $= (fromString $ showSvg dstY)
                , "stroke"      $= toJSString color
                , "strokeWidth" $= width
                ] mempty


connection_ :: InPortRef -> Ref Connection -> ReactElementM ViewEventHandler ()
connection_ inPortRef connectionRef = React.viewWithSKey (connection connectionRef) (fromString $ show inPortRef) () mempty


currentConnection :: Ref CurrentConnection -> ReactView ()
currentConnection connectionRef = React.defineControllerView
    name connectionRef $ \connectionStore () -> do
        let connection = connectionStore ^. dt
            src        = connection ^. Connection.currentFrom
            dst        = connection ^. Connection.currentTo
            color      = connection ^. Connection.currentColor
            x1         = fromString $ showSvg $ src ^. x
            y1         = fromString $ showSvg $ src ^. y
            x2         = fromString $ showSvg $ dst ^. x
            y2         = fromString $ showSvg $ dst ^. y
            width      = fromString $ show connectionWidth
        line_
            [ "x1"          $= x1
            , "y1"          $= y1
            , "x2"          $= x2
            , "y2"          $= y2
            , "stroke"      $= toJSString color
            , "strokeWidth" $= width
            ] mempty

currentConnection_ :: Ref CurrentConnection -> ReactElementM ViewEventHandler ()
currentConnection_ connectionRef = React.viewWithSKey (currentConnection connectionRef) "current-connection" () mempty
