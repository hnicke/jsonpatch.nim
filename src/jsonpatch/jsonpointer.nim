import std/[strutils, sequtils, json]

type
  JsonPointer = object
    tokens*: seq[string]

proc toJsonPointer*(jsonPointer: string): JsonPointer =
  ## See https://tools.ietf.org/html/rfc6901
  let tokens = jsonPointer
    .split("/")
    .mapIt(it.multiReplace(("~1","/"), ("~0", "~")))
  return JsonPointer(tokens: tokens)

type JsonContainer* = enum
    JsonArray
    JsonObject

proc tokenContainerType*(token: string): JsonContainer =
    try:
        if token == "-" or (typeof(parseInt(token)) is int):
            return JsonArray
        else:
            raise newException(ValueError, "")
    except ValueError:
        return JsonObject

proc pointsToRoot*(p: JsonPointer): bool =
    return len(p.tokens) == 1 and p.tokens[0] == ""

iterator intermediateNodes*(p: JsonPointer): (int, string) =
    for idx, token in p.tokens[0..p.tokens.len-2]:
      yield (idx, token)

proc deleteAt(n: JsonNode, p: JsonPointer) =
  # TODO traverse node along pointer and unlink target node.
  # reuse traversal algorithm from jsonpatch.nim
