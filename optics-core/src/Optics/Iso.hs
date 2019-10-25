-- |
-- Module: Optics.Iso
-- Description: Translates between types with the same structure.
--
-- An 'Iso'morphism expresses the fact that two types have the
-- same structure, and hence can be converted from one to the other in
-- either direction.
--
module Optics.Iso
  (
  -- * Formation
    Iso
  , Iso'

  -- * Introduction
  , iso

  -- * Elimination
  -- | An 'Iso' is in particular a 'Optics.Getter.Getter', a
  -- 'Optics.Review.Review' and a 'Optics.Setter.Setter', therefore you can
  -- specialise types to obtain:
  --
  -- @
  -- 'Optics.Getter.view'   :: 'Iso' s t a b -> s -> a
  -- 'Optics.Review.review' :: 'Iso' s t a b -> b -> t
  -- @
  --
  -- @
  -- 'Optics.Setter.over'   :: 'Iso' s t a b -> (a -> b) -> s -> t
  -- 'Optics.Setter.set'    :: 'Iso' s t a b ->       b  -> s -> t
  -- @

  -- * Computation
  -- |
  --
  -- @
  -- 'Optics.Getter.view'   ('iso' f g) ≡ f
  -- 'Optics.Review.review' ('iso' f g) ≡ g
  -- @

  -- * Well-formedness
  -- | The functions translating back and forth must be mutually inverse:
  --
  -- @
  -- 'Optics.Getter.view' i . 'Optics.Getter.review' i ≡ 'id'
  -- 'Optics.Getter.review' i . 'Optics.Getter.view' i ≡ 'id'
  -- @

  -- * Additional introduction forms
  , equality
  , simple
  , coerced
  , coercedTo
  , coerced1
  , curried
  , uncurried
  , flipped
  , involuted
  , Swapped(..)

  -- * Additional elimination forms
  , withIso
  , au
  , under

  -- * Combinators
  -- | The 'Optics.Re.re' combinator can be used to reverse an 'Iso':
  --
  -- @
  -- 'Optics.Re.re' :: 'Iso' s t a b -> 'Iso' b a t s
  -- @
  , mapping

  -- * Subtyping
  , An_Iso
  -- | <<diagrams/Iso.png Iso in the optics hierarchy>>
  )
  where

import Data.Tuple
import Data.Bifunctor
import Data.Coerce

import Optics.Internal.Concrete
import Optics.Internal.Optic
import Optics.Internal.Profunctor

-- | Type synonym for a type-modifying iso.
type Iso s t a b = Optic An_Iso NoIx s t a b

-- | Type synonym for a type-preserving iso.
type Iso' s a = Optic' An_Iso NoIx s a

