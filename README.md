# Mini-POC: RAG + Multiagente (LangGraph + Chroma)

## Pré-requisitos
- Python 3.10+
- (A) Ollama com `ollama pull llama3.1` **ou** (B) OpenAI API (`OPENAI_API_KEY`)

## Como rodar
```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.sample .env   # ajuste se quiser usar OpenAI
# adicione textos a data/inbox/ (exemplos já incluídos)
python app.py --ingest --query "O que é arquitetura orientada a eventos e quando usar?"
```

Saída esperada: resposta concisa com seção **Fontes** referenciando `arquivo#chunk`.
