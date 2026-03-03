FROM python:3.12-slim

# Instala o locale pt_BR
RUN apt-get update && apt-get install -y locales && \
    sed -i '/pt_BR.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen pt_BR.UTF-8

ENV LANG pt_BR.UTF-8
ENV LANGUAGE pt_BR:pt
ENV LC_ALL pt_BR.UTF-8

# Define o diretorio de trabalho
WORKDIR /app

# Copia o codigo fonte e arquivos necessarios para o funcionamento da aplicação
COPY requirements.txt .
COPY ./img ./img/
COPY ./modelos_arquivos ./modelos_arquivos/
COPY ./models ./models/
COPY ./planilhas ./planilhas/
COPY ./services ./services/
COPY ./views ./views/
COPY ./app.py .
COPY ./db.py .
COPY ./funcoes.py .

# Instala as dependencias e libs necessarias
RUN pip install -r requirements.txt

# Exposição da porta onde a aolicação é executada
EXPOSE 8501

# Comando para executar a aplicação
CMD ["streamlit","run","app.py"]