module PostgREST.Types where
import           Protolude
import qualified GHC.Show
import qualified GHC.Read
import           Data.Aeson
import qualified Data.ByteString.Lazy as BL
import           Data.HashMap.Strict  as M
import           Data.Tree
import qualified Data.Vector          as V
import           PostgREST.RangeQuery (NonnegRange)
import           Network.HTTP.Types.Header (hContentType, Header)

-- | Enumeration of currently supported response content types
data ContentType = CTApplicationJSON | CTTextCSV | CTOpenAPI
                 | CTSingularJSON | CTOctetStream
                 | CTAny | CTOther ByteString deriving Eq

data ApiRequestError = ActionInappropriate
                     | InvalidBody ByteString
                     | InvalidRange
                     | ParseRequestError Text Text
                     | UnknownRelation
                     | NoRelationBetween Text Text
                     | UnsupportedVerb
                     deriving (Show, Eq)

data DbStructure = DbStructure {
  dbTables      :: [Table]
, dbColumns     :: [Column]
, dbRelations   :: [Relation]
, dbPrimaryKeys :: [PrimaryKey]
, dbProcs       :: M.HashMap Text ProcDescription
} deriving (Show, Eq)

data PgArg = PgArg {
  pgaName :: Text
, pgaType :: Text
, pgaReq  :: Bool
} deriving (Show, Eq)

data PgType = Scalar QualifiedIdentifier | Composite QualifiedIdentifier | Pseudo Text deriving (Eq, Show)

data RetType = Single PgType | SetOf PgType deriving (Eq, Show)

data ProcVolatility = Volatile | Stable | Immutable
  deriving (Eq, Show)

data ProcDescription = ProcDescription {
  pdName       :: Text
, pdArgs       :: [PgArg]
, pdReturnType :: RetType
, pdVolatility :: ProcVolatility
} deriving (Show, Eq)

type Schema = Text
type TableName = Text
type SqlQuery = Text
type SqlFragment = Text
type RequestBody = BL.ByteString

data Table = Table {
  tableSchema     :: Schema
, tableName       :: TableName
, tableInsertable :: Bool
} deriving (Show, Ord)

newtype ForeignKey = ForeignKey { fkCol :: Column } deriving (Show, Eq, Ord)

data Column =
    Column {
      colTable     :: Table
    , colName      :: Text
    , colPosition  :: Int32
    , colNullable  :: Bool
    , colType      :: Text
    , colUpdatable :: Bool
    , colMaxLen    :: Maybe Int32
    , colPrecision :: Maybe Int32
    , colDefault   :: Maybe Text
    , colEnum      :: [Text]
    , colFK        :: Maybe ForeignKey
    } deriving (Show, Ord)

type Synonym = (Column,Column)

data PrimaryKey = PrimaryKey {
    pkTable :: Table
  , pkName  :: Text
} deriving (Show, Eq)

data OrderDirection = OrderAsc | OrderDesc deriving (Eq)
instance Show OrderDirection where
  show OrderAsc  = "asc"
  show OrderDesc = "desc"

data OrderNulls = OrderNullsFirst | OrderNullsLast deriving (Eq)
instance Show OrderNulls where
  show OrderNullsFirst = "nulls first"
  show OrderNullsLast  = "nulls last"

data OrderTerm = OrderTerm {
  otTerm      :: Field
, otDirection :: Maybe OrderDirection
, otNullOrder :: Maybe OrderNulls
} deriving (Show, Eq)

data QualifiedIdentifier = QualifiedIdentifier {
  qiSchema :: Schema
, qiName   :: TableName
} deriving (Show, Eq)


data RelationType = Child | Parent | Many | Root deriving (Show, Eq)
data Relation = Relation {
  relTable    :: Table
, relColumns  :: [Column]
, relFTable   :: Table
, relFColumns :: [Column]
, relType     :: RelationType
, relLTable   :: Maybe Table
, relLCols1   :: Maybe [Column]
, relLCols2   :: Maybe [Column]
} deriving (Show, Eq)

-- | An array of JSON objects that has been verified to have
-- the same keys in every object
newtype PayloadJSON = PayloadJSON (V.Vector Object)
  deriving (Show, Eq)

unPayloadJSON :: PayloadJSON -> V.Vector Object
unPayloadJSON (PayloadJSON objs) = objs

data Proxy = Proxy {
  proxyScheme     :: Text
, proxyHost       :: Text
, proxyPort       :: Integer
, proxyPath       :: Text
} deriving (Show, Eq)

data Operator = Equals | Gte | Gt | Lte | Lt | Neq | Like | ILike | Is | IsNot |
                TSearch | Contains | Contained | In | NotIn deriving (Eq, Enum)

