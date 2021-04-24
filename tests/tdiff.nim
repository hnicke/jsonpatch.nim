import
  std/[unittest, json],
  jsonpatch

template diffCheck(d1, d2: JsonNode): untyped =
  let patch = diff(d1, d2)
  echo %patch
  check d1.patch(patch) == d2

template diffCheck(d1, d2: untyped): untyped =
  let j1 = %* d1
  let j2 =  %* d2
  j1.diffCheck j2
    

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
    (%* {"foo": "bar"}).diffCheck (%* {})

  test "replace string with string":
   (%* {"foo": "bar"}).diffCheck (%* {"foo": "baz"})

  test "replace bool with string":
   (%* {"foo": true}).diffCheck (%* {"foo": "baz"})

  test "replace int with string":
   (%* {"foo": 1}).diffCheck (%* {"foo": "baz"})

  test "replace string with object":
    (%* {"foo": "bar"}).diffCheck (%* {"foo": {"bar": "bar"}})

  test "replace object with string":
    (%* {"foo": {"bar": "baz"}}).diffCheck (%* {"foo": "bar"})

  test "replace array with object":
    (%* {"foo": ["bar"]}).diffCheck (%* {"foo": {"bar": "baz"}})

  test "replace object with array":
    (%* {"foo": {"bar": "baz"}}).diffCheck (%* {"foo": ["bar"]})

  test "append string to array":
    (%* {"foo": ["bar"]}).diffCheck (%* {"foo": ["bar", "baz"]})

#   test "multiple occourences of same item in src and target array":
#     (%* {"foo": ["bar", "bar"]}).diffCheck (%* {"foo": ["bar", "bar", "bar"]})

