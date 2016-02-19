-- | Helpers from purescript-signal tests
module Test.Signal
  ( expect
  , expectFn
  ) where

import Control.Monad.Aff (makeAff)
import Control.Monad.Eff.Exception (error)
import Control.Monad.Eff.Ref (REF, writeRef, readRef, newRef)
import Data.List (List(..), toList, fromList)
import Prelude (class Show, class Eq, bind, ($), show, (++), (/=), unit)
import Signal (Signal, (~>), runSignal)
import Test.Unit (TIMER, Assertion, timeout, success, failure)

expectFn :: forall e a. (Eq a, Show a) => Signal a -> Array a -> Assertion (ref :: REF | e)
expectFn sig vals = makeAff \fail win -> do
  remaining <- newRef vals
  let getNext val = do
        nextValArray <- readRef remaining
        let nextVals = toList nextValArray
        case nextVals of
          Cons x xs -> do
            if x /= val then fail $ error $ "expected " ++ show x ++ " but got " ++ show val
              else case xs of
                Nil -> win unit
                _ -> writeRef remaining (fromList xs)
          Nil -> fail $ error "unexpected emptiness"
  runSignal $ sig ~> getNext

expect :: forall e a. (Eq a, Show a) => Int -> Signal a -> Array a -> Assertion (ref :: REF | e)
expect time sig vals = timeout time $ expectFn sig vals
