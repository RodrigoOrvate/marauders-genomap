# Usar uma imagem base com suporte a X11 (para a interface gráfica)
FROM mambaorg/micromamba:latest

# Metadados
LABEL maintainer="evomol-lab"
LABEL version="1.0"

# Mudar para root para instalar dependências do sistema
USER root
RUN apt-get update && apt-get install -y \
    libgl1 \
    libegl1 \
    libdbus-1-3 \
    libxkbcommon-x11-0 \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-randr0 \
    libxcb-render-util0 \
    libxcb-xinerama0 \
    libxcb-xfixes0 \
    libxcb-shape0 \
    libxcb-cursor0 \
    wget \
    sudo \
    && apt-get clean

# Criar o ambiente de Bioinformática (baseado no seu setup.sh)
RUN micromamba create -y -n marauders -c conda-forge -c bioconda \
    python=3.10 \
    pyqt6 \
    fastqc \
    trimmomatic \
    bbmap \
    seqtk \
    samtools \
    megahit \
    spades \
    trinity \
    prodigal \
    hmmer \
    multiqc \
    sra-tools \
    pigz

# Configurar diretório de trabalho
WORKDIR /app
COPY . /app

# Garantir permissões nos scripts
RUN chmod +x /app/scripts/*.sh

# Variáveis de ambiente para o QT rodar no Docker
ENV QT_QPA_PLATFORM=xcb
ENV PATH="/opt/conda/envs/marauders/bin:$PATH"

# Comando para rodar a interface
CMD ["micromamba", "run", "-n", "marauders", "python", "marauders_gui.py"]
