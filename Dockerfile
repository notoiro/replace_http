FROM nimlang/nim:onbuild

RUN mkdir /usr/src/app/dicts
RUN wget https://raw.githubusercontent.com/YTJVDCM/bep-eng-json/master/bep-eng.json -o /usr/src/app/dicts/bep-eng.json

ENTRYPOINT ["./ReplaceHttp"]
