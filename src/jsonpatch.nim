import json

type 
  JsonPatch* = object
  JsonPatchError* = object of CatchableError

func diff*(first: JsonNode, second: JsonNode): JsonPatch =
  JsonPatch()

func applyPatch*(document: JsonNode, patch: JsonPatch): JsonNode =
  document
