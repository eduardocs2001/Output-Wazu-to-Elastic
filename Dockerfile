# Use a imagem base do Ubuntu
FROM ubuntu:20.04

# Mantenha o sistema atualizado e instale as dependências
RUN apt-get update && apt-get install -y \
    tcpdump \
    wget \
    apt-transport-https \
    openjdk-11-jre-headless \
    curl \
    gnupg \
    software-properties-common

# Adicionar a chave GPG e o repositório do Logstash
RUN wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add - && \
    echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" > /etc/apt/sources.list.d/elastic-7.x.list && \
    apt-get update && apt-get install -y logstash


# Copia a configuração do Logstash para o container
COPY logstash.conf /etc/logstash/conf.d/logstash.conf

# Expor a porta 514 para syslog e a 9600 para a API do Logstash (opcional)
EXPOSE 514 514/udp 9600

# Comando de inicialização do Logstash
CMD ["/usr/share/logstash/bin/logstash", "-f", "/etc/logstash/conf.d/logstash.conf"]
