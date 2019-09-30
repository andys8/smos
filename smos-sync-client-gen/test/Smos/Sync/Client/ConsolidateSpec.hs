module Smos.Sync.Client.ConsolidateSpec
  ( spec
  ) where

import Test.Hspec
import Test.Validity

import Control.Monad
import qualified Data.Map as M
import Data.Mergeful
import Data.Mergeful.Timed
import qualified Data.Set as S
import Text.Show.Pretty

import Smos.Sync.API

import Smos.Sync.Client.Contents
import Smos.Sync.Client.ContentsMap (ContentsMap(..))
import Smos.Sync.Client.Sync

import Smos.Sync.Client.ContentsMap.Gen ()
import Smos.Sync.Client.Sync.Gen ()

spec :: Spec
spec = do
  describe "consolidateInitialSyncedItemsWithFiles" $ do
    it "contains all the contents that received from the server" $
      forAllValid $ \syncedItems ->
        forAllValid $ \contents -> do
          let cs' = consolidateInitialSyncedItemsWithFiles syncedItems contents
          unless
            (M.keysSet (makeAlreadySyncedMap syncedItems) `S.isSubsetOf`
             M.keysSet (contentsMapFiles $ makeContentsMap cs')) $
            expectationFailure $
            unlines
              [ "The items received from the server were not a subset of the resulting store"
              , "synced items from server:"
              , ppShow syncedItems
              , "consolidated store:"
              , ppShow cs'
              ]
    it "contains all the contents that are found locally" $
      forAllValid $ \syncedItems ->
        forAllValid $ \contents -> do
          let cs' = consolidateInitialSyncedItemsWithFiles syncedItems contents
          unless
            (M.keysSet (contentsMapFiles contents) `S.isSubsetOf`
             M.keysSet (contentsMapFiles $ makeContentsMap cs')) $
            expectationFailure $
            unlines
              [ "The contents found locally were not a subset of the resulting store"
              , "local contents:"
              , ppShow contents
              , "consolidated store:"
              , ppShow cs'
              ]
  describe "consolidateMetaMapWithFiles" $ do
    it "contains all the contents that are found locally" $
      forAllValid $ \syncedItems ->
        forAllValid $ \contents -> do
          let cs' = consolidateMetaMapWithFiles syncedItems contents
          unless
            (M.keysSet (contentsMapFiles contents) `S.isSubsetOf`
             M.keysSet (contentsMapFiles $ makeContentsMap cs')) $
            expectationFailure $
            unlines
              [ "The contents found locally were not a subset of the resulting store"
              , "local contents:"
              , ppShow contents
              , "consolidated store:"
              , ppShow cs'
              ]
    it "contains all the items that were added, marked as added" $
      forAllValid $ \syncedItems ->
        forAllValid $ \contents -> do
          let cs' = consolidateMetaMapWithFiles syncedItems contents
          let addedItems =
                map (uncurry SyncFile) $
                M.toList $ contentsMapFiles contents `M.difference` syncedItems
          M.elems (clientStoreAddedItems cs') `shouldBe` addedItems
    it "contains all the items that were changed, marked as unchanged" $
      forAllValid $ \syncedItems ->
        forAllValid $ \contents -> do
          let cs' = consolidateMetaMapWithFiles syncedItems contents
          let changedItems =
                M.mapMaybe id $
                M.intersectionWithKey
                  (\path sfm bs ->
                     if isUnchanged sfm bs
                       then Just (SyncFile path bs)
                       else Nothing)
                  syncedItems
                  (contentsMapFiles contents)
          M.elems (M.map timedValue $ clientStoreSyncedItems cs') `shouldBe` M.elems changedItems
    it "contains all the items that were changed, marked as changed" $
      forAllValid $ \syncedItems ->
        forAllValid $ \contents -> do
          let cs' = consolidateMetaMapWithFiles syncedItems contents
          let changedItems =
                M.mapMaybe id $
                M.intersectionWithKey
                  (\path sfm bs ->
                     if isUnchanged sfm bs
                       then Nothing
                       else Just (SyncFile path bs))
                  syncedItems
                  (contentsMapFiles contents)
          M.elems (M.map timedValue $ clientStoreSyncedButChangedItems cs') `shouldBe`
            M.elems changedItems
    it "contains all the items that were deleted, marked as deleted" $
      forAllValid $ \syncedItems ->
        forAllValid $ \contents -> do
          let cs' = consolidateMetaMapWithFiles syncedItems contents
          let deletedItems = syncedItems `M.difference` contentsMapFiles contents
              deletedItemsKeys = S.fromList $ M.elems $ M.map syncFileMetaUUID deletedItems
          M.keysSet (clientStoreDeletedItems cs') `shouldBe` deletedItemsKeys