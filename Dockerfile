FROM nimlang/nim:onbuild

RUN mkdir -p /usr/src/app/dicts
RUN wget https://raw.githubusercontent.com/YTJVDCM/bep-eng-json/master/bep-eng.json -O /usr/src/app/dicts/bep-eng.json

ENTRYPOINT ["./ReplaceHttp"]
