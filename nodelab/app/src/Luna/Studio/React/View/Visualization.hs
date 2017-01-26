{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE OverloadedStrings #-}
module Luna.Studio.React.View.Visualization
( visualization
, visualization_
, strValue
)
where

import           Control.Arrow                                  ((***))
import           Data.List.Split                                (wordsBy)
import           Data.Size                                      (Size (Size), Vector2 (Vector2))
import qualified Data.Text                                      as Text
import           Empire.API.Data.DefaultValue                   (Value (..))
import qualified Empire.API.Data.DefaultValue                   as DefaultValue
import qualified Empire.API.Data.Error                          as LunaError
import           Empire.API.Data.TypeRep                        (TypeRep)
import           Empire.API.Graph.NodeResultUpdate              (NodeValue)
import qualified Empire.API.Graph.NodeResultUpdate              as NodeResult
import           Luna.Studio.Prelude
import           Luna.Studio.React.Model.DataFrame              (DataFrame)
import qualified Luna.Studio.React.Model.DataFrame              as DataFrame
import qualified Luna.Studio.React.Model.Image                  as Image
import           Luna.Studio.React.Model.Node                   (Node)
import qualified Luna.Studio.React.Model.Node                   as Node
import           Luna.Studio.React.View.Visualization.DataFrame (dataFrame_)
import           Luna.Studio.React.View.Visualization.Graphics  (graphics_)
import           Luna.Studio.React.View.Visualization.Image     (image_)
import           React.Flux                                     hiding (image_)
import qualified React.Flux                                     as React

viewName :: JSString
viewName = "visualization"

errorMessageWrapMargin :: Int
errorMessageWrapMargin = 30

errorLen :: Int
errorLen = 40

visualization :: ReactView NodeValue
visualization = React.defineView viewName $ \case
    NodeResult.Error msg          -> nodeError_ msg
    NodeResult.Value _ valueReprs -> nodeValues_ valueReprs

visualization_ :: NodeValue -> ReactElementM ViewEventHandler ()
visualization_ v = React.view visualization v mempty

strValue :: Node -> String
strValue n = convert $ case n ^. Node.value of
    Nothing -> ""
    Just (NodeResult.Value value []) -> value
    Just (NodeResult.Value value _ ) -> value
    Just (NodeResult.Error msg     ) -> limitString errorLen (convert $ showError msg)

limitString :: Int -> Text -> Text
limitString limit str | Text.length str > limit64 = Text.take limit64 str <> "…"
                      | otherwise                 = str
                      where limit64 = fromIntegral limit

wrapLines :: Int -> String -> String
wrapLines limit str = unlines . reverse $ foldl f [] $ words str where
    f (a:as) e = let t = a ++ " " ++ e in if length t <= limit then t:as else e:a:as
    f []     e = [e]

showError :: LunaError.Error TypeRep -> String
showError = showErrorSep ""

showErrorSep :: String -> LunaError.Error TypeRep -> String
showErrorSep sep err = case err of
    LunaError.ImportError   name     -> "Cannot find symbol \"" <> name        <> "\""
    LunaError.NoMethodError name tpe -> "Cannot find method \"" <> name        <> "\" for type \"" <> toString tpe <> "\""
    LunaError.TypeError     t1   t2  -> "Cannot match type  \"" <> toString t1 <> "\" with \""     <> toString t2  <> "\""
    LunaError.RuntimeError  msg      -> "Runtime error: " <> sep <> msg

nodeError_ :: LunaError.Error TypeRep -> ReactElementM ViewEventHandler ()
nodeError_ err = do
    let message = wrapLines errorMessageWrapMargin $ showErrorSep "\n" err
    div_
        [ "key"       $= "error"
        , "className" $= "vis vis--error"
        ] $ elemString message

nodeValues_ :: [Value] -> ReactElementM ViewEventHandler ()
nodeValues_ = mapM_ (uncurry nodeValue_) . zip [0..]

nodeValue_ :: Int -> Value -> ReactElementM ViewEventHandler ()
nodeValue_ visIx = \case
    StringList      v -> dataFrame_ visIx $ listTable $ convert <$> v
    IntList         v -> dataFrame_ visIx $ listTable $ convert . show <$> v
    DoubleList      v -> dataFrame_ visIx $ listTable $ convert . show <$> v
    StringMaybeList v -> dataFrame_ visIx $ listTable $ convert . show <$> v
    StringStringMap v -> dataFrame_ visIx $ listTablePairs $ (mapTuple convert) <$> v
    IntPairList     v -> dataFrame_ visIx $ listTablePairs $ mapTuple (convert . show) <$> v
    DoublePairList  v -> dataFrame_ visIx $ listTablePairs $ mapTuple (convert . show) <$> v
    Image     url w h -> image_ visIx $ Image.create (Size (Vector2 w h)) $ convert url
    StringValue   str -> div_ $ elemString $ normalize str
    Lambda        str -> div_ $ elemString $ normalize str
    Graphics       gr -> graphics_ visIx gr
    DataFrame    cols -> do
        let heads  = convert <$> fst <$> cols
            cols'  = fmap DefaultValue.stringify <$> snd <$> cols
            rows   = transpose cols'
            widget = DataFrame.create heads rows
        dataFrame_ visIx widget
    _ -> return ()

listTable :: [Text] -> DataFrame
listTable col = DataFrame.create ["Index", "Value"] rows where
    nats = [1..] :: [Integer]
    idxs = convert . show <$> take (length col) nats
    cols = [idxs, col]
    rows = transpose cols

mapTuple :: (b -> c) -> (b, b) -> (c, c)
mapTuple = join (***)

listTablePairs :: [(Text, Text)] -> DataFrame
listTablePairs rows = DataFrame.create ["fst", "snd"] $ (\(f,s) -> [f,s]) <$> rows

normalize :: String -> String
normalize = intercalate "<br />" . wordsBy (== '\n')