-- | Build an iso from a pair of inverse functions.
--
-- If you want to build an 'Iso' from the van Laarhoven representation, use
-- @isoVL@ from the @optics-vl@ package.
iso :: (s -> a) -> (b -> t) -> Iso s t a b
iso f g = Optic (dimap f g)
{-# INLINE iso #-}

-- | Extract the two components of an isomorphism.
withIso :: Iso s t a b -> ((s -> a) -> (b -> t) -> r) -> r
withIso o k = case getOptic o (Exchange id id) of
  Exchange sa bt -> k sa bt
{-# INLINE withIso #-}

-- | Based on @ala@ from Conor McBride's work on Epigram.
--
-- This version is generalized to accept any 'Iso', not just a @newtype@.
--
-- >>> au (coerced1 @Sum) foldMap [1,2,3,4]
-- 10
--
-- You may want to think of this combinator as having the following, simpler
-- type:
--
-- @
-- au :: 'Iso' s t a b -> ((b -> t) -> e -> s) -> e -> a
-- @
au :: Functor f => Iso s t a b -> ((b -> t) -> f s) -> f a
au k = withIso k $ \sa bt f -> sa <$> f bt
{-# INLINE au #-}

-- | The opposite of working 'Optics.Setter.over' a 'Optics.Setter.Setter' is
-- working 'under' an isomorphism.
--
-- @
-- 'under' ≡ 'Optics.Setter.over' '.' 'Optics.Re.re'
-- @
under :: Iso s t a b -> (t -> s) -> b -> a
under k = withIso k $ \sa bt ts -> sa . ts . bt
{-# INLINE under #-}

----------------------------------------
-- Isomorphisms

-- | This can be used to lift any 'Iso' into an arbitrary 'Functor'.
mapping
  :: (Functor f, Functor g)
  => Iso    s     t     a     b
  -> Iso (f s) (g t) (f a) (g b)
mapping k = withIso k $ \sa bt -> iso (fmap sa) (fmap bt)
{-# INLINE mapping #-}

-- | Capture type constraints as an isomorphism.
--
-- /Note:/ This is the identity optic:
--
-- >>> :t view equality
-- view equality :: a -> a
equality :: (s ~ a, t ~ b) => Iso s t a b
equality = Optic id
{-# INLINE equality #-}

-- | Proof of reflexivity.
simple :: Iso' a a
simple = Optic id
{-# INLINE simple #-}

-- | Data types that are representationally equal are isomorphic.
--
-- >>> view coerced 'x' :: Identity Char
-- Identity 'x'
--
coerced :: (Coercible s a, Coercible t b) => Iso s t a b
coerced = Optic (lcoerce' . rcoerce')
{-# INLINE coerced #-}

-- | Type-preserving version of 'coerced' with type parameters rearranged for
-- TypeApplications.
--
-- >>> newtype MkInt = MkInt Int deriving Show
--
-- >>> over (coercedTo @Int) (*3) (MkInt 2)
-- MkInt 6
--
coercedTo :: forall a s. Coercible s a => Iso' s a
coercedTo = Optic (lcoerce' . rcoerce')
{-# INLINE coercedTo #-}

-- | Special case of 'coerced' for trivial newtype wrappers.
--
-- >>> over (coerced1 @Identity) (++ "bar") (Identity "foo")
-- Identity "foobar"
--
coerced1
  :: forall f s a. (Coercible s (f s), Coercible a (f a))
  => Iso (f s) (f a) s a
coerced1 = Optic (lcoerce' . rcoerce')
{-# INLINE coerced1 #-}

-- | The canonical isomorphism for currying and uncurrying a function.
--
-- @
-- 'curried' = 'iso' 'curry' 'uncurry'
-- @
--
-- >>> view curried fst 3 4
-- 3
--
curried :: Iso ((a, b) -> c) ((d, e) -> f) (a -> b -> c) (d -> e -> f)
curried = iso curry uncurry
{-# INLINE curried #-}

-- | The canonical isomorphism for uncurrying and currying a function.
--
-- @
-- 'uncurried' = 'iso' 'uncurry' 'curry'
-- @
--
-- @
-- 'uncurried' = 'Optics.Re.re' 'curried'
-- @
--
-- >>> (view uncurried (+)) (1,2)
-- 3
--
uncurried :: Iso (a -> b -> c) (d -> e -> f) ((a, b) -> c) ((d, e) -> f)
uncurried = iso uncurry curry
{-# INLINE uncurried #-}

-- | The isomorphism for flipping a function.
--
-- >>> (view flipped (,)) 1 2
-- (2,1)
--
flipped :: Iso (a -> b -> c) (a' -> b' -> c') (b -> a -> c) (b' -> a' -> c')
flipped = iso flip flip
{-# INLINE flipped #-}

-- | Given a function that is its own inverse, this gives you an 'Iso' using it
-- in both directions.
--
-- @
-- 'involuted' ≡ 'Control.Monad.join' 'iso'
-- @
--
-- >>> "live" ^. involuted reverse
-- "evil"
--
-- >>> "live" & involuted reverse %~ ('d':)
-- "lived"
involuted :: (a -> a) -> Iso' a a
involuted a = iso a a
{-# INLINE involuted #-}

-- | This class provides for symmetric bifunctors.
class Bifunctor p => Swapped p where
  -- |
  -- @
  -- 'swapped' '.' 'swapped' ≡ 'id'
  -- 'first' f '.' 'swapped' = 'swapped' '.' 'second' f
  -- 'second' g '.' 'swapped' = 'swapped' '.' 'first' g
  -- 'bimap' f g '.' 'swapped' = 'swapped' '.' 'bimap' g f
  -- @
  --
  -- >>> view swapped (1,2)
  -- (2,1)
  --
  swapped :: Iso (p a b) (p c d) (p b a) (p d c)

instance Swapped (,) where
  swapped = iso swap swap
  {-# INLINE swapped #-}

instance Swapped Either where
  swapped = iso (either Right Left) (either Right Left)
  {-# INLINE swapped #-}

-- $setup
-- >>> import Data.Functor.Identity
-- >>> import Data.Monoid
-- >>> import Optics.Core
