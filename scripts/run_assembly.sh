#!/bin/bash
set -e

# Argumentos: R1, R2, Threads, RAM, Assembler, DelRaw, DelTrim
READ1=$1; READ2=$2; THREADS=$3; MEMORY=$4; ASSEMBLER=$5; DEL_RAW=$6; DEL_TRIM=$7

# [FIX 1] Captura o PREFIX corretamente para arquivos com ou sem _1
PREFIX=$(basename "$READ1" | sed 's/_1\.fastq\.gz//; s/\.fastq\.gz//')

# [FIX 2] Tenta localizar os adaptadores automaticamente se o caminho padrão falhar
ADAPTERS="/usr/share/trimmomatic/TruSeq3-PE-2.fa"
if [ ! -f "$ADAPTERS" ]; then
    # Procura caminhos comuns do Conda/Linux
    ADAPTERS=$(find /opt /usr /home -name "TruSeq3-PE-2.fa" 2>/dev/null | head -n 1)
    [ -z "$ADAPTERS" ] && echo "❌ Erro: Arquivo de adaptadores não encontrado!" && exit 1
fi

# [FIX 5] Trimmomatic não suporta espaços no caminho do ILLUMINACLIP — copia para /tmp se necessário
CLEAN_ADAPTERS=false
if [[ "$ADAPTERS" == *" "* ]]; then
    ADAPTERS_TMP=$(mktemp /tmp/trimmomatic_adapters_XXXXXX.fa)
    cp "$ADAPTERS" "$ADAPTERS_TMP"
    ADAPTERS="$ADAPTERS_TMP"
    CLEAN_ADAPTERS=true
fi

mkdir -p 01_QC_Reports 02_Trimmed_Reads 03_Normalized_Reads 04_MultiQC_Report 05_Assembly_Results

echo "### [STEP 1] 📊 QC Inicial ###"
# [FIX 3] Usa a variável READ1 literal passada, sem assumir sufixos
if [ "$READ2" != "none" ] && [ -f "$READ2" ]; then
    fastqc --threads "$THREADS" -o 01_QC_Reports "$READ1" "$READ2"
else
    fastqc --threads "$THREADS" -o 01_QC_Reports "$READ1"
fi

echo "### [STEP 2] ✂️  Trimming ###"
if [ "$READ2" != "none" ] && [ -f "$READ2" ]; then
    trimmomatic PE -threads "$THREADS" -phred33 "$READ1" "$READ2" \
        02_Trimmed_Reads/${PREFIX}_1_paired.fastq.gz 02_Trimmed_Reads/${PREFIX}_1_unpaired.fastq.gz \
        02_Trimmed_Reads/${PREFIX}_2_paired.fastq.gz 02_Trimmed_Reads/${PREFIX}_2_unpaired.fastq.gz \
        ILLUMINACLIP:${ADAPTERS}:2:30:10 LEADING:20 TRAILING:20 SLIDINGWINDOW:4:20 MINLEN:50
    R1_FINAL="02_Trimmed_Reads/${PREFIX}_1_paired.fastq.gz"
    R2_FINAL="02_Trimmed_Reads/${PREFIX}_2_paired.fastq.gz"
else
    # [FIX 4] Trimmomatic para Single-End (Metagenômica)
    trimmomatic SE -threads "$THREADS" -phred33 "$READ1" 02_Trimmed_Reads/${PREFIX}_trimmed.fastq.gz \
        ILLUMINACLIP:${ADAPTERS}:2:30:10 LEADING:20 TRAILING:20 SLIDINGWINDOW:4:20 MINLEN:50
    R1_FINAL="02_Trimmed_Reads/${PREFIX}_trimmed.fastq.gz"
fi

echo "### [STEP 3] 🧬 Normalização ###"
if [[ "$ASSEMBLER" != "trinity" ]]; then
    if [ "$READ2" != "none" ] && [ -f "$READ2" ]; then
        bbnorm.sh in1="$R1_FINAL" in2="$R2_FINAL" out1=03_Normalized_Reads/${PREFIX}_1_norm.fastq.gz out2=03_Normalized_Reads/${PREFIX}_2_norm.fastq.gz target=100
        R1_ASM="03_Normalized_Reads/${PREFIX}_1_norm.fastq.gz"
        R2_ASM="03_Normalized_Reads/${PREFIX}_2_norm.fastq.gz"
    else
        bbnorm.sh in="$R1_FINAL" out=03_Normalized_Reads/${PREFIX}_norm.fastq.gz target=100
        R1_ASM="03_Normalized_Reads/${PREFIX}_norm.fastq.gz"
    fi
else
    R1_ASM="$R1_FINAL"; R2_ASM="$R2_FINAL"
