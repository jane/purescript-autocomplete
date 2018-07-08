module Autocomplete.Store where

import Prelude

import Autocomplete.Types (Suggestions(..), SuggestionResults, Terms)
import Data.Array (length)
import Data.List (List(Nil, Cons), (:), take)
import Data.Map (Map, alter, insert, lookup, update)
import Data.Maybe (Maybe(..), fromMaybe, isJust)
import Data.Tuple (Tuple(Tuple))
import Debug.Trace (spy)

-- | Stores searched terms so they can be recalled without re-querying.
-- | Also stores the current search terms.
newtype SuggesterState a = SuggesterState { currentTerms :: Terms
                                          , currentResults :: (Suggestions a)
                                          , termsHistory :: List Terms
                                          , store :: Map Terms (Suggestions a) }

data SuggesterAction a
  = SetTerms Terms
  | AddResults (SuggestionResults a)

-- | Updates the suggestion store, updating either
-- | the current terms or search results.
updateSuggestions :: forall a. SuggesterAction a -> SuggesterState a -> SuggesterState a
updateSuggestions action (SuggesterState state) =
  case action of
    SetTerms terms ->
      let newHistory =
            if terms == ""
              then Nil
              else state.currentTerms : state.termsHistory
      in buildState (const terms $ spy ("update: " <> terms) "_") newHistory state.store
    AddResults (Tuple terms results) ->
      let newStore = alter (maybeUpdateTermResult (spy ("update: " <> show terms) $ Just results)) terms state.store
      in buildState state.currentTerms state.termsHistory newStore
  where
    maybeUpdateTermResult = case _, _ of
      Just a             , Nothing          -> Just a -- always use incoming value when none exists
      Just a@(Failed _ _), _                -> Just a -- always use "result" values containing data
      Just a@(Ready _)   , _                -> Just a -- "
      _                  , b                -> b      -- otherwise, no update

    buildState currentTerms termsHistory store = SuggesterState
      { currentTerms
      , termsHistory: take 100 termsHistory
      , store
      , currentResults:
          let
            results = lookupOrLoading currentTerms store
          in
            case length $ runSuggestions results of
              0 -> results `substitute` getNextBestResults termsHistory store
              _ -> results
      }

    runSuggestions (Loading a) = a
    runSuggestions (Failed _ a) = a
    runSuggestions (Ready a) = a

    substitute (Loading _) r = Loading r
    substitute (Failed e _) r = Failed e r
    substitute (Ready _) r = Ready r

    lookupOrLoading terms store =
      fromMaybe (Loading []) $ lookup terms store

    getNextBestResults Nil store = []
    getNextBestResults (Cons terms history) store =
      let results = runSuggestions $ lookupOrLoading terms store
      in case length results of
        0 -> getNextBestResults history store
        _ -> results

-- | Returns whether the store contains any form of results for the
-- | current terms.
hasSuggestionResults :: forall a. SuggesterState a -> Boolean
hasSuggestionResults (SuggesterState s) = isJust $ lookup s.currentTerms s.store

-- | Find the results for the store's current terms, or an empty result set.
getSuggestionResults :: forall a. SuggesterState a -> Suggestions a
getSuggestionResults (SuggesterState s) = s.currentResults
