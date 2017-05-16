{-# LANGUAGE OverloadedStrings, DataKinds #-}

import Database.Cassandra.CQL
import Control.Monad
import Control.Monad.Catch
import Control.Monad.Trans (liftIO)
import Data.Int
import Data.ByteString.Char8 (ByteString)
import qualified Data.ByteString.Char8 as C
import Data.Set (Set)
import qualified Data.Set as S
import Data.Text (Text)
import qualified Data.Text as T
import Data.UUID
import System.Random

dropLists :: Query Schema () ()
dropLists = "drop table sets"

createLists :: Query Schema () ()
createLists = "create table sets (id uuid PRIMARY KEY, items set<text>)"

insert :: Query Write (UUID, Set Text) ()
insert = "insert into sets (id, items) values (?, ?)"

select :: Query Rows () (Set Text)
select = "select items from sets"

ignoreDropFailure :: Cas () -> Cas ()
ignoreDropFailure code = code `catch` \exc -> case exc of
    ConfigError _ _ -> return ()  -- Ignore the error if the table doesn't exist
    Invalid _ _ -> return ()
    _               -> throw exc

main = do
    --let auth = Just (PasswordAuthenticator "cassandra" "cassandra")
    let auth = Nothing
    pool <- newPool [("localhost", "9042")] "test" auth -- servers, keyspace, auth
    runCas pool $ do
        ignoreDropFailure $ liftIO . print =<< executeSchema QUORUM dropLists ()
        liftIO . print =<< executeSchema QUORUM createLists ()

        u1 <- liftIO randomIO
        u2 <- liftIO randomIO
        u3 <- liftIO randomIO
        executeWrite QUORUM insert (u1, S.fromList ["one", "two"])
        executeWrite QUORUM insert (u2, S.fromList ["hundred", "two hundred"])
        executeWrite QUORUM insert (u3, S.fromList ["dozen"])

        liftIO . print =<< executeRows QUORUM select ()
