{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE CPP #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE UndecidableInstances #-}
{-# OPTIONS_HADDOCK not-home #-}

-- | Core optic types and subtyping machinery.
--
-- This module contains the core 'Optic' types, and the underlying
-- machinery that we need in order to implement the subtyping between
-- various different flavours of optics.
--
-- The composition operator for optics is also defined here.
--
-- This module is intended for internal use only, and may change without
-- warning in subsequent releases.
--
module Optics.Internal.Optic
  ( Optic(..)
  , Optic'
  , Optic_
  , Optic__
  , NoIx
  , WithIx
  , castOptic
  , (%)
  , (%%)
  , (%&)
  , IsProxy(..)
  -- * Labels
  , LabelOptic(..)
  , LabelOptic'
  -- * Re-exports
  , module Optics.Internal.Optic.Subtyping
  , module Optics.Internal.Optic.Types
  , module Optics.Internal.Optic.TypeLevel
  ) where

import Data.Function ((&))
import Data.Proxy (Proxy (..))
import Data.Type.Equality
import GHC.OverloadedLabels
import GHC.TypeLits

import Optics.Internal.Optic.Subtyping
import Optics.Internal.Optic.TypeLevel
import Optics.Internal.Optic.Types
import Optics.Internal.Profunctor

-- to make %% simpler
import Unsafe.Coerce (unsafeCoerce)

-- | An alias for an empty index-list
type NoIx = '[]

-- | Singleton index list
type WithIx i = '[i]

-- | Wrapper newtype for the whole family of optics.
--
-- The first parameter @k@ identifies the particular optic kind (e.g. 'A_Lens'
-- or 'A_Traversal').
--
-- The parameter @is@ is a list of types available as indices.  This will
-- typically be 'NoIx' for unindexed optics, or 'WithIx' for optics with a
-- single index. See the "Indexed optics" section of the overview documentation
-- in the @Optics@ module of the main @optics@ package for more details.
--
-- The parameters @s@ and @t@ represent the "big" structure,
-- whereas @a@ and @b@ represent the "small" structure.
--
newtype Optic (k :: *) (is :: [*]) s t a b = Optic
  { getOptic :: forall p i. Profunctor p
             => Optic_ k p i (Curry is i) s t a b
  }

-- | Common special case of 'Optic' where source and target types are equal.
--
-- Here, we need only one "big" and one "small" type. For lenses, this
-- means that in the restricted form we cannot do type-changing updates.
--
type Optic' k is s a = Optic k is s s a a

-- | Type representing the various kinds of optics.
--
-- The tag parameter @k@ is translated into constraints on @p@
-- via the type family 'Constraints'.
--
type Optic_ k p i j s t a b = Constraints k p => Optic__ p i j s t a b

-- | Optic internally as a profunctor transformation.
type Optic__ p i j s t a b = p i a b -> p j s t

-- | Proxy type for use as an argument to 'implies'.
--
data IsProxy (k :: *) (l :: *) (p :: * -> * -> * -> *) =
  IsProxy

-- | Explicit cast from one optic flavour to another.
--
-- The resulting optic kind is given in the first type argument, so you can use
-- TypeApplications to set it. For example
--
-- @
--  'castOptic' @'A_Lens' o
-- @
--
-- turns @o@ into a 'Optics.Lens.Lens'.
--
-- This is the identity function, modulo some constraint jiggery-pokery.
--
castOptic
  :: forall destKind srcKind is s t a b
  .  Is srcKind destKind
  => Optic srcKind  is s t a b
  -> Optic destKind is s t a b
castOptic (Optic o) = Optic (implies' o)
  where
    implies'
      :: forall p i
      .  Optic_ srcKind  p i (Curry is i) s t a b
      -> Optic_ destKind p i (Curry is i) s t a b
    implies' x = implies (IsProxy :: IsProxy srcKind destKind p) x
{-# INLINE castOptic #-}

-- | Compose two optics of compatible flavours.
--
-- Returns an optic of the appropriate supertype.  If either or both optics are
-- indexed, the composition preserves all the indices.
--
infixl 9 %
(%) :: (Is k m, Is l m, m ~ Join k l, ks ~ Append is js)
    => Optic k is s t u v
    -> Optic l js u v a b
    -> Optic m ks s t a b
o % o' = castOptic o %% castOptic o'
{-# INLINE (%) #-}

-- | Compose two optics of the same flavour.
--
-- Normally you can simply use ('%') instead, but this may be useful to help
-- type inference if the type of one of the optics is otherwise
-- under-constrained.
infixl 9 %%
(%%) :: forall k is js ks s t u v a b. ks ~ Append is js
     => Optic k is s t u v
     -> Optic k js u v a b
     -> Optic k ks s t a b
Optic o %% Optic o' = Optic oo
  where
    -- unsafeCoerce to the rescue, for a proof see below.
    oo :: forall p i. Profunctor p => Optic_ k p i (Curry ks i) s t a b
    oo = (unsafeCoerce
           :: Optic_ k p i (Curry is (Curry js i)) s t a b
           -> Optic_ k p i (Curry ks i           ) s t a b)
      (o . o')
{-# INLINE (%%) #-}

-- | Flipped function application, specialised to optics and binding tightly.
--
-- Useful for post-composing optics transformations:
--
-- >>> toListOf (ifolded %& ifiltered (\i s -> length s <= i)) ["", "a","abc"]
-- ["","a"]
--
infixl 9 %&
(%&) :: Optic k is s t a b
     -> (Optic k is s t a b -> Optic l js s' t' a' b')
     -> Optic l js s' t' a' b'
(%&) = (&)
{-# INLINE (%&) #-}


-- |
--
-- 'AppendProof' is a very simple class which provides a witness
--
-- @
-- foldr f (foldr f init xs) ys = foldr f init (ys ++ xs)
--    where f = (->)
-- @
--
-- It shows that usage of 'unsafeCoerce' in '(%%)' is, in fact, safe.
--
class Append xs ys ~ zs => AppendProof (xs :: [*]) (ys :: [*]) (zs :: [*])
  | xs ys -> zs, zs xs -> ys {- , zs ys -> xs -} where
  appendProof :: Proxy i -> Curry xs (Curry ys i) :~: Curry zs i

instance ys ~ zs => AppendProof '[] ys zs where
  appendProof _ = Refl

instance
  (Append (x : xs) ys ~ (x : zs), AppendProof xs ys zs
  ) => AppendProof (x ': xs) ys (x ': zs) where
  appendProof
    :: forall i. Proxy i
    -> Curry (x ': xs) (Curry ys i) :~: Curry (x ': zs) i
  appendProof i = case appendProof @xs @ys @zs i of
    Refl -> Refl

----------------------------------------
-- Labels

-- | Support for overloaded labels as optics. An overloaded label @#foo@ can be
-- used as an optic if there is an instance of @'LabelOptic' "foo" k s t a b@.
--
-- See "Optics.Label" for examples and further details.
--
class LabelOptic (name :: Symbol) k s t a b | name s -> k a
                                            , name t -> k b
                                            , name s b -> t
                                            , name t a -> s where
  -- | Used to interpret overloaded label syntax.  An overloaded label @#foo@
  -- corresponds to @'labelOptic' \@"foo"@.
  labelOptic :: Optic k NoIx s t a b

-- | If no instance matches, GHC tends to bury error messages "No instance for
-- LabelOptic..." within a ton of other error messages about ambiguous type
-- variables and overlapping instances which are irrelevant and confusing. Use
-- overlappable instance providing a custom type error to cut its efforts short.
instance {-# OVERLAPPABLE #-}
  (LabelOptic name k s t a b,
   TypeError
   ('Text "No instance for LabelOptic " ':<>: 'ShowType name
    ':<>: 'Text " " ':<>: QuoteType k
    ':<>: 'Text " " ':<>: QuoteType s
    ':<>: 'Text " " ':<>: QuoteType t
    ':<>: 'Text " " ':<>: QuoteType a
    ':<>: 'Text " " ':<>: QuoteType b
    ':$$: 'Text "  (maybe you forgot to define it or misspelled a name?)")
  ) => LabelOptic name k s t a b where
  labelOptic = error "unreachable"

-- | Type synonym for a type-preserving optic as overloaded label.
type LabelOptic' name k s a = LabelOptic name k s s a a

instance
  (LabelOptic name k s t a b, is ~ NoIx
  ) => IsLabel name (Optic k is s t a b) where
#if __GLASGOW_HASKELL__ >= 802
  fromLabel = labelOptic @name @k @s @t @a @b
#else
  fromLabel _ = labelOptic @name @k @s @t @a @b
#endif

-- $setup
-- >>> import Optics.Core