instance Show Operator where
  show op =  case op of
    Equals -> "eq"
    Gte -> "gte"
    Gt -> "gt"
    Lte -> "lte"
    Lt -> "lt"
    Neq -> "neq"
    Like -> "like"
    ILike -> "ilike"
    In -> "in"
    NotIn -> "notin"
    IsNot -> "isnot"
    Is -> "is"
    TSearch -> "@@"
    Contains -> "@>"
    Contained -> "<@"

instance Read Operator where
  readsPrec _ op =  case op of
    "eq" -> [(Equals, "")]
    "gte" -> [(Gte, "")]
    "gt" -> [(Gt, "")]
    "lte" -> [(Lte, "")]
    "lt" -> [(Lt, "")]
    "neq" -> [(Neq, "")]
    "like" -> [(Like, "")]
    "ilike" -> [(ILike, "")]
    "in" -> [(In, "")]
    "notin" -> [(NotIn, "")]
    "isnot" -> [(IsNot, "")]
    "is" -> [(Is, "")]
    "@@" -> [(TSearch, "")]
    "@>" -> [(Contains, "")]
    "<@" -> [(Contained, "")]
    _ -> []

opToSqlFragment :: Operator -> SqlFragment
opToSqlFragment op = case op of
  Equals -> "="
  Gte -> ">="
  Gt -> ">"
  Lte -> "<="
  Lt -> "<"
  Neq -> "<>"
  Like -> "LIKE"
  ILike -> "ILIKE"
  In -> "IN"
  NotIn -> "NOT IN"
  IsNot -> "IS NOT"
  Is -> "IS"
  TSearch -> "@@"
  Contains -> "@>"
  Contained -> "<@"

data Operation = Operation{ hasNot::Bool, expr::(Operator, Operand) } deriving (Eq, Show)
data Operand = VText Text | VTextL [Text] | VForeignKey QualifiedIdentifier ForeignKey deriving (Show, Eq)
type FieldName = Text
type JsonPath = [Text]
type Field = (FieldName, Maybe JsonPath)
type Alias = Text
type Cast = Text
type NodeName = Text
type SelectItem = (Field, Maybe Cast, Maybe Alias)
type Path = [Text]
data ReadQuery = Select { select::[SelectItem], from::[TableName], flt_::[Filter], order::Maybe [OrderTerm], range_::NonnegRange } deriving (Show, Eq)
data MutateQuery = Insert { in_::TableName, qPayload::PayloadJSON, returning::[FieldName] }
                 | Delete { in_::TableName, where_::[Filter], returning::[FieldName] }
                 | Update { in_::TableName, qPayload::PayloadJSON, where_::[Filter], returning::[FieldName] } deriving (Show, Eq)
data Filter = Filter { field::Field, operation::Operation } deriving (Show, Eq)
type ReadNode = (ReadQuery, (NodeName, Maybe Relation, Maybe Alias))
type ReadRequest = Tree ReadNode
type MutateRequest = MutateQuery
data DbRequest = DbRead ReadRequest | DbMutate MutateRequest

instance ToJSON Column where
  toJSON c = object [
      "schema"    .= tableSchema t
    , "name"      .= colName c
    , "position"  .= colPosition c
    , "nullable"  .= colNullable c
    , "type"      .= colType c
    , "updatable" .= colUpdatable c
    , "maxLen"    .= colMaxLen c
    , "precision" .= colPrecision c
    , "references".= colFK c
    , "default"   .= colDefault c
    , "enum"      .= colEnum c ]
    where
      t = colTable c

instance ToJSON ForeignKey where
  toJSON fk = object [
      "schema" .= tableSchema t
    , "table"  .= tableName t
    , "column" .= colName c ]
    where
      c = fkCol fk
      t = colTable c

instance ToJSON Table where
  toJSON v = object [
      "schema"     .= tableSchema v
    , "name"       .= tableName v
    , "insertable" .= tableInsertable v ]

instance Eq Table where
  Table{tableSchema=s1,tableName=n1} == Table{tableSchema=s2,tableName=n2} = s1 == s2 && n1 == n2

instance Eq Column where
  Column{colTable=t1,colName=n1} == Column{colTable=t2,colName=n2} = t1 == t2 && n1 == n2

-- | Convert from ContentType to a full HTTP Header
toHeader :: ContentType -> Header
toHeader ct = (hContentType, toMime ct <> "; charset=utf-8")

-- | Convert from ContentType to a ByteString representing the mime type
toMime :: ContentType -> ByteString
toMime CTApplicationJSON = "application/json"
toMime CTTextCSV         = "text/csv"
toMime CTOpenAPI         = "application/openapi+json"
toMime CTSingularJSON    = "application/vnd.pgrst.object+json"
toMime CTOctetStream     = "application/octet-stream"
toMime CTAny             = "*/*"
toMime (CTOther ct)      = ct
