import 
  json,
  options

type 
  JsonPointer = string

  JsonPatchOperationKind {.pure.} = enum
    Add = "add"
    Remove = "remove"
    Replace = "replace"
    Move = "move"
    Copy = "copy"
    Test = "test"

  # TODO use objects variants once https://github.com/nim-lang/RFCs/issues/368 is implemented
  JsonPatchOperation = object
    op: JsonPatchOperationKind
    value: Option[JsonNode]

  JsonPatch* = seq[JsonPatchOperation]

  JsonPatchError* = object of CatchableError


proc initJsonPatch(): JsonPatch =
  @[]

func diff*(first: JsonNode, second: JsonNode): JsonPatch =
  @[]

func applyPatch*(document: JsonNode, patch: JsonPatch): JsonNode =
  document
