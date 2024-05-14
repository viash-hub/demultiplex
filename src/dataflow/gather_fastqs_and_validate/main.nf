workflow run_wf {
  take:
    input_ch

  main:
    output_ch = input_ch
      // Gather input files from BCL convert output folder
      | flatMap { id, state ->
        println "Processing sample sheet: $state.sample_sheet"
        def sample_sheet = state.sample_sheet
        def start_parsing = false
        def sample_id_column_index = null
        def samples = ["Undetermined"]
        def original_id = id

        // Parse sample sheet for sample IDs
        csv_lines = sample_sheet.splitCsv(header: false, sep: ',')
        csv_lines.any { csv_items ->
          if (csv_items.isEmpty()) {
            return
          }
          def possible_header = csv_items[0]
          def header = possible_header.find(/\[(.*)\]/){fullmatch, header_name -> header_name}
          if (header) {
            if (start_parsing) {
              // Stop parsing when encountering the next header
              return true
            }
            if (header == "Data") {
              start_parsing = true
            }
          }
          if (start_parsing) {
            if ( !sample_id_column_index ) {
              sample_id_column_index = csv_items.findIndexValues{it == "Sample_ID"}
              assert sample_id_column_index != -1:
              "Could not find column 'Sample_ID' in sample sheet!"
              return
            }
            samples += csv_items[sample_id_column_index]
          }
        }
        println "Looking for fastq files in ${state.input}."
        def allfastqs = state.input.listFiles().findAll{it.isFile() && it.name ==~ /^.+\.fastq.gz$/}
        println "Found ${allfastqs.size()} fastq files, matching them to the following samples: ${samples}."
        processed_samples = samples.collect { sample_id ->
          def forward_regex = ~/^${sample_id}_S(\d+)_(L(\d+)_)?R1_(\d+)\.fastq\.gz$/
          def reverse_regex = ~/^${sample_id}_S(\d+)_(L(\d+)_)?R2_(\d+)\.fastq\.gz$/
          def forward_fastq = state.input.listFiles().findAll{it.isFile() && it.name ==~ forward_regex}
          def reverse_fastq = state.input.listFiles().findAll{it.isFile() && it.name ==~ reverse_regex}
          assert forward_fastq : "No forward fastq files were found for sample ${sample_id}"
          assert forward_fastq.size() < 2:
          "Found multiple forward fastq files corresponding to sample ${sample_id}: ${forward_fastq}"
          assert reverse_fastq.size() < 2:
          "Found multiple reverse fastq files corresponding to sample ${sample_id}: ${reverse_fastq}."
          assert !forward_fastq.isEmpty():
          "Expected a forward fastq file to have been created correspondig to sample ${sample_id}."
          // TODO: if one sample had reverse reads, the others must as well.
          reverse_fastq = !reverse_fastq.isEmpty() ? reverse_fastq[0] : null
          def fastqs_state = [
            "fastq_forward": forward_fastq[0],
            "fastq_reverse": reverse_fastq,
            "_meta": [ "join_id": original_id ],
          ]
          [sample_id, fastqs_state]
        }
        println "Finished processing sample sheet."
        return processed_samples
      }

  emit:
    output_ch
}