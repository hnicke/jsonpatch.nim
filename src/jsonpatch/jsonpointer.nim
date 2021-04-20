import
  std/[json, strutils, strformat, sequtils, options]

type
  JsonPointer* = object
    segments: seq[string]
  JsonContainerKind* {.pure.} = enum
    JsonObject
    JsonArray
  JsonPointerKey* = object
    case kind*: JsonContainerKind
    of JsonObject: member*: string
    of JsonArray: idx*: int
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
  if p.segments.len > 0:
    result = "/" & p.segments.join("/")
  else:
    result = ""

proc parent*(jsonPointer: JsonPointer): Option[JsonPointer] =
  case jsonPointer.segments.len
  of 0: none(JsonPointer)
  else: some JsonPointer(segments: jsonPointer.segments[0..^2])

func parseChildKey*(node: JsonNode, pointerSegment: string): JsonPointerKey =
  case node.kind
  of JObject:
    result = JsonPointerKey(kind: JsonObject, member: pointerSegment)
  of JArray:
    result = JsonPointerKey(kind: JsonArray)
    if pointerSegment == "-":
      result.idx = node.len
    else:
      try:
        result.idx = parseInt(pointerSegment)
      except ValueError:
        raise newException(JsonPointerResolveError,
            &"Segment '{pointerSegment}' is not a valid array index")
  else: raise newException(Defect, &"Node is of kind {node.kind}, which is a not container node")

func leafSegment*(p: JsonPointer): Option[string] =
  ## Returns the last segment of the pointer, if it exists
  if p.segments.len > 0:
    return some p.segments[^1]

func resolve*(root: JsonNode, jsonPointer: JsonPointer): Option[JsonNode] =
  ## Returns the parent of the node which is represented by given JSON Pointer.
  var node = root
  for segment in jsonPointer.segments:
    let key = node.parseChildKey(segment)
    case key.kind
    of JsonObject:
      try:
        node = node[key.member]
      except KeyError:
        return none(JsonNode)
    of JsonArray:
      if 0 <= key.idx and key.idx < node.len:
        node = node[key.idx]
      else:
        return none(JsonNode)
  return some(node)


func resolve*(root: JsonNode, jsonPointer: string): Option[JsonNode] =
  ## Returns the parent of the node which is represented by given string, interpreted as JSON Pointer.
  root.resolve(jsonPointer.toJsonPointer())

func isRoot*(p: JsonPointer): bool = p.segments.len == 0

proc `%`*(p: JsonPointer): JsonNode = newJString($p)

proc to*[T: JsonPointer](node: JsonNode, t: typedesc[T]): T =
  case node.kind
  of JString:
    result = node.getStr().toJsonPointer()
  else:
    raise newException(JsonKindError, &"JsonPointer must be json string, but found '{node.kind}'")
