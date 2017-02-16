{-# LANGUAGE LambdaCase          #-}
{-# LANGUAGE ScopedTypeVariables #-}

{-| This module contains operations that output modified nodes.
    These functions use reading, deconstructing and building APIs.

-}

module Empire.ASTOps.Modify (
    redirectLambdaOutput
  , renameVar
  , rewireNode
  , setLambdaOutputToBlank
  , addLambdaArg
  , removeLambdaArg
  ) where

import           Control.Lens (folded, ifiltered)

import           Empire.Prelude

import           Empire.API.Data.Node               (NodeId)
import qualified Empire.API.Data.Port               as Port
import           Empire.ASTOp                       (ASTOp)
import qualified Empire.ASTOps.Builder              as ASTBuilder
import qualified Empire.ASTOps.Deconstruct          as ASTDeconstruct
import qualified Empire.ASTOps.Read                 as ASTRead
import qualified Empire.ASTOps.Remove               as ASTRemove
import           Empire.Data.AST                    (NodeRef, NotLambdaException(..),
                                                     NotUnifyException(..), astExceptionToException,
                                                     astExceptionFromException)

import qualified Luna.IR.Expr.Combinators as IR (changeSource)
import           Luna.IR.Expr.Term.Uni
import           Luna.IR.Expr.Term.Named (Term(Sym_Lam))
import           Luna.IR (match)
import qualified Luna.IR as IR



addLambdaArg :: ASTOp m => NodeRef -> m ()
addLambdaArg lambda = match lambda $ \case
    Lam _arg _body -> do
        out' <- ASTRead.getLambdaOutputRef lambda
        addLambdaArg' lambda out'
    _ -> throwM $ NotLambdaException lambda

addLambdaArg' :: ASTOp m => NodeRef -> NodeRef -> m ()
addLambdaArg' lambda out = match lambda $ \case
    Lam _arg body -> do
        body' <- IR.source body
        if body' == out then do
            b <- IR.blank
            l <- IR.lam b out
            IR.changeSource body $ IR.generalize l
        else do
            addLambdaArg' body' out
    _ -> throwM $ NotLambdaException lambda

data CannotRemovePortException = CannotRemovePortException
    deriving Show

instance Exception CannotRemovePortException where
    toException = astExceptionToException
    fromException = astExceptionFromException

removeLambdaArg :: ASTOp m => NodeRef -> Port.PortId -> m NodeRef
removeLambdaArg _      Port.InPortId{} = throwM $ CannotRemovePortException
removeLambdaArg _      (Port.OutPortId Port.All) = throwM $ CannotRemovePortException
removeLambdaArg lambda (Port.OutPortId (Port.Projection port)) = match lambda $ \case
    Lam _arg _body -> do
        args <- ASTDeconstruct.extractArguments lambda
        out  <- ASTRead.getLambdaOutputRef lambda
        let newArgs = args ^.. folded . ifiltered (\i _ -> i /= port)
        ASTBuilder.lams newArgs out
    _ -> throwM $ NotLambdaException lambda

redirectLambdaOutput :: ASTOp m => NodeRef -> NodeRef -> m NodeRef
redirectLambdaOutput lambda newOutputRef = do
    match lambda $ \case
        Lam _args _ -> do
            args' <- ASTDeconstruct.extractArguments lambda
            ASTBuilder.lams args' newOutputRef
        _ -> throwM $ NotLambdaException lambda

setLambdaOutputToBlank :: ASTOp m => NodeRef -> m NodeRef
setLambdaOutputToBlank lambda = do
    match lambda $ \case
        Lam _args _ -> do
            args' <- ASTDeconstruct.extractArguments lambda
            blank <- IR.generalize <$> IR.blank
            ASTBuilder.lams args' blank
        _ -> throwM $ NotLambdaException lambda

replaceTargetNode :: ASTOp m => NodeRef -> NodeRef -> m ()
replaceTargetNode matchNode newTarget = do
    match matchNode $ \case
        Unify _l r -> do
            IR.changeSource r newTarget
        _ -> throwM $ NotUnifyException matchNode

rewireNode :: ASTOp m => NodeId -> NodeRef -> m ()
rewireNode nodeId newTarget = do
    matchNode <- ASTRead.getASTPointer nodeId
    oldTarget <- ASTRead.getASTTarget  nodeId
    replaceTargetNode matchNode newTarget
    ASTRemove.removeSubtree oldTarget

renameVar :: ASTOp m => NodeRef -> String -> m ()
renameVar vref name = match vref $ \case
    Var n -> do
        (var :: IR.Expr (IR.E IR.String)) <- IR.unsafeGeneralize <$> IR.source n
        IR.modifyExprTerm var $ IR.lit .~ name
