import
  std/[json, strutils, strformat, sequtils, options]

type
  JsonPointer* = object
    segments: seq[string]
  JsonPointerKey* = object
    case kind*: JsonNodeKind
    of JObject: member*: string
    of JArray: idx*: int
    else: discard
  JsonPointerResolveError* = object of CatchableError

proc toJsonPointer*(jsonPointer: string): JsonPointer =
  ## See https://tools.ietf.org/html/rfc6901
  var segments = jsonPointer
    .split("/")
    .mapIt(it.multiReplace(("~1", "/"), ("~0", "~")))
  if segments.len > 0:
    segments.delete(0)
  return JsonPointer(segments: segments)

proc `$`*(p: JsonPointer): string =
  p.segments.join("/")

proc parent*(jsonPointer: JsonPointer): Option[JsonPointer] =
  case jsonPointer.segments.len
  of 0: none(JsonPointer)
  else: some JsonPointer(segments: jsonPointer.segments[0..^2])

func parseChildKey*(node: JsonNode, pointerSegment: string): JsonPointerKey =
  result = JsonPointerKey(kind: node.kind)
  case node.kind
  of JObject:
    result.member = pointerSegment
  of JArray:
    if pointerSegment == "-":
      result.idx = node.len
    else:
      try:
        result.idx = parseInt(pointerSegment)
      except ValueError:
        raise newException(JsonPointerResolveError,
            &"Segment '{pointerSegment}' is not a valid array index")
  else: discard

func leafSegment*(p: JsonPointer): string = p.segments[^1]

func resolve*(root: JsonNode, jsonPointer: JsonPointer): Option[JsonNode] =
  ## Returns the parent of the node which is represented by given JSON Pointer.
  var node = root
  for segment in jsonPointer.segments:
    let key = node.parseChildKey(segment)
    case key.kind
    of JObject:
      try:
        node = node[key.member]
      except KeyError:
        return none(JsonNode)
    of JArray:
      if 0 <= key.idx and key.idx < node.len:
        node = node[key.idx]
      else:
        return none(JsonNode)
    else:
      # TODO implement
      assert false, "not implemented"
  return some(node)


func resolve*(root: JsonNode, jsonPointer: string): Option[JsonNode] =
  ## Returns the parent of the node which is represented by given string, interpreted as JSON Pointer.
  root.resolve(jsonPointer.toJsonPointer())

func pointsToRoot*(p: JsonPointer): bool = p.segments.len == 0

