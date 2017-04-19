{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE QuasiQuotes         #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE ViewPatterns        #-}

module FileLoadSpec (spec) where

import           Data.Coerce
import           Data.List                      (find)
import qualified Data.Map                       as Map
import qualified Empire.Data.Graph              as Graph (breadcrumbHierarchy)
import qualified Empire.API.Data.Graph          as Graph
import qualified Empire.API.Data.Node           as Node
import qualified Empire.API.Data.Port           as Port
import           Empire.API.Data.Breadcrumb     (Breadcrumb(..))
import           Empire.API.Data.GraphLocation  (GraphLocation(..))
import           Empire.API.Data.PortRef        (AnyPortRef (..), InPortRef (..), OutPortRef (..))
import           Empire.API.Data.TypeRep        (TypeRep(TStar))
import           Empire.ASTOp                   (runASTOp)
import qualified Empire.ASTOps.Parse            as ASTParse
import qualified Empire.ASTOps.Print            as ASTPrint
import qualified Empire.Commands.Graph          as Graph
import qualified Empire.Commands.GraphBuilder   as GraphBuilder
import qualified Empire.Commands.Library        as Library
import qualified Luna.Syntax.Text.Parser.Parser as Parser (ReparsingStatus(..), ReparsingChange(..))

import           Prologue                   hiding ((|>))

import           Test.Hspec (Spec, around, describe, it, xit, expectationFailure,
                             parallel, shouldBe, shouldMatchList, shouldStartWith)

import EmpireUtils

import           Text.RawString.QQ (r)


spec :: Spec
spec = around withChannels $ do
    describe "file loading" $ do
        it "parses unit" $ \env -> do
            let code = [r|pi ‹0›= 3.14
foo ‹1›= a: b: a + b
bar ‹2›= foo c 6
‹3›print pi
c ‹4›= 3
|]
            res <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath" code
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.withGraph loc $ Graph.loadCode code
                graph <- Graph.withGraph loc $ runASTOp $ GraphBuilder.buildGraph
                return graph
            withResult res $ \(Graph.Graph nodes connections _ _ _) -> do
                let Just pi = find (\node -> node ^. Node.name == Just "pi") nodes
                pi ^. Node.code `shouldBe` Just "3.14"
                pi ^. Node.canEnter `shouldBe` False
                let Just foo = find (\node -> node ^. Node.name == Just "foo") nodes
                foo ^. Node.code `shouldBe` Just "a: b: a + b"
                foo ^. Node.canEnter `shouldBe` True
                let Just bar = find (\node -> node ^. Node.name == Just "bar") nodes
                bar ^. Node.code `shouldBe` Just "foo c 6"
                bar ^. Node.canEnter `shouldBe` False
                let Just anon = find (\node -> node ^. Node.name == Nothing) nodes
                anon ^. Node.code `shouldBe` Just "print pi"
                anon ^. Node.canEnter `shouldBe` False
                let Just c = find (\node -> node ^. Node.name == Just "c") nodes
                c ^. Node.code `shouldBe` Just "3"
                c ^. Node.canEnter `shouldBe` False
                connections `shouldMatchList` [
                      (outPortRef (pi ^. Node.nodeId) [], inPortRef (anon ^. Node.nodeId) [Port.Arg 0])
                    , (outPortRef (c ^. Node.nodeId)  [], inPortRef (bar ^. Node.nodeId)  [Port.Arg 0])
                    ]
        it "shows proper changes to expressions" $ \env -> do
            let code = [r|pi ‹0›= 3.14

foo ‹1›= a: b: a + b

c ‹2›= 4
bar ‹3›= foo 8 c
|]
            res <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath" code
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.withGraph loc $ Graph.loadCode code
                Graph.substituteCode "TestPath" 59 59 "3" (Just 60)
            withResult res $ \(coerce -> Just (rs :: [Parser.ReparsingChange])) -> do
                let unchanged = filter (\x -> case x of Parser.UnchangedExpr{} -> True; _ -> False) rs
                    changed   = filter (\x -> case x of Parser.ChangedExpr{} -> True; _ -> False) rs
                length unchanged `shouldBe` 3
                length changed `shouldBe` 1
        it "does not duplicate nodes on edit" $ \env -> do
            let code = [r|pi ‹0›= 3.14

foo ‹1›= a: b: a + b

c ‹2›= 4
bar ‹3›= foo 8 c
|]
            res <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath" code
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.withGraph loc $ Graph.loadCode code
                changes <- Graph.substituteCode "TestPath" 43 43 "3" (Just 44)
                graph   <- Graph.getGraph loc
                return (changes, graph)
            withResult res $ \(coerce -> Just (rs :: [Parser.ReparsingChange]), graph) -> do
                let unchanged = filter (\x -> case x of Parser.UnchangedExpr{} -> True; _ -> False) rs
                    changed   = filter (\x -> case x of Parser.ChangedExpr{} -> True; _ -> False) rs
                length unchanged `shouldBe` 3
                length changed `shouldBe` 1
                let Graph.Graph nodes connections _ _ _ = graph
                    cNodes = filter (\node -> node ^. Node.name == Just "c") nodes
                length cNodes `shouldBe` 1
                let [cNode] = cNodes
                    Just bar = find (\node -> node ^. Node.name == Just "bar") nodes
                connections `shouldMatchList` [
                      (outPortRef (cNode ^. Node.nodeId) [], inPortRef (bar ^. Node.nodeId) [Port.Arg 1])
                    ]
        it "double modification gives proper value" $ \env -> do
            let code = [r|pi ‹0›= 3.14

foo ‹1›= a: b: a + b

c ‹2›= 4
bar ‹3›= foo 8 c
|]
            res <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath" code
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.withGraph loc $ Graph.loadCode code
                Graph.substituteCode "TestPath" 43 43 "3" (Just 44)
                Graph.substituteCode "TestPath" 43 43 "3" (Just 44)
                Graph.getGraph loc
            withResult res $ \graph -> do
                let Graph.Graph nodes connections _ _ _ = graph
                    cNodes = filter (\node -> node ^. Node.name == Just "c") nodes
                length nodes `shouldBe` 4
                length cNodes `shouldBe` 1
                let [cNode] = cNodes
                    Just bar = find (\node -> node ^. Node.name == Just "bar") nodes
                cNode ^. Node.code `shouldBe` Just "334"
                connections `shouldMatchList` [
                      (outPortRef (cNode ^. Node.nodeId) [], inPortRef (bar ^. Node.nodeId) [Port.Arg 1])
                    ]
        it "modifying two expressions give proper values" $ \env -> do
            let code = [r|pi ‹0›= 3.14

foo ‹1›= a: b: a + b

c ‹2›= 4
bar ‹3›= foo 8 c
|]
            res <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath" code
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.withGraph loc $ Graph.loadCode code
                Graph.substituteCode "TestPath" 43 43 "3" (Just 44)
                Graph.substituteCode "TestPath" 59 59 "1" (Just 60)
                Graph.getGraph loc
            withResult res $ \graph -> do
                let Graph.Graph nodes connections _ _ _ = graph
                    cNodes = filter (\node -> node ^. Node.name == Just "c") nodes
                length nodes `shouldBe` 4
                length cNodes `shouldBe` 1
                let [cNode] = cNodes
                    Just bar = find (\node -> node ^. Node.name == Just "bar") nodes
                cNode ^. Node.code `shouldBe` Just "34"
                bar ^. Node.code `shouldBe` Just "foo 18 c"
                connections `shouldMatchList` [
                      (outPortRef (cNode ^. Node.nodeId) [], inPortRef (bar ^. Node.nodeId) [Port.Arg 1])
                    ]
        it "adding an expression works" $ \env -> do
            let code = [r|pi ‹0›= 3.14

foo ‹1›= a: b: a + b

c ‹2›= 4
bar ‹3›= foo 8 c
|]
            res <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath" code
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.withGraph loc $ Graph.loadCode code
                Graph.substituteCode "TestPath" 35 35 "d ‹4›= 10" (Just 36)
                Graph.getGraph loc
            withResult res $ \graph -> do
                let Graph.Graph nodes connections _ _ _ = graph
                    Just d = find (\node -> node ^. Node.name == Just "d") nodes
                d ^. Node.code `shouldBe` Just "10"
                let Just c = find (\node -> node ^. Node.name == Just "c") nodes
                    Just bar = find (\node -> node ^. Node.name == Just "bar") nodes
                connections `shouldMatchList` [
                      (outPortRef (c ^. Node.nodeId) [], inPortRef (bar ^. Node.nodeId) [Port.Arg 1])
                    ]
        it "unparseable expression does not sabotage whole file" $ \env -> do
            let code = [r|pi ‹0›= 3.14

foo ‹1›= a: b: a + b

c ‹2›= 4
bar ‹3›= foo 8 c
|]
            res <- evalEmp env $ do
                Library.createLibrary Nothing "TestPath" code
                let loc = GraphLocation "TestPath" $ Breadcrumb []
                Graph.withGraph loc $ Graph.loadCode code
                Graph.substituteCode "TestPath" 8 12 ")" (Just 8)
                Graph.substituteCode "TestPath" 8 9 "5" (Just 8)
                Graph.getGraph loc
            withResult res $ \graph -> do
                let Graph.Graph nodes connections _ _ _ = graph
                    Just pi = find (\node -> node ^. Node.name == Just "pi") nodes
                    Just c = find (\node -> node ^. Node.name == Just "c") nodes
                    Just bar = find (\node -> node ^. Node.name == Just "bar") nodes
                pi ^. Node.code `shouldBe` Just "5"
                c ^. Node.code `shouldBe` Just "4"
                bar ^. Node.code `shouldBe` Just "foo 8 c"
                connections `shouldMatchList` [
                      (outPortRef (c ^. Node.nodeId) [], inPortRef (bar ^. Node.nodeId) [Port.Arg 1])
                    ]