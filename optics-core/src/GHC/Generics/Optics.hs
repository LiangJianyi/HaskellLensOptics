{-# LANGUAGE PolyKinds #-}
-- |
-- Module: GHC.Generics.Optics
-- Description: Optics for types defined in "GHC.Generics".
--
-- Note: "GHC.Generics" exports a number of names that collide with "Optics"
-- (at least 'GHC.Generics.to').
--
-- You can use hiding or imports to mitigate this to an extent, and the
-- following imports, represent a fair compromise for user code:
--
-- @
-- import "Optics"
-- import "GHC.Generics" hiding (to)
-- import "GHC.Generics.Optics"
-- @
--
-- You can use 'generic' to replace 'GHC.Generics.from' and 'GHC.Generics.to'
-- from "GHC.Generics".
--
module GHC.Generics.Optics
  ( generic
  , generic1
  , _V1
  , _U1
  , _Par1
  , _Rec1
  , _K1
  , _M1
  , _L1
  , _R1
  ) where

import qualified GHC.Generics as GHC (to, from, to1, from1)
import GHC.Generics (Generic, Rep, Generic1, Rep1, (:+:) (..), V1, U1 (..),
                     K1 (..), M1 (..), Par1 (..), Rec1 (..))

import Optics.Iso
import Optics.Lens
import Optics.Prism

-- | Convert from the data type to its representation (or back)
--
-- >>> view (generic % re generic) "hello" :: String
-- "hello"
--
generic :: (Generic a, Generic b) => Iso a b (Rep a c) (Rep b c)
generic = iso GHC.from GHC.to
{-# INLINE generic #-}

-- | Convert from the data type to its representation (or back)
generic1 :: Generic1 f => Iso (f a) (f b) (Rep1 f a) (Rep1 f b)
generic1 = iso GHC.from1 GHC.to1
{-# INLINE generic1 #-}

_V1 :: Lens (V1 s) (V1 t) a b
_V1 = lens absurd absurd where
  absurd !_a = undefined
{-# INLINE _V1 #-}

_U1 :: Iso (U1 p) (U1 q) () ()
_U1 = iso (const ()) (const U1)
{-# INLINE _U1 #-}

_Par1 :: Iso (Par1 p) (Par1 q) p q
_Par1 = iso unPar1 Par1
{-# INLINE _Par1 #-}

_Rec1 :: Iso (Rec1 f p) (Rec1 g q) (f p) (g q)
_Rec1 = iso unRec1 Rec1
{-# INLINE _Rec1 #-}

_K1 :: Iso (K1 i c p) (K1 j d q) c d
_K1 = iso unK1 K1
{-# INLINE _K1 #-}

_M1 :: Iso (M1 i c f p) (M1 j d g q) (f p) (g q)
_M1 = iso unM1 M1
{-# INLINE _M1 #-}

_L1 :: Prism ((a :+: c) t) ((b :+: c) t) (a t) (b t)
_L1 = prism L1 reviewer
  where
  reviewer (L1 v) = Right v
  reviewer (R1 v) = Left (R1 v)
{-# INLINE _L1 #-}

_R1 :: Prism ((c :+: a) t) ((c :+: b) t) (a t) (b t)
_R1 = prism R1 reviewer
  where
  reviewer (R1 v) = Right v
  reviewer (L1 v) = Left (L1 v)
{-# INLINE _R1 #-}

-- $setup
-- >>> import Optics.Core
