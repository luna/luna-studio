{-# LANGUAGE DeriveAnyClass      #-}
{-# LANGUAGE LambdaCase          #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications    #-}

module Empire.ASTOps.Builder (
    buildAccessors
  , lams
  , makeNodeRep
  , makeAccessor
  , applyFunction
  , removeAccessor
  ) where

import           Control.Monad                      (foldM, replicateM)
import           Data.Maybe                         (isNothing)
import           Empire.Prelude

import           Empire.ASTOp                       (ASTOp)
import           Empire.ASTOps.Deconstruct          (deconstructApp, extractArguments, dumpAccessors)
import           Empire.ASTOps.Remove               (removeSubtree)
import           Empire.Data.AST                    (NodeRef, astExceptionFromException,
                                                     astExceptionToException)
import           Empire.Data.Layers                 (NodeMarker(..), Marker)

import           Luna.IR.Expr.Term.Uni
import           Luna.IR.Function (arg)
import           Luna.IR.Function.Argument (Arg)
import           Luna.IR (match)
import qualified Luna.IR as IR


apps :: ASTOp m => IR.Expr f -> [NodeRef] -> m NodeRef
apps fun exprs = IR.unsafeRelayout <$> foldM f (IR.unsafeRelayout fun) (IR.unsafeRelayout <$> exprs)
    where
        f fun' arg' = appAny fun' (arg arg')

appAny :: ASTOp m => NodeRef -> Arg (NodeRef) -> m NodeRef
appAny = fmap IR.generalize .: IR.app

lams :: ASTOp m => [NodeRef] -> NodeRef -> m NodeRef
lams args output = IR.unsafeRelayout <$> foldM f (IR.unsafeRelayout seed) (IR.unsafeRelayout <$> rest)
    where
        f arg' lam' = lamAny (arg arg') lam'
        (seed : rest) = args ++ [output]

lamAny :: ASTOp m => Arg NodeRef -> NodeRef -> m NodeRef
lamAny a b = fmap IR.generalize $ IR.lam a b

newApplication :: ASTOp m => NodeRef -> NodeRef -> Int -> m NodeRef
newApplication fun arg' pos = do
    blanks <- sequence $ replicate pos IR.blank
    let args = IR.generalize blanks ++ [arg']
    apps fun args

rewireApplication :: ASTOp m => NodeRef -> NodeRef -> Int -> m NodeRef
rewireApplication fun arg' pos = do
    (target, oldArgs) <- deconstructApp fun

    let argsLength = max (pos + 1) (length oldArgs)
    blanks <- replicateM (argsLength - length oldArgs) IR.blank
    let argsCmd = oldArgs ++ map IR.generalize blanks
        withNewArg = argsCmd & ix pos .~ arg'

    apps target withNewArg

applyFunction :: ASTOp m => NodeRef -> NodeRef -> Int -> m NodeRef
applyFunction fun arg' pos = match fun $ \case
    App{} -> rewireApplication fun arg' pos
    _     -> newApplication fun arg' pos


reapply :: ASTOp m => NodeRef -> [NodeRef] -> m NodeRef
reapply funRef args = do
    funNode <- pure funRef
    fun <- match funNode $ \case
        App t _ -> do
            f <- IR.source t
            removeSubtree funRef
            return f
        _ -> return funRef
    apps fun args

buildAccessors :: ASTOp m => NodeRef -> [String] -> m NodeRef
buildAccessors = foldM $ \t n -> IR.generalize <$> IR.rawAcc n t

data SelfPortNotExistantException = SelfPortNotExistantException NodeRef
    deriving (Show)

instance Exception SelfPortNotExistantException where
    toException = astExceptionToException
    fromException = astExceptionFromException

makeAccessor :: ASTOp m => NodeRef -> NodeRef -> m NodeRef
makeAccessor target naming = do
    (_, names) <- dumpAccessors naming
    when (null names) $ throwM $ SelfPortNotExistantException naming
    args <- extractArguments naming
    acc <- buildAccessors target names
    if null args then return acc else reapply acc args

data SelfPortNotConnectedException = SelfPortNotConnectedException NodeRef
    deriving (Show)

instance Exception SelfPortNotConnectedException where
    toException = astExceptionToException
    fromException = astExceptionFromException

removeAccessor :: ASTOp m => NodeRef -> m NodeRef
removeAccessor ref = do
    (target, names) <- dumpAccessors ref
    args            <- extractArguments ref
    when (isNothing target) $ throwM $ SelfPortNotConnectedException ref
    case names of
        []     -> throwM $ SelfPortNotConnectedException ref
        n : ns -> do
            v   <- IR.generalize <$> IR.strVar n
            acc <- buildAccessors v ns
            if null args then return acc else reapply acc args

makeNodeRep :: ASTOp m => NodeMarker -> String -> NodeRef -> m NodeRef
makeNodeRep marker name node = do
    (nameVar :: NodeRef) <- IR.generalize <$> IR.strVar name
    IR.writeLayer @Marker (Just marker) nameVar
    IR.generalize <$> IR.unify nameVar node
