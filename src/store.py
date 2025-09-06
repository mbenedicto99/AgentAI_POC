import os, uuid
import chromadb
from .emb import embed_texts

_client = chromadb.PersistentClient(path=os.getenv("CHROMA_PATH", ".chroma"))
_coll = _client.get_or_create_collection(name=os.getenv("CHROMA_COLLECTION","docs"))

def upsert_docs(chunks, source):
    ids, docs, metas = [], [], []
    for i, ch in enumerate(chunks):
        ids.append(f"{source}-{i}-{uuid.uuid4().hex[:8]}")
        docs.append(ch)
        metas.append({"source": source, "chunk": i})
    _coll.upsert(ids=ids, documents=docs, metadatas=metas, embeddings=embed_texts(docs))
    return len(ids)

def search(query, k=5):
    qemb = embed_texts([query])[0]
    res = _coll.query(query_embeddings=[qemb], n_results=k, include=['documents','metadatas','distances'])
    hits=[]
    for i in range(len(res['ids'][0])):
        hits.append({
            "text": res['documents'][0][i],
            "metadata": res['metadatas'][0][i],
            "score": float(res['distances'][0][i]),
        })
    return hits
