##[
This module implements JSON pointers according to [RFC 6901](https://tools.ietf.org/html/rfc6901).
]##

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
  JsonPointerError* = object of CatchableError

proc toJsonPointer*(jsonPointer: string): JsonPointer =
  ## See https://tools.ietf.org/html/rfc6901
  if not jsonPointer.startsWith("/") and jsonPointer.len > 0:
    raise newException(JsonPointerError,
        &"json pointer must start with slash, but was '{jsonPointer}'")
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

func parseChildKey*(node: JsonNode, segment: string): JsonPointerKey =
  case node.kind
  of JObject:
    result = JsonPointerKey(kind: JsonObject, member: segment)
  of JArray:
    result = JsonPointerKey(kind: JsonArray)
    if segment == "-":
      result.idx = node.len
    elif segment.startsWith("0") and segment.len > 1:
      raise newException(JsonPointerError,
                        &"Invalid segment '{segment}': leading zeroes are not allowed")
    else:
      try:
        let idx = parseInt(segment)
        if idx >= 0:
          result.idx = idx
        else:
          raise newException(JsonPointerError,
              &"Array index must not be negative")
      except ValueError:
        raise newException(JsonPointerError,
            &"Segment '{segment}' is not a valid array index")
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

func `/`*(p1: JsonPointer, p2: JsonPointer): JsonPointer =
  ## Concatenate pointers
  result.segments = p1.segments & p2.segments

func `/`*(p1: JsonPointer, p2: string): JsonPointer =
  ## Concatenate pointers while converting second argument to JsonPointer
  let p2 = if p2.startsWith("/"): p2 else: "/" & p2

  result.segments = p1.segments & p2.toJsonPointer().segments


proc `%`*(p: JsonPointer): JsonNode = newJString($p)

proc to*[T: JsonPointer](node: JsonNode, t: typedesc[T]): T =
  case node.kind
  of JString:
    result = node.getStr().toJsonPointer()
  else:
    raise newException(JsonKindError, &"JsonPointer must be json string, but found '{node.kind}'")
