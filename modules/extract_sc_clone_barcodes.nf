#!/usr/bin/env nextflow

process sc_get_unmapped_reads {
    label 'medium_mem'

    input:
        path bam_file

    output:
        path "${out_bam_file}"

    script:
        out_bam_file = "${bam_file.baseName}_reads_unmapped.bam"
    """
    sambamba view -t ${task.cpus} -F "unmapped" -f bam -o ${out_bam_file} ${bam_file}
    """
}

process sc_remove_low_qual_reads {
    label 'small_mem'
    
    input:
        path unmapped_bam

    output:
        path "${out_bam_file}"

    script:
        out_bam_file = "${unmapped_bam.baseName}_filtered.bam"

    """
    sc_remove_low_qual_reads.py ${unmapped_bam} ${params.phred_thres} ${out_bam_file}
    """
}

process sc_retain_reads_with_CB_tag {
    label 'medium_mem'

    input:
        path bam_file

    output:
        path "${out_bam_file}"

    script:
        out_bam_file = "${bam_file.baseName}_withCB.bam"
    
    """
    #!/usr/bin/bash
    sambamba view \
        -F "([CB] != null and [UB] != null)" \
        -t ${task.cpus} \
        -f bam \
        -o ${out_bam_file} \
        ${bam_file}
    """
}

process sc_split_unmapped_reads {
    label 'small_mem'

    input:
        path unmapped_bam 

    output:
        path "${outdir}/${unmapped_bam.baseName}_unmapped_chunk_*.fasta"

    script:
        outdir = "${unmapped_bam.baseName}_unmapped_chunks"
    """
    mkdir ${outdir}
    
    sc_split_reads.py \
        --input_bam_filename ${unmapped_bam} \
        --outdir ${outdir} \
        --n_chunks ${params.n_chunks}
    """
}

process sc_map_unmapped_reads {
    label "${params.mapping_process_profile}"

    input:
        path unmapped_fasta

    output:
        path "${unmapped_fasta.baseName}_reads_barcodes.txt"

    """
    #!/usr/bin/bash

    flexiplex \
            -x "${params.adapter_5prime}" \
            -b ${params.barcode_length_chr} \
            -u "" \
            -x "${params.adapter_3prime}" \
            -f ${params.adapter_edit_distance} \
            -e ${params.barcode_edit_distance} \
            -n ${unmapped_fasta.baseName} \
            -k ${params.clone_barcodes_reference} \
            -p ${task.cpus} \
            $unmapped_fasta
    
    """
}

process sc_merge_barcodes {
    label 'small_mem'

    input:
        path mapped_reads

    output:
        path "${outfile}"

    script:
        outfile = "clone_barcodes.csv"

    """
    sc_merge_clone_barcodes.py ${mapped_reads} ${outfile}
    """
}
