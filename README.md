# Marauders GenoMap 🧬

O **Marauders GenoMap** é uma plataforma integrada para bioinformática que automatiza o pipeline de análise genômica e transcriptômica. Utilizando uma interface gráfica (GUI) baseada em **PyQt6**, a ferramenta orquestra desde a aquisição de dados brutos até a predição proteica, eliminando a necessidade de lidar manualmente com extensas linhas de comando.

---

## 🛠️ Como o Marauders Funciona?

O software funciona como um **gerenciador de fluxo de trabalho (workflow manager)**. Ele conecta diferentes ferramentas consagradas na comunidade científica através de motores em Bash:

1.  **Entrada de Dados:** O usuário fornece um *Accession ID* do SRA.
2.  **Processamento:** O sistema executa sequencialmente o download (SRA Toolkit), controle de qualidade (FastQC/MultiQC), limpeza de reads (Trimmomatic/BBMap) e montagem (MEGAHIT/SPAdes/Trinity).
3.  **Saída:** O pipeline finaliza com a predição de genes (Prodigal) e busca de domínios (HMMER), entregando resultados prontos para análise biológica.

---

## 🐳 O Ecossistema Docker

### Por que usar Docker?
Instalar ferramentas de bioinformática pode ser complexo devido a dependências de sistema conflitantes. O **Dockerfile** deste projeto resolve isso criando um ambiente isolado e idêntico para todos os usuários, garantindo a reprodutibilidade científica.

### O Arquivo Bruto (Docker Hub)
Em vez de compilar todo o ambiente localmente (o que pode levar muito tempo), você pode baixar a **imagem binária completa** (o "arquivo bruto" de ~13GB) diretamente do Docker Hub. Esta imagem já contém todos os softwares científicos pré-configurados.

---

## 🚀 Tutorial de Uso

### Opção A: Usar a Imagem Pronta via GitHub (Recomendado)
Para obter a versão estável diretamente do GitHub Packages sem precisar compilar nada:
```bash
docker pull ghcr.io/rodrigoorvate/marauders-genomap:latest
```

### Opção B: Construir a Imagem Localmente
Se você clonou o repositório e deseja gerar a imagem na sua própria máquina (processo de build), execute:
```bash
# Na raiz do projeto, onde está o Dockerfile:
docker build -t marauders-genomap .
```

### 2. Configurar a Interface Gráfica (Linux)
Como o Marauders possui uma interface visual, você deve permitir que o container acesse o servidor de vídeo do seu sistema host:
```Bash
xhost +local:docker
```

### 3. Executar o Sistema
Utilize o comando abaixo para iniciar o programa. Note o uso de volumes para garantir que os resultados sejam salvos no seu computador e não apenas dentro do container:
```Bash
docker run -it --rm \
    --env="DISPLAY" \
    --volume="/tmp/.X11-unix:/tmp/.X11-unix:rw" \
    --volume="$(pwd):/app" \
    ghcr.io/rodrigoorvate/marauders-genomap:latest
```

---

## 📁 Estrutura do Ambiente Docker

  *Sistema Base: Linux configurado com todas as dependências de Bioinformática.

  *Volumes: O diretório local é mapeado para /app no container, permitindo que os arquivos de saída (genomas, gráficos e relatórios) permaneçam na sua máquina após o fechamento do software.

  *Recursos: O container está configurado para detectar automaticamente a RAM e os Threads do host, otimizando o processo de Assembly.

  *Volumes: O diretório local é mapeado para /app no container, permitindo que os arquivos de saída (genomas, gráficos e relatórios) permaneçam na sua máquina após o fechamento do software.

  *Vecursos: O container está configurado para detectar automaticamente a RAM e os Threads do host, otimizando o processo de Assembly.
