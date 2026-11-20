#!/usr/bin/env python3
"""avail_asr — sidecar de reconocimiento de voz sin conexión para AVAILABLE.

Protocolo (compatible con scripts/autoload/ia_speech.gd):
  Uso:   avail_asr.exe <carpeta-modelo> <rate>
  stdin: comandos binarios [op:1 byte][len:u32 LE][payload]
         'R' = reiniciar/recomenzar escucha · 'A' = audio PCM16 mono · 'E' = fin de utterance · 'Q' = salir
  stdout: líneas 'READY', 'P {"partial": "..."}', 'F {"text": "..."}', 'ERR ...'

Licencias: vosk (Apache-2.0), vosk-model-small-es-0.3 (Apache-2.0). Sin red.
"""
import json
import sys

def main() -> int:
    if len(sys.argv) < 3:
        print("ERR usage: avail_asr <model-dir> <rate>", flush=True)
        return 2
    model_dir = sys.argv[1]
    try:
        rate = int(sys.argv[2])
    except ValueError:
        print("ERR bad rate", flush=True)
        return 2

    try:
        from vosk import Model, KaldiRecognizer, SetLogLevel
        SetLogLevel(-1)
        model = Model(model_dir)
    except Exception as e:  # noqa: BLE001
        print(f"ERR model: {e}", flush=True)
        return 1

    rec = KaldiRecognizer(model, rate)
    rec.SetWords(False)
    stdin = sys.stdin.buffer
    stdout = sys.stdout

    def out(line: str) -> None:
        stdout.write(line + "\n")
        stdout.flush()

    out("READY")

    def feed(data: bytes) -> None:
        if rec.AcceptWaveform(data):
            res = json.loads(rec.Result())
            out("F " + json.dumps({"text": res.get("text", "")}, ensure_ascii=False))
        else:
            part = json.loads(rec.PartialResult())
            txt = part.get("partial", "")
            if txt:
                out("P " + json.dumps({"partial": txt}, ensure_ascii=False))

    while True:
        hdr = stdin.read(5)
        if len(hdr) < 5:
            break
        op = hdr[0:1]
        ln = int.from_bytes(hdr[1:5], "little")
        payload = stdin.read(ln) if ln > 0 else b""
        if ln > 0 and len(payload) < ln:
            break
        if op == b"R":
            rec.Reset()
        elif op == b"A":
            try:
                feed(payload)
            except Exception as e:  # noqa: BLE001
                out(f"ERR feed: {e}")
        elif op == b"E":
            try:
                res = json.loads(rec.FinalResult())
            except Exception:  # noqa: BLE001
                res = {}
            out("F " + json.dumps({"text": res.get("text", "")}, ensure_ascii=False))
        elif op == b"Q":
            break
        else:
            out(f"ERR unknown op {op!r}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
