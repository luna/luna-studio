---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2013
---------------------------------------------------------------------------

module Luna.Codegen.Hs.FuncGenerator(
generateFunction
) where


import Debug.Trace

import           Data.String.Utils                 (join)
import qualified Data.Graph.Inductive            as DG
import           Control.Monad.State               (runState, get, put, State)

import qualified Luna.Type.Type                  as Type
import qualified Luna.Network.Path.Import        as Import
import           Luna.Network.Path.Import          (Import)
import qualified Luna.Network.Path.Path          as Path
import           Luna.Network.Path.Path            (Path)
import qualified Luna.Network.Graph.Graph        as Graph
import           Luna.Network.Graph.Graph          (Graph)
import qualified Luna.Network.Def.NodeDef        as NodeDef
import           Luna.Network.Def.NodeDef          (NodeDef)
import qualified Luna.Network.Def.DefManager     as DefManager
import           Luna.Network.Def.DefManager       (DefManager)
import qualified Luna.Network.Graph.Node         as Node
import           Luna.Network.Graph.Node           (Node)
import qualified Luna.Network.Graph.DefaultValue as DefaultValue
import qualified Luna.Network.Flags              as Flags
import qualified Luna.Network.Path.Path          as Path
import           Luna.Codegen.Hs.State.FuncState   (FuncState)
import qualified Luna.Codegen.Hs.State.FuncState as FuncState
import qualified Luna.Codegen.Hs.State.Context   as Context
import qualified Luna.Codegen.Hs.State.Mode      as Mode


import qualified Luna.Codegen.Hs.AST.Function    as Function
import           Luna.Codegen.Hs.AST.Function      (Function)
import qualified Luna.Codegen.Hs.AST.Expr        as Expr
import           Luna.Codegen.Hs.AST.Expr          (Expr)

import Data.Tuple.Select



inputs :: String
inputs = "inputs'"


outputs :: String
outputs = "outputs'"




generateFunction def = func where
    graph      = NodeDef.graph def
    vertices   = Graph.topsort graph
    nodes      = Graph.labVtxs graph vertices
    funcproto  = Function.empty { Function.name = Type.name $ NodeDef.cls def
                                , Function.inputs = [inputs]
                                }
    func       =  generateNodeExprs graph nodes funcproto


generateNodeExprs graph [] func           = func
generateNodeExprs graph (node:nodes) func = nfunc where
    nfunc = generateNodeExpr graph node $ generateNodeExprs graph nodes func


generateNodeExpr graph lnode func = Function.addExpr expr func where 
    nid   = sel1 lnode
    node  = sel2 lnode
    expr  = Expr.Assignment (Expr.VarRef nid) value where 
    value = case node of
        Node.New _ _            -> Expr.VarRef cvtx where
                                       cvtx:vtxs = Graph.innvtx graph nid
                                       -- TODO[wd] exception when too many inputs

        Node.Type name _ _      -> Expr.Var name

        Node.Tuple _ _          -> Expr.Tuple args where
                                       vtxs = Graph.innvtx graph nid
                                       args = map Expr.VarRef vtxs

        Node.Call name flags _  -> Expr.Call name args where
                                       vtxs = Graph.innvtx graph nid
                                       args = map Expr.VarRef vtxs

        Node.Inputs  _ _        -> Expr.Var inputs
        Node.Outputs _ _        -> Expr.Var outputs

        Node.Default d          -> Expr.Default val where 
                                       val = case d of
                                           DefaultValue.DefaultString v -> "\"" ++ v ++ "\""
                                           DefaultValue.DefaultInt    v -> show v




--indent :: Int -> String
--indent num = replicate (num*4) ' '

--mpostfix :: String
--mpostfix = "''M"

--outvar :: Show a => a -> [Char]
--outvar x = "out'" ++ show x

--generateImportCode :: Import -> String
--generateImportCode i = let
--    segments = Path.segments $ Import.path i
--    items    = Import.items i
--    import_list       = [(join "." (segments++[item]),item) | item <- items]
--    simple_imports    = ["import           " ++ path ++ " as " ++ item         | (path, item) <-import_list]
--    qualified_imports = ["import qualified " ++ path ++ " (" ++ item ++"(..))" | (path, item) <-import_list]
--    in join "\n" (simple_imports ++ qualified_imports)


--generateImportsCode :: [Import] -> String
--generateImportsCode i = join "\n" $ fmap generateImportCode i

--generateNodeCode (nid, Node.Call name flags _ ) = do
--    state <- get
--    defout <- generateDefaultOutput nid    
--    let isio = Flags.io flags && (FuncState.mode state /= Mode.ForcePure)
--        (op, fname) = if isio 
--            then ("<-", name ++ mpostfix)
--            else ("=" , name)
--        code = outvar nid ++ " " ++ op ++ " " ++ fname ++ " " ++ defout
    
