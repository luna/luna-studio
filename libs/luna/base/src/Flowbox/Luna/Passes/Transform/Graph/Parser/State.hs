 ---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE ConstraintKinds  #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TemplateHaskell  #-}

module Flowbox.Luna.Passes.Transform.Graph.Parser.State where

import           Control.Monad.State
import           Data.Map            (Map)
import qualified Data.Map            as Map

import           Flowbox.Control.Error
import           Flowbox.Luna.Data.AST.Expr                      (Expr)
import qualified Flowbox.Luna.Data.AST.Expr                      as Expr
import qualified Flowbox.Luna.Data.Graph.Edge                    as Edge
import           Flowbox.Luna.Data.Graph.Graph                   (Graph)
import qualified Flowbox.Luna.Data.Graph.Graph                   as Graph
import           Flowbox.Luna.Data.Graph.Node                    (Node)
import qualified Flowbox.Luna.Data.Graph.Node                    as Node
import           Flowbox.Luna.Data.Graph.Port                    (OutPort)
import           Flowbox.Luna.Data.PropertyMap                   (PropertyMap)
import qualified Flowbox.Luna.Passes.Transform.AST.IDFixer.State as IDFixer
import           Flowbox.Prelude                                 hiding (mapM)
import           Flowbox.System.Log.Logger



logger :: Logger
logger = getLogger "Flowbox.Luna.Passes.Transform.Graph.Parser.State"


type NodeMap = Map (Node.ID, OutPort) Expr


data GPState = GPState { _body        :: [Expr]
                       , _output      :: Maybe Expr
                       , _nodeMap     :: NodeMap
                       , _graph       :: Graph
                       , _propertyMap :: PropertyMap
                       } deriving (Show)

makeLenses(''GPState)

type GPStateM m = MonadState GPState m


make :: Graph -> PropertyMap -> GPState
make = GPState [] Nothing Map.empty


getBody :: GPStateM m => m [Expr]
getBody = gets (view body)


setBody :: GPStateM m => [Expr] -> m ()
setBody b = modify (set body b)


getOutput :: GPStateM m => m (Maybe Expr)
getOutput = gets (view output)


setOutput :: GPStateM m => Expr -> m ()
setOutput o = modify (set output $ Just o)


getNodeMap :: GPStateM m => m NodeMap
getNodeMap = gets (view nodeMap)


setNodeMap :: GPStateM m => NodeMap -> m ()
setNodeMap nm =  modify (set nodeMap nm)


getGraph :: GPStateM m => m Graph
getGraph = gets (view graph)


getPropertyMap :: GPStateM m => m PropertyMap
getPropertyMap = gets (view propertyMap)


addToBody :: GPStateM m => Expr -> m ()
addToBody e = do b <- getBody
                 setBody $ e : b


addToNodeMap :: GPStateM m => (Node.ID, OutPort) -> Expr -> m ()
addToNodeMap key expr = getNodeMap >>= setNodeMap . Map.insert key expr


nodeMapLookUp :: GPStateM m => (Node.ID, OutPort) -> m Expr
nodeMapLookUp key = do nm <- getNodeMap
                       Map.lookup key nm <?.> ("GraphParser: nodeMapLookUp: Cannot find " ++ (show key) ++ " in nodeMap")



getNodeSrcs :: GPStateM m => Node.ID -> m [Expr]
getNodeSrcs nodeID = do
    g <- getGraph
    let connectedMap = Map.fromList
                     $ map (\(pNID, _, Edge.Data s d) -> (d, (pNID, s)))
                     $ Graph.lprel g nodeID
    case Map.size connectedMap of
        0 -> return []
        _ -> do let maxPort   = fst $ Map.findMax connectedMap
                    connected = map (flip Map.lookup connectedMap) [0..maxPort]
                mapM getNodeSrc connected


getNodeSrc :: GPStateM m => Maybe (Node.ID, OutPort) -> m Expr
getNodeSrc Nothing  = return $ Expr.Wildcard IDFixer.unknownID
getNodeSrc (Just a) = nodeMapLookUp a


getNode :: GPStateM m => Node.ID -> m Node
getNode nodeID = do gr <- getGraph
                    Graph.lab gr nodeID <?.> ("GraphParser: getNodeOutputName: Cannot find nodeID=" ++ (show nodeID) ++ " in graph")


getNodeOutputName :: GPStateM m => Node.ID -> m String
getNodeOutputName nodeID = do node <- getNode nodeID
                              return $ node ^. Node.outputName

