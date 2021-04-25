import
  std/[unittest, json],
  jsonpatch

template diffCheck(d1, d2: JsonNode, maxOpCount: int = high(int)): untyped =
  let patch = diff(d1, d2)
  check patch.len <= maxOpCount
  echo "        ,.-> patch: ", %patch
  check d1.patch(patch) == d2

template diffCheck(d1, d2: untyped, maxOpCount: int = high(int)): untyped =
  let j1 = %* d1
  let j2 = %* d2
  j1.diffCheck(j2, maxOpCount)


suite "diff":
  # TODO
  # - assert the JsonPatch is never bigger than one replace operation containing d2
  # - support array operations

  test "no change":
    # TODO do we support scalar documents?
    for doc in @[
        %* {},
        %* {"foo": "bar"},
      ]:
      check diff(doc, doc) == initJsonPatch()

  test "member add":
    {}.diffCheck {"foo": "bar"}

  test "member remove":
    ( %* {"foo": "bar"}).diffCheck ( %* {})

  test "replace string with string":
    ( %* {"foo": "bar"}).diffCheck ( %* {"foo": "baz"})

  test "replace bool with string":
    ( %* {"foo": true}).diffCheck ( %* {"foo": "baz"})

  test "replace int with string":
    ( %* {"foo": 1}).diffCheck ( %* {"foo": "baz"})

  test "replace string with object":
    ( %* {"foo": "bar"}).diffCheck ( %* {"foo": {"bar": "bar"}})

  test "replace object with string":
    ( %* {"foo": {"bar": "baz"}}).diffCheck ( %* {"foo": "bar"})

  test "replace array with object":
    ( %* {"foo": ["bar"]}).diffCheck ( %* {"foo": {"bar": "baz"}})

  test "replace object with array":
    ( %* {"foo": {"bar": "baz"}}).diffCheck ( %* {"foo": ["bar"]})

  test "append item to array":
    ( %* ["foo"]).diffCheck ( %* ["foo", "bar"])

  test "append two items to array":
    ( %* ["foo"]).diffCheck ( %* ["foo", "bar", "baz"])

  test "remove item from array":
    ( %* ["foo", "bar"]).diffCheck ( %* ["bar"])

  test "remove two items from array":
    ( %* ["foo", "bar", "baz"]).diffCheck ( %* ["foo"])

  test "multiple occourences of same item in src and target array":
    ( %* ["foo", "bar"]).diffCheck ( %* ["foo", "bar", "bar"])

  test "replace item in array":
    ( %* ["foo", "bar"]).diffCheck ( %* ["for", "bar", "baz"])

  test "add member to object, nested in array":
    ( %* {"foo": [{"bar": "baz"}]}).diffCheck ( %* {"foo": [{"bar": "baz",
        "foobar": "foobaz"}]})

  test "insert item in middle of array":
    # patch: [{"op":"replace","path":"/1","value":"baz"},{"op":"add","path":"/2","value":"bar"}]
    # current patch looks like this:
    # - replace bar with baz
    # - add bar to end of array
    # wanted:
    # - add baz to array at index 1
    # possible solutions to achieve this:
    # - either optimize directly
    # - optimize afterwards (need more context data, e.g. 


    ( %* ["foo", "bar"]).diffCheck( %* ["foo", "baz", "bar"], 1)
