import
  std/[json, strutils, strformat, sequtils, deques, parseutils, options]

type
  JsonPointer* = object
    segments: seq[string]
    pointer: int
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
  else: some JsonPointer(segments: jsonPointer.segments[0..jsonPointer.segments.len - 2])

func resolveParent*(root: JsonNode, jsonPointer: JsonPointer): Option[JsonNode] =
  ## Returns the parent of the node which is represented by the JSON Pointer.
    # TODO handle case where pointer is empty: ""
    # if segment == "":
      # continue
  var segments = jsonPointer.segments.toDeque()
  var node = root
  while segments.len > 1:
    let segment = segments.popFirst()
    case node.kind
    of JObject:
      try:
        node = node[segment]
      except KeyError:
        # handle missing key
        assert false, "not implemented"
    of JArray:
      if segment == "-":
        if node.len > 0:
          node = node[node.len-1]
        else:
          return none(JsonNode)
      else:
        try:
          let idx = parseInt(segment)
          if 0 <= idx and idx < node.len:
            node = node[idx]
          else:
            return none(JsonNode)
        except ValueError:
          raise newException(JsonPointerResolveError,
             &"Segment '{segment}' is not a valid array index")
    else:
      assert false, "not implemented"
  return some(node)

