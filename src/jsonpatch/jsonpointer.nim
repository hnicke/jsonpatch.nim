import std/[strutils, sequtils, json]

type
  JsonPointer = object
    tokens*: seq[string]

proc toJsonPointer*(jsonPointer: string): JsonPointer =
  ## See https://tools.ietf.org/html/rfc6901
  let tokens = jsonPointer
    .split("/")
    .mapIt(it.multiReplace(("~1", "/"), ("~0", "~")))
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
  # if p.pointsToRoot():
    # return value
  var current = n
  var parent: JsonNode
  # handle all intermediate nodes
  for idx, segment in p.intermediateNodes():
    if segment == "":
      continue
    case current.kind
    of JObject:
      let intermediateNode = current.getOrDefault(segment)
      if intermediateNode == nil:
        let nextSegment = jsonPointer.tokens[idx + 1]
        case nextSegment.tokenContainerType()
        of JsonArray:
          current.add(segment, newJArray())
        of JsonObject:
          current.add(segment, newJObject())
      parent = current
      current = current[segment]

# TODO traverse node along pointer and unlink target node.
  # reuse traversal algorithm from jsonpatch.nim

