import 
    std/[json, strutils, sequtils]
#[
# Ways to think about jsongraph manipulation
- would be nice to navigate upwards (know the parent..)

# Opertions to support
## Add
- traverse
- check existence
- insert
## Remove
- traverse
- check existence
- remove
## Move
- Add + Remove
## Copy
- lookup node at path + Add


# Forces
- json nodes don't know parent
  -> traversal only until before leaf
  -> add, remove, copy etc only needs parent all the time anyways!!

# usage:
document.add(node, jpointer)
document.delete(node, jpointer)

# optionally create non-existent on the fly
node, parent = document.traverse(jpointer, createNonExistent=false)
# downsides: weird interface, know-it-all, unwiedly

# transparent lightweight
document.traverse(jpointer)
iterator traverse(JsonNode, JsonPointer): JsonNode

iterator traverse(JsonNode, JsonPointer): JsonNode

initJsonPointer(JsonNode, string): JsonPointer

]#

type 
  JPointer = object
    document: JsonNode
    rawSegments: seq[string]
    # precompute sequence of JsonNode
    segments: seq[JsonNode]
    pointer: int

proc initJsonPointer*(document: JsonNode, jsonPointer: string): JPointer =
  ## See https://tools.ietf.org/html/rfc6901
  let segments = jsonPointer
    .split("/")
    .mapIt(it.multiReplace(("~1", "/"), ("~0", "~")))
  return JPointer(document: document, rawSegments: segments)

# proc hasNext(p: JPointer): bool
# proc nextExists(p: JPointer): bool
# proc next(p: JPointer): JsonNode

# proc targetNodeExists(p: JPointer): bool
G



