---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2013
---------------------------------------------------------------------------

module Luna.Data.Graph (
    Graph,
    Vertex,
    Edge,
    empty,
    insNode,
    insNodes,
    insEdge,
    insEdges,
    lab,
    labs,
    labVtx,
    labVtxs,
    out,
    out_,
    inn,
    inn_,
    innvtx,
    suc,
    suc_,
    pre,
    pre_,
    topsort,
    path,
    newIds
) where

import qualified Data.Graph.Inductive            as DG
import           Data.Graph.Inductive            hiding (lab, Graph)


type Graph a b = DG.Gr a b
type Vertex    = DG.Node
type LVertex a = DG.LNode a


lab :: Graph a b -> Vertex -> a
lab g vtx = DG.lab' $ DG.context g vtx


labs :: Graph a b -> [Vertex] -> [a]
labs g vtxs = map (lab g) vtxs


labVtx :: Graph a b -> Vertex -> LVertex a
labVtx g vtx = (vtx, lab g vtx)


labVtxs :: Graph a b -> [Vertex] -> [LVertex a]
labVtxs g vtxs = map (labVtx g) vtxs


out_ :: Graph a b -> Vertex -> [b]
out_ g vtx = [el | (_,_,el) <- out g vtx]


inn_ :: Graph a b -> Vertex -> [b]
inn_ g vtx = [el | (_,_,el) <- inn g vtx]


innvtx :: Graph a b -> Vertex -> [Vertex]
innvtx g vtx = [pvtx | (pvtx,_,_) <- inn g vtx]


suc_ :: Graph a b -> Vertex -> [a]
suc_ g vtx = map (lab g) $ suc g vtx


pre_ :: Graph a b -> Vertex -> [a]
pre_ g vtx = map (lab g) $ pre g vtx


path :: Graph a b -> Vertex -> [Vertex]
path g vtx = case pre g vtx of
    []       -> [vtx]
    [parent] -> path g parent ++ [vtx]
    _        -> error "Node has multiple parents"


newIds :: Graph a b -> [Vertex]
newIds g = [n+1..] where (_,n) = nodeRange g