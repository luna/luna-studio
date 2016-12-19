{-# LANGUAGE OverloadedStrings #-}
module Luna.Studio.React.View.DataFrame where

import qualified Data.Text.Lazy                       as Text
import           React.Flux

import           Luna.Studio.Prelude
import           Luna.Studio.React.Model.DataFrame    (DataFrame)
import qualified Luna.Studio.React.Model.DataFrame    as DataFrame
import           Luna.Studio.React.View.ForeignObject (foreignObject_)



dataFrame_ :: Int -> DataFrame -> ReactElementM ViewEventHandler ()
dataFrame_ visIx df =
    div_
        [ "key" $= fromString (show visIx)
        , "className" $= "visualization data-frame" ] $
        div_ $
            table_ $
                tbody_ $ do
                    tr_ $ forM_ (df ^. DataFrame.headers) $
                        th_ .
                            elemString . fromString . Text.unpack
                    forM_ (df ^. DataFrame.rows) $ \row ->
                        tr_ $ forM_ row $
                            td_ .
                                elemString . fromString . Text.unpack
