# Imagem base para execucao do projeto
FROM python:3.13.12-slim-trixie

# Diretorio de trabalho do container
WORKDIR /app

# Copia os arquivos necessarios
COPY main.py .
COPY requirements.txt .

# Executa a instalacao das dependencias
RUN pip install -r requirements.txt

# Exposição da porta 8501 do container
EXPOSE 8501

# Inicia a aplicação
CMD ["streamlit", "run", "main.py"]