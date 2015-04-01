---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE ConstraintKinds  #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE Rank2Types       #-}
{-# LANGUAGE TemplateHaskell  #-}
{-# LANGUAGE TupleSections    #-}

module Luna.Pass.Transform.Graph.Parser.Parser where

import           Control.Monad.State
import           Control.Monad.Trans.Either
import qualified Data.Map                   as Map
import qualified Data.Maybe                 as Maybe

import           Flowbox.Prelude                        hiding (folded, mapM, mapM_)
import           Flowbox.System.Log.Logger              hiding (error)
import           Luna.Data.ASTInfo                      (ASTInfo)
import qualified Luna.Data.ASTInfo                      as ASTInfo
import qualified Luna.Parser.Parser                     as Parser
import qualified Luna.Parser.State                      as Parser
import           Luna.Pass.Transform.Graph.Parser.State (GPPass)
import qualified Luna.Pass.Transform.Graph.Parser.State as State
import           Luna.Syntax.Arg                        (Arg (Arg))
import qualified Luna.Syntax.Decl                       as Decl
import qualified Luna.Syntax.Enum                       as Enum
import qualified Luna.Syntax.Expr                       as Expr
import           Luna.Syntax.Graph.DefaultsMap          (DefaultsMap)
import           Luna.Syntax.Graph.Edge                 (Edge)
import qualified Luna.Syntax.Graph.Edge                 as Edge
import           Luna.Syntax.Graph.Graph                (Graph)
import qualified Luna.Syntax.Graph.Graph                as Graph
import qualified Luna.Syntax.Graph.Node                 as Node
import           Luna.Syntax.Graph.Node.Expr            (NodeExpr)
import qualified Luna.Syntax.Graph.Node.Expr            as NodeExpr
import qualified Luna.Syntax.Graph.Node.MultiPart       as MultiPart
import qualified Luna.Syntax.Graph.Node.OutputPat       as OutputPat
import qualified Luna.Syntax.Graph.Node.StringExpr      as StringExpr
import           Luna.Syntax.Graph.Port                 (DstPortP (DstPort))
import qualified Luna.Syntax.Graph.Port                 as Port
import           Luna.Syntax.Graph.Tag                  (TDecl, TExpr, TPat, Tag)
import qualified Luna.Syntax.Graph.Tag                  as Tag
import           Luna.Syntax.Label                      (Label (Label))
import qualified Luna.Syntax.Label                      as Label
import qualified Luna.Syntax.Name.Pattern               as Pattern
import qualified Luna.Syntax.Pat                        as Pat
import           Luna.System.Session                    as Session
import qualified Luna.Util.Label                        as Label



type V = ()


logger :: Logger
logger = getLogger $moduleName


run :: MonadIO m => Graph Tag V -> TDecl V -> ASTInfo -> EitherT State.Error m (TDecl V, ASTInfo)
run graph ldecl astInfo = evalStateT (func2graph ldecl) $ State.mk graph astInfo


func2graph :: TDecl V -> GPPass V m (TDecl V, ASTInfo)
func2graph decl@(Label _ (Decl.Func funcDecl)) = do
    let sig = funcDecl ^. Decl.funcDeclSig
    graph <- State.getGraph
    mapM_ (parseNode sig) $ Graph.sort graph
    b  <- State.getBody
    mo <- State.getOutput
    let body = reverse $ case mo of
                Nothing -> b
                Just o  -> o : b
    (decl & Label.element . Decl.funcDecl . Decl.funcDeclBody .~ body,) <$> State.getASTInfo


parseNode :: Decl.FuncSig a e -> (Node.ID, Node.Node Tag V) -> GPPass V m ()
parseNode signature (nodeID, node) = case node of
    Node.Outputs defaults pos -> parseOutputs nodeID defaults
    Node.Inputs           pos -> parseInputs nodeID signature
    Node.Expr expr outputPat defaults pos -> do
        graph <- State.getGraph
        let lsuclData = Graph.lsuclData graph nodeID
            connectedOnlyToOutput = map (\(dstNID, _, edge) -> (dstNID, edge ^? Edge.src)) lsuclData == [(Node.outputID, Just Port.mkSrcAll)]
            outDataEdges = map (view _3) lsuclData
        srcs <- getNodeSrcs nodeID defaults
        ast <- (Label.label %~ Tag.mkNode nodeID pos Nothing) <$> buildExpr expr srcs
        if connectedOnlyToOutput
            then State.addToExprMap (nodeID, Port.mkSrcAll) $ return ast
            else if not (null outDataEdges) || Maybe.isJust outputPat
                then do pat <- buildPat expr nodeID outDataEdges outputPat
                        let assignment = Expr.Assignment pat ast
                        addExprs nodeID pat
                        State.addToBody =<< newLabel assignment
                else State.addToBody ast


buildExpr :: NodeExpr Tag V -> [TExpr V] -> GPPass V m (TExpr V)
buildExpr nodeExpr srcs = case nodeExpr of
    NodeExpr.ASTExpr expr -> return expr
    NodeExpr.MultiPart mp -> do defArg <- Expr.unnamed <$> newLabel Expr.Wildcard
                                let args = map Expr.unnamed srcs
                                newLabel $ Expr.App $ MultiPart.toNamePat mp args defArg
    NodeExpr.StringExpr str -> case str of
        StringExpr.List           -> newLabel $ Expr.List $ Expr.SeqList srcs
        StringExpr.Tuple          -> newLabel $ Expr.Tuple srcs
        _                         -> do
            astInfo <- State.getASTInfo
            r <- Session.runT $ do
                void Parser.init
                let parserState = Parser.defState & Parser.info .~ astInfo
                Parser.parseString (toString str) (Parser.exprParser2 parserState)
            case fst r of
                Left err -> lift $ left $ toString err
                Right (lexpr, parserState) -> do
                    State.setASTInfo $ parserState ^. Parser.info
                    return $ Label.replaceExpr Tag.fromEnumerated lexpr
        --StringExpr.Pattern pat    -> parsePatNode     nodeID pat
        --StringExpr.Native  native -> parseNativeNode  nodeID native
        --_                         -> parseAppNode     nodeID $ StringExpr.toString str


buildPat :: NodeExpr Tag V -> Node.ID -> [Edge] -> Maybe TPat -> GPPass V m TPat
buildPat nodeExpr nodeID edges = construct (map (unwrap . (^?! Edge.src)) edges)
    where
        construct [] (Just o) = return o
        construct []  _       = l . Pat.Grouped =<< l (Pat.Tuple [])
        construct [Port.All] (Just o@(Label _ (Pat.Var _))) = return o
        construct [Port.All] _                              = State.withASTInfo $ OutputPat.generate nodeExpr nodeID
        l = newLabel


addExprs :: Node.ID -> TPat -> GPPass V m ()
addExprs nodeID tpat = case tpat of
    Label _ (Pat.Var  vname) -> addToExprMap Port.mkSrcAll vname
    Label _ (Pat.Grouped gr) -> addExprs nodeID gr
    Label _ (Pat.Tuple   tp) -> add 0 tp
    _                        -> return ()
    where
        addToExprMap port vname = State.addToExprMap (nodeID, port)
                                $ newLabel' $ Expr.Var $ Expr.Variable vname ()
        add _ []    = return ()
        add i (h:t) = case h of
            Label _ (Pat.Var vname) -> addToExprMap (Port.mkSrc i) vname >> add (i + 1) t
            _                       -> add (i + 1) t


parseInputs :: Node.ID -> Decl.FuncSig a e -> GPPass V m ()
parseInputs nodeID = mapM_ (parseArg nodeID) . zip [0..] . Pattern.args


parseArg :: Node.ID -> (Int, Arg a e) -> GPPass V m ()
parseArg nodeID (num, input) = case input of
    Arg (Label _                     (Pat.Var vname)    ) _ -> addVar vname
    Arg (Label _ (Pat.Typed (Label _ (Pat.Var vname)) _)) _ -> addVar vname
    _                                                       -> lift $ left "parseArg: Wrong Arg type"
    where addVar vname = State.addToExprMap (nodeID, Port.mkSrc num)
                       $ newLabel' $ Expr.Var $ Expr.Variable vname ()


parseOutputs :: Node.ID -> DefaultsMap Tag V -> GPPass V m ()
parseOutputs nodeID defaults = do
    srcs    <- getNodeSrcs nodeID defaults
    inPorts <- State.inboundPorts nodeID
    case (srcs, map unwrap inPorts) of
        ([], _)               -> whenM doesLastStatementReturn $
                                   State.setOutput =<< newLabel . Expr.Grouped
                                                   =<< newLabel (Expr.Tuple [])
        ([src], [Port.Num 0]) -> State.setOutput =<< newLabel (Expr.Grouped src)
        ([src], _           ) -> State.setOutput src
        _                     -> State.setOutput =<< newLabel (Expr.Tuple srcs)


doesLastStatementReturn :: GPPass V m Bool
doesLastStatementReturn = do
    body <- State.getBody
    return $ case body of
        []                                 -> False
        (Label _ (Expr.Assignment {}) : _) -> False --TODO[PM] : check it
        _                                  -> True


getNodeSrcs :: Node.ID -> DefaultsMap Tag v -> GPPass v m [TExpr v]
getNodeSrcs nodeID defaults = do
    g <- State.getGraph
    connectedVars <- mapM (getVar . processEdge) $ Graph.lprelData g nodeID
    let defalutsExprs = map processDefault $ Map.toList defaults
        srcsMap = Map.union (Map.fromList connectedVars) (Map.fromList defalutsExprs)
    if Map.null srcsMap
        then return []
        else do let maxPort = fst $ Map.findMax srcsMap
                mapM (wildcardMissing . flip Map.lookup srcsMap) [0..maxPort]
    where
        processEdge (pNID, _, Edge.Data s (DstPort  Port.All   )) = (0, (pNID, s))
        processEdge (pNID, _, Edge.Data s (DstPort (Port.Num d))) = (d, (pNID, s))

        processDefault (DstPort  Port.All   , expr) = (0, expr)
        processDefault (DstPort (Port.Num d), expr) = (d, expr)

        getVar (i, key) = (i,) <$> State.exprMapLookup key

        wildcardMissing Nothing  = newLabel Expr.Wildcard
        wildcardMissing (Just e) = return e

newLabel :: a -> GPPass v m (Label Tag a)
newLabel = State.withASTInfo . newLabel'

newLabel' :: a -> State ASTInfo (Label Tag a)
newLabel' a = do
    n <- ASTInfo.incID <$> get
    put n
    return $ Label (Enum.tag $ n ^. ASTInfo.lastID) a
