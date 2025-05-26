nextflow.enable.dsl=2

include { gather_fastqs_and_validate } from params.rootDir + "/target/nextflow/dataflow/gather_fastqs_and_validate/main.nf"


workflow test_gather_and_validate {
    output_ch = Channel.fromList([
        [
          id: "run1",
          input: params.rootDir + "/src/dataflow/gather_fastqs_and_validate/test_data/fastqs",
          sample_sheet: params.rootDir + "/src/dataflow/gather_fastqs_and_validate/test_data/samplesheet.csv",
        ]
    ])
    | map { state -> [state.id, state]}
    | gather_fastqs_and_validate.run(toState: ["fastq_forward", "fastq_reverse"])

    output_ch
        | toSortedList{a, b -> a[0] <=> b[0]}
        | view {"Output: $it"}
        | map {
            assert it.size() == 3: "Expected three fastq pairs"
            def first_pair = it[0][1]
            assert first_pair.fastq_forward.collect{it.name} == ["Undetermined_S1_R1_001.fastq.gz"] 
            assert first_pair.fastq_reverse.collect{it.name} == ["Undetermined_S1_R2_001.fastq.gz"] 
            def second_pair = it[1][1]
            assert second_pair.fastq_forward.collect{it.name} == ["sample1_S1_L001_R1_001.fastq.gz", "sample1_S1_L002_R1_001.fastq.gz"] 
            assert second_pair.fastq_reverse.collect{it.name} == ["sample1_S1_L001_R2_001.fastq.gz", "sample1_S1_L002_R2_001.fastq.gz"] 
            def undetermined_pair = it[2][1]
            assert undetermined_pair.fastq_forward.collect{it.name} == ["sample2_S1_L001_R1_001.fastq.gz"]
            assert undetermined_pair.fastq_reverse.collect{it.name} == ["sample2_S1_L001_R2_001.fastq.gz"]

        }
}


workflow test_undetermined_empty {
    output_ch = Channel.fromList([
        [
          id: "run1",
          input: params.rootDir + "/src/dataflow/gather_fastqs_and_validate/test_data/fastqs_undetermined_empty",
          sample_sheet: params.rootDir + "/src/dataflow/gather_fastqs_and_validate/test_data/samplesheet.csv",
        ]
    ])
    | map { state -> [state.id, state]}
    | gather_fastqs_and_validate.run(toState: ["fastq_forward", "fastq_reverse"])

    output_ch
        | toSortedList{a, b -> a[0] <=> b[0]}
        | view {"Output: $it"}
        | map {
            assert it.size() == 3: "Expected three fastq pairs"
            def first_pair = it[0][1]
            assert first_pair.fastq_forward.collect{it.name} == ["Undetermined_S1_R1_001.fastq.gz"] 
            assert first_pair.fastq_reverse.collect{it.name} == ["Undetermined_S1_R2_001.fastq.gz"] 
            def second_pair = it[1][1]
            assert second_pair.fastq_forward.collect{it.name} == ["sample1_S1_L001_R1_001.fastq.gz", "sample1_S1_L002_R1_001.fastq.gz"] 
            assert second_pair.fastq_reverse.collect{it.name} == ["sample1_S1_L001_R2_001.fastq.gz", "sample1_S1_L002_R2_001.fastq.gz"] 
            def undetermined_pair = it[2][1]
            assert undetermined_pair.fastq_forward.collect{it.name} == ["sample2_S1_L001_R1_001.fastq.gz"]
            assert undetermined_pair.fastq_reverse.collect{it.name} == ["sample2_S1_L001_R2_001.fastq.gz"]

        }
}

workflow test_without_index {
    output_ch = Channel.fromList([
        [
          id: "run1",
          input: params.rootDir + "/src/dataflow/gather_fastqs_and_validate/test_data/fastqs_undetermined_empty",
          sample_sheet: params.rootDir + "/src/dataflow/gather_fastqs_and_validate/test_data/samplesheet_no_index.csv",
        ]
    ])
    | map { state -> [state.id, state]}
    | gather_fastqs_and_validate.run(toState: ["fastq_forward", "fastq_reverse"])

    output_ch
        | toSortedList{a, b -> a[0] <=> b[0]}
        | view {"Output: $it"}
        | map {
            assert it.size() == 2: "Expected two fastq pairs"
            def first_pair = it[0][1]
            assert first_pair.fastq_forward.collect{it.name} == ["Undetermined_S1_R1_001.fastq.gz"] 
            assert first_pair.fastq_reverse.collect{it.name} == ["Undetermined_S1_R2_001.fastq.gz"] 

        }
}