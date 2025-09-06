import os
from typing import TypedDict, List
from langgraph.graph import StateGraph, END
from langchain_openai import ChatOpenAI
from langchain_community.chat_models import ChatOllama
from .store import search

def get_llm():
    provider = os.getenv("PROVIDER","ollama").lower()
    if provider == "openai":
        model = os.getenv("OPENAI_MODEL","gpt-4o-mini")
        return ChatOpenAI(model=model, temperature=0)
    model = os.getenv("OLLAMA_MODEL","llama3.1")
    return ChatOllama(model=model, temperature=0)

_llm = get_llm()

class GraphState(TypedDict):
    query: str
    notes: str
    answer: str
    citations: List[str]

def research_node(state: GraphState):
    q = state["query"]
    hits = search(q, k=5)
    context = "\n\n---\n".join([f"[{i}] {h['text']}" for i,h in enumerate(hits, start=1)])
    prompt = (
        "Você é um pesquisador. Leia os trechos abaixo e extraia até 8 bullets que respondam: "
        f"'{q}'. Cite os índices [n] relevantes.\n\n{context}"
    )
    resp = _llm.invoke(prompt)
    citations = [f"[{i}] {h['metadata']['source']}#{h['metadata']['chunk']}" for i,h in enumerate(hits, start=1)]
    return {"notes": str(resp.content), "citations": citations}

def write_node(state: GraphState):
    q, notes = state["query"], state["notes"]
    prompt = (
        f"Com base nas anotações, escreva resposta concisa (<=200 palavras) para: {q}. "
        f"Inclua 'Fontes' com as citações.\n\nAnotações:\n{notes}\n"
    )
    resp = _llm.invoke(prompt)
    return {"answer": str(resp.content)}

def build_app():
    g = StateGraph(GraphState)
    g.add_node("research", research_node)
    g.add_node("write", write_node)
    g.set_entry_point("research")
    g.add_edge("research", "write")
    g.add_edge("write", END)
    return g.compile()
