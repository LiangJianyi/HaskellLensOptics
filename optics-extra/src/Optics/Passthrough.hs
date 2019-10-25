module Optics.Passthrough where

import Optics.Internal.Optic
import Optics.AffineTraversal
import Optics.Lens
import Optics.Prism
import Optics.Traversal
import Optics.View

class (Is k A_Traversal, ViewableOptic k r) => PermeableOptic k r where
  -- | Modify the target of an 'Optic' returning extra information of type 'r'.
  passthrough
    :: Optic k is s t a b
    -> (a -> (r, b))
    -> s
    -> (ViewResult k r, t)

instance PermeableOptic An_Iso r where
  passthrough = toLensVL
  {-# INLINE passthrough #-}

instance PermeableOptic A_Lens r where
  passthrough = toLensVL
  {-# INLINE passthrough #-}

instance PermeableOptic A_Prism r where
  passthrough o f s = withPrism o $ \bt sta -> case sta s of
    Left t -> (Nothing, t)
    Right a -> case f a of
      (r, b) -> (Just r, bt b)
  {-# INLINE passthrough #-}

instance PermeableOptic An_AffineTraversal r where
  passthrough o f s = withAffineTraversal o $ \sta sbt -> case sta s of
    Left t -> (Nothing, t)
    Right a -> case f a of
      (r, b) -> (Just r, sbt s b)
  {-# INLINE passthrough #-}

instance Monoid r => PermeableOptic A_Traversal r where
  passthrough = traverseOf
  {-# INLINE passthrough #-}
