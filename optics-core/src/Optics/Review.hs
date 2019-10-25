-- |
-- Module: Optics.Review
-- Description: A backwards 'Optics.Getter.Getter', i.e. a function.
--
-- A 'Review' is a backwards 'Optics.Getter.Getter', i.e. a
-- @'Review' T B@ is just a function @B -> T@.
--
module Optics.Review
  (
  -- * Formation
    Review

  -- * Introduction
  , unto

  -- * Elimination
  , review

  -- * Computation
  -- |
  --
  -- @
  -- 'review' ('unto' f) = f
  -- @

  -- * Subtyping
  , A_Review
  -- | <<diagrams/Review.png Review in the optics hierarchy>>
  )
  where

import Optics.Internal.Bi
import Optics.Internal.Optic
import Optics.Internal.Profunctor
import Optics.Internal.Tagged
import Optics.Internal.Utils

-- | Type synonym for a review.
type Review t b = Optic' A_Review NoIx t b

-- | Retrieve the value targeted by a 'Review'.
--
-- >>> review _Left "hi"
-- Left "hi"
review :: Is k A_Review => Optic' k is t b -> b -> t
review o = unTagged #. getOptic (castOptic @A_Review o) .# Tagged
{-# INLINE review #-}

-- | An analogue of 'Optics.Getter.to' for reviews.
unto :: (b -> t) -> Review t b
unto f = Optic (lphantom . rmap f)
{-# INLINE unto #-}

-- $setup
-- >>> import Optics.Core