--    if isio
--        then do put $ state{FuncState.ctx=Context.IO, FuncState.lastctx=Context.IO  }
--        else do put $ state{                          FuncState.lastctx=Context.Pure} 
--    return code


--generateFunctionBody :: State FuncState String
--generateFunctionBody = do
--    state <- get
--    let
--        graph      = FuncState.graph state
--        vertices   = Graph.topsort graph
--        nodes      = Graph.labVtxs graph vertices
--    generateNodeCodes nodes


--generateFunctionHeader :: State FuncState String
--generateFunctionHeader = do
--    state <- get
--    let t    = NodeDef.cls $ FuncState.def state
--        name = Type.name t ++ if FuncState.ctx state == Context.IO || FuncState.mode state == Mode.ForceIO
--            then mpostfix
--            else ""
--    return $ name ++ " " ++ inputs ++ " = " 


--generateFunctionCode :: State FuncState String
--generateFunctionCode = do
--    body   <- generateFunctionBody
--    header <- generateFunctionHeader
--    state  <- get
--    let
--        (ret, prefix) = if FuncState.ctx state == Context.IO || FuncState.mode state == Mode.ForceIO
--            then ("return " ++ outputs, "do\n" ++ indent 1 ++ "let\n")
--            else ("in "     ++ outputs, "\n"   ++ indent 1 ++ "let\n")
--        code =  header ++ prefix
--             ++ body
--             ++ indent 1 ++ ret 
--    return code


--generateNodeCodes :: [DG.LNode Node] -> State FuncState String
--generateNodeCodes []           = return ""
--generateNodeCodes (node:nodes) = do
--    prestate  <- get
--    code      <- generateNodeCode  node
--    poststate <- get
--    childcode <- generateNodeCodes nodes

--    let
--        ctx = FuncState.lastctx poststate
--        prefix = if ctx /= (FuncState.lastctx prestate)
--            then case ctx of
--                Context.IO   -> ""
--                Context.Pure -> indent 1 ++ "let\n" ++ indent 1
--            else case ctx of
--                Context.IO   -> ""
--                Context.Pure -> indent 1
--    return $ prefix ++ indent 1 ++ code ++ "\n" ++ childcode


--collectInputNum :: Graph -> Int -> [DG.Node]
--collectInputNum graph nid = [num | (num,_,_) <- inedges] where
--    inedges = Graph.inn graph nid


--generateDefaultOutput :: Int -> State FuncState String
--generateDefaultOutput nid = do
--    state <- get 
--    let
--        inputnums = collectInputNum (FuncState.graph state) nid
--        body = if null inputnums
--            then "()"
--            else join " " $ fmap outvar inputnums
--    return body


--generateNodeCode :: DG.LNode Node -> State FuncState String
--generateNodeCode (nid, Node.New _ _) = do
--    defout <- generateDefaultOutput nid
--    return $ outvar nid ++ " = " ++ defout

--generateNodeCode (nid, Node.Default (DefaultValue.DefaultString val)) = return $ outvar nid ++ " = \"" ++ val ++ "\"" 

--generateNodeCode (nid, Node.Default (DefaultValue.DefaultInt val)) = return $  outvar nid ++ " = " ++ show val

--generateNodeCode (nid, Node.Type name _ _ ) = 
--    --"type Type'" ++ show nid ++ " = " ++ name ++ "\n" ++
--    return $ outvar nid ++ " = " ++ name

--generateNodeCode (nid, Node.Call name flags _ ) = do
--    state <- get
--    defout <- generateDefaultOutput nid    
--    let isio = Flags.io flags && (FuncState.mode state /= Mode.ForcePure)
--        (op, fname) = if isio 
--            then ("<-", name ++ mpostfix)
--            else ("=" , name)
--        code = outvar nid ++ " " ++ op ++ " " ++ fname ++ " " ++ defout
    
--    if isio
--        then do put $ state{FuncState.ctx=Context.IO, FuncState.lastctx=Context.IO  }
--        else do put $ state{                          FuncState.lastctx=Context.Pure} 
--    return code
        
--generateNodeCode (nid, Node.Tuple _ _) = do
--    state <- get 
--    let 
--        inputnums = collectInputNum (FuncState.graph state) nid
--        elements = join ", " $ fmap outvar inputnums
--        body = if length inputnums == 1
--            then "OneTuple " ++ elements
--            else "(" ++ elements ++ ")"
--    return $ outvar nid ++ " = " ++ body
                  
--generateNodeCode (nid, Node.Inputs _ _ ) = return $ outvar nid ++ " = " ++ inputs

--generateNodeCode (nid, Node.Outputs _ _ ) = do
--    defout <- generateDefaultOutput nid
--    return $ outputs ++ " = " ++ defout

--generateNodeCode (nid, node) = return "<not implemented>"