fi

echo "### [STEP 4] 📈 MultiQC ###"
multiqc . -o 04_MultiQC_Report

# [FIX 6] Assemblers resolvem symlinks internamente (realpath) e passam paths para
# subprocessos como gzip sem aspas. Symlinks não resolvem o problema.
# Solução: hard links para inputs (realpath retorna o próprio path do hard link)
# e diretório de output temporário em $HOME (sem espaços), movido ao final.
WORKDIR_REAL="$(realpath .)"
CLEAN_ASM_HARD=false
USING_TMP_OUT=false
R1_FOR_ASM="$R1_ASM"
R2_FOR_ASM="${R2_ASM:-}"

if [[ "$WORKDIR_REAL" == *" "* ]]; then
    CLEAN_ASM_HARD=true
    USING_TMP_OUT=true
    # Hard links em $HOME: mesmo filesystem que o projeto, sem espaços no path.
    # realpath de um hard link retorna seu próprio path (não o original).
    ln "$(realpath "$R1_ASM")" "${HOME}/marauders_r1_$$.fastq.gz"
    R1_FOR_ASM="${HOME}/marauders_r1_$$.fastq.gz"
    if [ "$READ2" != "none" ] && [ -n "${R2_ASM:-}" ]; then
        ln "$(realpath "$R2_ASM")" "${HOME}/marauders_r2_$$.fastq.gz"
        R2_FOR_ASM="${HOME}/marauders_r2_$$.fastq.gz"
    else
        R2_FOR_ASM=""
    fi
    ASM_OUT_TMP="${HOME}/marauders_asm_out_$$"
fi

echo "### [STEP 5] 🏗️  Assembly Final com $ASSEMBLER ###"
case $ASSEMBLER in
    megahit)
        OUT="$( [ "$USING_TMP_OUT" == "true" ] && echo "$ASM_OUT_TMP" || echo "05_Assembly_Results/MEGAHIT_${PREFIX}" )"
        if [ -n "$R2_FOR_ASM" ]; then
            megahit -1 "$R1_FOR_ASM" -2 "$R2_FOR_ASM" -t "$THREADS" -m "$MEMORY" -o "$OUT"
        else
            megahit -r "$R1_FOR_ASM" -t "$THREADS" -m "$MEMORY" -o "$OUT"
        fi
        [ "$USING_TMP_OUT" == "true" ] && mv "$OUT" "05_Assembly_Results/MEGAHIT_${PREFIX}" ;;
    spades)
        OUT="$( [ "$USING_TMP_OUT" == "true" ] && echo "$ASM_OUT_TMP" || echo "05_Assembly_Results/SPADES_${PREFIX}" )"
        if [ -n "$R2_FOR_ASM" ]; then
            spades.py --careful -t "$THREADS" -m "$MEMORY" -o "$OUT" -1 "$R1_FOR_ASM" -2 "$R2_FOR_ASM"
        else
            spades.py --careful -t "$THREADS" -m "$MEMORY" -o "$OUT" -s "$R1_FOR_ASM"
        fi
        [ "$USING_TMP_OUT" == "true" ] && mv "$OUT" "05_Assembly_Results/SPADES_${PREFIX}" ;;
    trinity)
        OUT="$( [ "$USING_TMP_OUT" == "true" ] && echo "$ASM_OUT_TMP" || echo "05_Assembly_Results/TRINITY_${PREFIX}" )"
        if [ -n "$R2_FOR_ASM" ]; then
            Trinity --seqType fq --max_memory "${MEMORY}G" --CPU "$THREADS" --output "$OUT" --left "$R1_FOR_ASM" --right "$R2_FOR_ASM"
        else
            Trinity --seqType fq --max_memory "${MEMORY}G" --CPU "$THREADS" --output "$OUT" --single "$R1_FOR_ASM"
        fi
        [ "$USING_TMP_OUT" == "true" ] && mv "$OUT" "05_Assembly_Results/TRINITY_${PREFIX}" ;;
esac

# Limpeza automática baseada na seleção do Dashboard
[ "$DEL_RAW" == "s" ] && rm -f "${PREFIX}"*.fastq.gz
[ "$DEL_TRIM" == "s" ] && rm -rf 02_Trimmed_Reads
[ "$CLEAN_ADAPTERS" == "true" ] && rm -f "$ADAPTERS_TMP"
[ "$CLEAN_ASM_HARD" == "true" ] && rm -f "${HOME}/marauders_r1_$$.fastq.gz" "${HOME}/marauders_r2_$$.fastq.gz"

echo -e "\a\n✅ Pipeline Marauders finalizado com sucesso!"
