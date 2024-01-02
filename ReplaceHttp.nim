import std/json
import std/sequtils
import std/osproc
import std/sugar
import std/re
import unicode
import std/times
import prologue

type DictData* = ref object
  from_re*: re.Regex
  to*: string

var dict: seq[DictData]

proc load_dict*(path = "./dict.json"): seq[DictData] =
  try:
    var json_file = parseFile(path)

    var dict = json_file["dict"].getElems
    var dict_arr: seq[DictData];

    for dic in dict:
      var from_re = re(escapeRe(dic[0].getStr), flags = {reIgnoreCase, reStudy})
      var to = dic[1].getStr

      dict_arr.add(DictData(from_re: from_re, to: to))

    result = dict_arr

  except IOError, JsonParsingError:
    quit(1)
  except:
    quit(1)

proc engtokana(text: string): string {.gcsafe.} =
  var tmp_text = text
  {.gcsafe.}:
    for dic in dict:
      tmp_text = tmp_text.replace(dic.from_re, dic.to)

  result = tmp_text

proc onRequest*(ctx: Context): Future[void] {.async, gcsafe.} =
  try:
    var body = ctx.request.body.parseJson
    var tx = body["text"].getStr
    tx = engtokana(tx)
    var responce = %*{"text": tx}
    resp jsonResponse(responce)
  except:
    echo repr(getCurrentException())
    resp "error", Http400

proc main() {.async.} =
  echo "start"
  dict = load_dict()
  echo "dict loaded"

  var settings = newSettings(port = Port(2972))
  var app = newApp(settings = settings)
  app.addRoute("/replace", onRequest, HttpPost)
  app.run()

  echo "localhost:2972"


discard main()
