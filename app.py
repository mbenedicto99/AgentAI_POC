import argparse
from dotenv import load_dotenv
from src.utils import read_txt_files, chunk, Timer
from src.store import upsert_docs
from src.graph import build_app

def ingest():
    total=0
    for name, text in read_txt_files():
        total += upsert_docs(chunk(text), source=name)
    return total

def main():
    load_dotenv()
    p = argparse.ArgumentParser()
    p.add_argument("--query", required=True, help="pergunta sobre os documentos")
    p.add_argument("--ingest", action="store_true", help="ingere arquivos em data/inbox/ antes")
    args = p.parse_args()

    if args.ingest:
        with Timer() as t: n = ingest()
        print(f"Ingestão: {n} chunks em {t.dt:.2f}s")

    app = build_app()
    with Timer() as t:
        out = app.invoke({"query": args.query})
    print("\n=== RESPOSTA ===\n")
    print(out["answer"])
    print(f"\nTempo total: {t.dt:.2f}s")

if __name__ == "__main__":
    main()
