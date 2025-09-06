import os
from sentence_transformers import SentenceTransformer
_model = None

def embed_texts(texts):
    global _model
    if _model is None:
        name = os.getenv("EMBED_MODEL", "all-MiniLM-L6-v2")
        _model = SentenceTransformer(name)
    vecs = _model.encode(texts, normalize_embeddings=True)
    return [v.tolist() for v in vecs]
