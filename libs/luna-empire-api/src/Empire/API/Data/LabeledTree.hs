{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE DeriveFoldable #-}
{-# LANGUAGE DeriveTraversable #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE TypeFamilies #-}

module Empire.API.Data.LabeledTree where

import Prologue
import Data.Binary      (Binary)
import Data.Aeson.Types (FromJSON, ToJSON)

data LabeledTree f a = LabeledTree { _subtrees :: (f (LabeledTree f a)), _value :: a} deriving (Generic, Functor, Applicative, Foldable, Traversable)
makeLenses ''LabeledTree

instance (Binary   (f (LabeledTree f a)), Binary   a) => Binary   (LabeledTree f a)
instance (ToJSON   (f (LabeledTree f a)), ToJSON   a) => ToJSON   (LabeledTree f a)
instance (FromJSON (f (LabeledTree f a)), FromJSON a) => FromJSON (LabeledTree f a)

deriving instance (Eq     a, Eq     (f (LabeledTree f a))) => Eq     (LabeledTree f a)
deriving instance (Show   a, Show   (f (LabeledTree f a))) => Show   (LabeledTree f a)
deriving instance (NFData a, NFData (f (LabeledTree f a))) => NFData (LabeledTree f a)

type instance Index   (LabeledTree f a) = [Index (f (LabeledTree f a))]
type instance IxValue (LabeledTree f a) = a
instance (IxValue (f (LabeledTree f a)) ~ LabeledTree f a, Ixed (f (LabeledTree f a))) => Ixed (LabeledTree f a) where
    ix []       = value
    ix (a : as) = subtrees . ix a . ix as
