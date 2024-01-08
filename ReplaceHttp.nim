import std/json
import std/sequtils
import std/sugar
import std/re
import unicode
import prologue
import std/dirs
import std/paths
import std/files
import algorithm
import std/math

type DictData* = ref object
  from_re*: re.Regex
  to*: string

var dict: seq[seq[DictData]]

proc slice_by_num[T](arr: seq[T], num: int): seq[seq[T]] =
  let result_len = toInt(ceil(arr.len / num))
  echo arr.len
  var result_arr = newSeq[seq[T]](result_len)
  for i in 0..<result_len:
    let x = i * num
    var y = (i + 1) * num - 1

    if(y >= arr.len):
      y = arr.len - 1

    result_arr[i] = arr[x..y]

  return result_arr

proc load_dict_dir*(dict_path = "./dicts/"): seq[seq[DictData]] =
  var path = paths.Path(dict_path)

  if(not dirExists(path)):
    echo "Dictionary file does not exist!"
    quit(1)

  var tmp_dict_arr: seq[seq[string]]

  for file in walkDirRec(path):
    if(not fileExists(file)): continue

    try:
      var json_file = parseFile(string(file))
      var dict = json_file["dict"].getElems

      for dic in dict:
        var s = dic[0].getStr
        if(not tmp_dict_arr.any((d) => d[0] == s)):
          tmp_dict_arr.add(@[dic[0].getStr, dic[1].getStr])

      echo "loaded dict file: " & string(file)
    except:
      echo "load err file: " & string(file)
      echo repr(getCurrentException())
      quit(1)

  tmp_dict_arr.sort((a, b) => cmp(a[0].toRunes.len, b[0].toRunes.len))
  tmp_dict_arr.reverse()

  var result_arr: seq[DictData]

  try:
    for dic in tmp_dict_arr:
      var from_re = re(escapeRe(dic[0]), flags = {reIgnoreCase, reStudy})

      result_arr.add(DictData(from_re: from_re, to: dic[1]))
  except:
    echo "regex parse error"
    echo repr(getCurrentException())
    quit(1)

  result = slice_by_num(result_arr, 2000)

proc test_patterns(patterns: seq[DictData], text: string): Future[seq[DictData]] =
  var result_future = newFuture[seq[DictData]]("test_patterns")

  var result_arr: seq[DictData]

  for p in patterns:
    if(text.contains(p.from_re)):
      result_arr.add(p)

  result_future.complete(result_arr)

  return result_future

proc engtokana(text: string): Future[string] {.async, gcsafe.} =
  var tmp_text = text

  var tests:seq[Future[seq[DictData]]]
  {.gcsafe.}:
    for dic in dict:
      tests.add(test_patterns(dic, text))

  var complete_tests = await all(tests)
  var replaces: seq[DictData]
  for t in complete_tests:
    replaces = concat(replaces, t)

  for m in replaces:
    tmp_text = tmp_text.replace(m.from_re, m.to)
  #{.gcsafe.}:
  #  for dic in dict:
  #    if(text.contains(dic.from_re)):
  #      replace_arr.add(dic)
      #tmp_text = tmp_text.replace(dic.from_re, dic.to)

  result = tmp_text

proc onRequest*(ctx: Context): Future[void] {.async, gcsafe.} =
  try:
    var body = ctx.request.body.parseJson
    var tx = body["text"].getStr
    tx = await engtokana(tx)
    var responce = %*{"text": tx}
    resp jsonResponse(responce)
  except:
    echo repr(getCurrentException())
    resp "error", Http400

proc main() {.async.} =
  echo "starting..."
  dict = load_dict_dir()
  echo "dict loaded"

  var settings = newSettings(port = Port(2972))
  var app = newApp(settings = settings)
  app.addRoute("/replace", onRequest, HttpPost)
  app.run()

discard main()
