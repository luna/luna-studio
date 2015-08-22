{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE NoMonomorphismRestriction #-}

{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Luna.Syntax.Term where

import Flowbox.Prelude hiding (Cons, cons)
import Data.Variants   hiding (Cons)

import Luna.Syntax.Lit
import Luna.Syntax.Arg
import Luna.Syntax.Name

import Data.Cata
import Data.Containers.Hetero
import Luna.Syntax.Graph

-- === Terms ===

-- Component types

data    Star       = Star               deriving (Show, Eq)
newtype Var        = Var      Name      deriving (Show, Eq)
data    Cons     t = Cons     Name [t]  deriving (Show, Eq)
data    Accessor t = Accessor Name t    deriving (Show, Eq)
data    App      t = App      t [Arg t] deriving (Show, Eq)


        --data CTop      = CTop
        --data CTarget t = CTarget t
        --data CName     = CName

        ----data CVar    = CVar  (Record '[CName])
        --data CAccessor t = CAccessor (Record '[CName, CTarget t])
        --data CTerm     t = CTerm     (Record '[CAccessor t])


        --type family PathsOf a :: [*]
        --type instance PathsOf (Accessor t) = '[CTarget (Record (PathsOf t))]


        --data Crumb t a = Crumb a


        --type CX = Mu CTerm

        ----c1 = Mu (CTerm $ cons $ CAccessor $ undefined) :: CX

        --cx = CAccessor $ cons CName :: CAccessor (Mu CTerm)

        --cy = CTerm $ cons cx :: CTerm (Mu CTerm)

        --cz = Mu (CTerm $ cons cx) :: CX
--data CTerm t = CTerm (Record '[Accessor t])

--c1 = cons CName :: CAccessor


    --type instance Variants (CAccessor t) = '[CName, CTarget (Record (PathsOf t))]

    --instance IsVariant (CAccessor t) where
    --    variant = CAccessor
    --    record  = undefined

    ----class IsVariant a where
    ----    variant :: Record (Variants a) -> a
    ----    record  :: Lens' a (Record (Variants a))

    --type family CrumbOf a
    --type instance CrumbOf (Mu a) = CrumbOf (a (Mu a))
    --type instance CrumbOf (Accessor t) = CAccessor t
    --type instance CrumbOf (Term' t) = CTerm t


    --type family PathsOf a :: [*]

    --type instance PathsOf (Accessor t) = '[CTarget (Record (PathsOf t))]

    --class HasTarget t a | a -> t where
    --    target :: Lens' a t

    --instance HasTarget t (Accessor t) where
    --    target = lens (\(Accessor _ t) -> t) (\(Accessor n _) t -> Accessor n t)

    --instance HasTarget (CAccessor t) (CTop (Accessor t)) where
    --    target = lens (const $ cons (CTarget :: CTarget (Record (PathsOf t)))) undefined

    --instance c ~ CrumbOf a => HasTarget c (CTop a) where

    --v = Mu (Term' $ cons $ Accessor "foo" (Mu $ Term' $ cons $ Var "foo")) :: Mu Term'

    --vc = CTop v :: CTop (Mu Term')

    --vc' :: CTerm (Mu Term')
    --vc' = view target vc

--instance HasTarget a t => HasTarget (Crumb a) where
--    target = lens (const $ Crumb CTarget) const - - - tu jest zle
    -- trzebaby dorobic MapVariants lub WithVariants - przy dodawaniu nowego breadcrumba

--------------------

--v = Crumb CTop :: Crumb CTop (Accessor Int)
--v' = view target v :: _



-- breadcrumby moga byc po prostu lensami Lens' a t
-- lub czyms podobnym pozwalajacym na rozlaczanie (!)

--data CTop    = CTop
--data CTarget = CTarget

--data Crumb a b = Crumb a b

-- ...

--instance HasTarget CTarget (Crumb a (Accessor t)) where
--    target = lens (const CTarget) const

-- najlepsze jest chyba reczne odwzorowanie struktury z lensami, przy cyzm nawet stale Lensy takie jak HasName przerobic na takie jak wyzej,
-- by dzialaly z breadcrumbami


-- Type sets

type TermElems  t = Var
                 ': ThunkElems t

type ThunkElems t = Accessor t
                 ': App      t
                 ': ValElems t

type ValElems   t = Lit
                 ': Cons t -- todo[wd]: Add "[t]"
                 ': Star
                 ': '[]

-- Record types

type H a h = h (a h)
type HRecord a (h :: * -> *) = VariantRec (a h)

newtype Val   h = Val   { __valRec   :: HRecord Val   h }
newtype Thunk h = Thunk { __thunkRec :: HRecord Thunk h }
newtype Term  h = Term  { __termRec  :: HRecord Term  h }

-----------------------------------------------------------------------------------------------

newtype Val'   t = Val'   (VariantRec (Val'   t)) deriving (Show)
newtype Thunk' t = Thunk' (VariantRec (Thunk' t)) deriving (Show)
newtype Term'  t = Term'  (VariantRec (Term'  t)) deriving (Show)

type instance Variants (Val'   t) =                           ValElems   t
type instance Variants (Thunk' t) = (Val' t) ':               ThunkElems t
type instance Variants (Term'  t) = (Val' t) ': (Thunk' t) ': TermElems  t


instance Record (Val'   h) where mkRecord = Val'
instance Record (Thunk' h) where mkRecord = Thunk'
instance Record (Term'  h) where mkRecord = Term'

--instance IsVariant (Val' h)   where record  = lens (\(Val' r) -> r) (const Val')
--                                    variant = Val'

--instance IsVariant (Thunk' h) where record  = lens (\(Thunk' r) -> r) (const Thunk')
--                                    variant = Thunk'

--instance IsVariant (Term' h)  where record  = lens (\(Term' r) -> r) (const Term')
--                                    variant = Term'

type instance Variants (Val   h) =                         ValElems   (H Val   h)
type instance Variants (Thunk h) = (Val h) ':              ThunkElems (H Thunk h)
type instance Variants (Term  h) = (Val h) ': (Thunk h) ': TermElems  (H Term  h)

makeLenses ''Val
makeLenses ''Thunk
makeLenses ''Term
--TODO[wd]: makeClassyInstances (dla HasRecord etc)

-- instances

deriving instance (Show (H Val h))                                    => Show (Val   h)
deriving instance (Show (H Val h), Show (H Thunk h))                  => Show (Thunk h)
deriving instance (Show (H Val h), Show (H Thunk h), Show (H Term h)) => Show (Term  h)

--instance IsVariant (Val h)   where record  = _valRec
--                                   variant = Val

--instance IsVariant (Thunk h) where record  = _thunkRec
--                                   variant = Thunk

--instance IsVariant (Term h)  where record  = _termRec
--                                   variant = Term

-- Name instances

--TODO[wd]: makeClassyInstances ''Cons
instance HasName Var          where name = lens (\(Var n)        -> n) (\(Var _) n         -> Var n)
instance HasName (Cons a)     where name = lens (\(Cons n _)     -> n) (\(Cons _ t1) n     -> Cons n t1)
instance HasName (Accessor a) where name = lens (\(Accessor n _) -> n) (\(Accessor _ t1) n -> Accessor n t1)

-- Repr instances

instance Repr a => Repr (App a) where
    repr (App a args) = "App (" <> repr a <> ") " <> repr args

instance Repr a => Repr (Arg a) where
    repr (Arg n a) = "Arg (" <> repr n <> ") (" <> repr a <> ")"







--type Term h = h (Term h)


--data Arg h = Arg { _label :: Maybe Name, _term :: Term h }

-- wszystkie rzeczy nazwane powinny byc w slownikach w jezyku! - czyli datatypy ponizej zostaja,
-- ale mozemy tworzyc np. Var funkcjami, ktore oczekuja konkretnego Stringa!
--data Term h = Var      Name
--            | Cons     Name
--            | Accessor Name (Term h)
--            | App      (Term h) [Arg h]
--            | Lambda
--            | RecUpd
--            | Unify    (Term h) (Term h)
--            | Case
--            | Typed
--            -- | Assignment
--            -- x | Decons
--            | Curry
--            -- | Meta
--            -- | Tuple
--            -- | Grouped
--            -- | Decl
--            | Lit      Lit
--            | Wildcard
--            -- | Tuple
--            -- | List
--            | Unsafe [Name] (Term h)



