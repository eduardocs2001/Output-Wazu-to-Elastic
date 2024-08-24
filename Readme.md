# Documentação Replica dos dados wazuh > Elastic Search

nosso objetivo é realizar retenção de 5 anos do wazuh, porém sabemos que com todo esse tempo teríamos problema na infraestrutura do wazuh, com grande possibilidade de quebrar, para isso faremos um output para o elastic intermediando com o Logstash

![output wazuh to elastic.drawio.png](imagens_readme\output_wazuh_to_elastic.drawio.png)

Com isso criaremos o Logstash e o elastic em Docker recebendo dados do wazuh, teremos a seguinte infraestrutura:

![image.png](imagens_readme\image.png)

1. Primeiramente vamos criar a pasta dados onde será salvo as informações do elastic search para manter persistência, adapte conforme seu cenário
2. Criar o Dockerfile, onde vai montar uma imagem ubuntu com o logstash e a configuração uma vez que a imagem padrão do logstash fornecia diversas falhas
    1. Já instalei o tcpdump para poder debugar se precisar
    
    ```coq
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
    
    ```
    
3. Agora vamos criar o arquivo de configuração do Logstash
    1. logstash.conf
    
    ```coq
    input {
      syslog {
        port => 514
        type => "syslog"
      }
    }
    output {
      elasticsearch {
        hosts => ["http://172.20.0.10:9200"]
        index => "syslog-%{+YYYY.MM.dd}"
        user => "elastic"
        password => "sua_senha"
      }
    }
    
    ```
    
4. Agora vamos criar o docker-compose.yml no qual vai criar a imagem do logstash, criar a rede e subir os containers:
    1. 
    
    ```coq
    version: '3.7'
    
    services:
      elasticsearch:
        image: elasticsearch:8.5.3
        container_name: elasticsearch
        volumes:
          - ./dados:/usr/share/elasticsearch/data
        networks:
          lab_network:
            ipv4_address: 172.20.0.10
        ports:
          - "9200:9200"
          - "9300:9300"
        environment:
          - "discovery.type=single-node"
          - "ELASTIC_PASSWORD=sua_senha"
          - "xpack.security.enabled=true"
          - "xpack.security.authc.api_key.enabled=true"
    
      logstash:
        build: .
        container_name: logstash-container
        networks:
          lab_network:
            ipv4_address: 172.20.0.11
        ports:
          - "514:514/udp"
          - "9600:9600"
        volumes:
          - ./logstash.conf:/etc/logstash/conf.d/logstash.conf
        restart: unless-stopped
    
    networks:
      lab_network:
        driver: bridge
        ipam:
          config:
            - subnet: 172.20.0.0/24
    
    ```
    
5. Para dar o start use os seguinte comandos:
    1. 
    
    ```coq
        docker-compose build 
    ```
    
    ```coq
    docker-compose up -d  
    ```
    
6. Agora vamos aplicar a configuração no wazuh:
    1. ossec.conf
    
    ```coq
      <syslog_output>
        <server>192.168.15.128</server>
        <port>514</port>
        <level>3</level>
        <format>json</format>
      </syslog_output>
    ```
    

Após isso você já poderá ver os logs chegando no elastic, vamos analisar:

wazuh envoando dados para o logstash via syslog:

![image.png](imagens_readme\image 1.png)

Agora vamos ver os dados chegando no elastic:

![image.png](imagens_readme\image 2.png)

como podemos ver ele já criou o index de hoje