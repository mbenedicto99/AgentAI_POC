# 1) Dependências
sudo apt update && sudo apt install -y curl

# 2) Instalação
curl -fsSL https://ollama.com/install.sh | sh

# 3) Verificar serviço/CLI
ollama --version
sudo systemctl status ollama   # deve estar "active (running)"

# 4) Baixar e testar um modelo
ollama pull llama3.1
ollama run llama3.1
