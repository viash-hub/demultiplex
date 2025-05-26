import java.util.zip.GZIPInputStream
import java.nio.file.Files
import java.io.BufferedInputStream

def is_empty(file_to_check){
  /* 
  Checks if a file has content
  */
  if (file_to_check.size() == 0) {
    return true
  }
  def input_stream = Files.newInputStream(file_to_check)
  def gzInputStream
  try {
    gzInputStream = new GZIPInputStream(new BufferedInputStream(input_stream))
  } catch (java.io.EOFException ex) {
    // This is not a gzipfile...
    return false
  }
  def read_one_byte = gzInputStream.read()
  return read_one_byte == -1
}

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
        def undetermined_sample_name = "Undetermined"
        def samples = [undetermined_sample_name]
        def original_id = id

        // Parse sample sheet for sample IDs
        println "Processing run information file ${sample_sheet}"
        csv_lines = sample_sheet.splitCsv(header: false, sep: ',')
        csv_lines.any { csv_items ->
          if (csv_items.isEmpty() || csv_items[0].startsWith("#")) {
            // skip empty or commented line 
            return
          }
          def possible_header = csv_items[0]
          def header = possible_header.find(/\[(.*)\]/){fullmatch, header_name -> header_name}
          if (header) {
            if (start_parsing) {
              // Stop parsing when encountering the next header
              println "Encountered next header '[${start_parsing}]', stopping parsing."
              return true
            }
            // [Data], [BCLConvert_Data] for illumina
            // [Samples] or sometimes [SAMPLES] for Element Biosciences
            if (header.toLowerCase() in ["data", "samples", "bclconvert_data"]) {
              println "Found header [${header}], start parsing."
              start_parsing = true
              return
            }
          }
          if (start_parsing) {
            if ( sample_id_column_index == null) {
              println "Looking for sample name column."
              sample_id_column_index = csv_items.findIndexValues{it == "Sample_ID" || it == "SampleName"}
              assert (!sample_id_column_index.isEmpty()):
                "Could not find column 'Sample_ID' (Illumina) or 'SampleName' " + 
                "(Element Biosciences) in run information! Found: ${sample_id_column_index}"
              assert sample_id_column_index.size() == 1, "Expected run information file to contain " + 
                "a column 'Sample_ID' or 'SampleName', not both. Found: ${sample_id_column_index}"
              sample_id_column_index = sample_id_column_index[0] 
              println "Found sample names column '${csv_items[sample_id_column_index]}'."
              return
            }
            def candidate_sample_id = csv_items[sample_id_column_index]
            if (candidate_sample_id?.trim()) { // Don't add empty csv entries.
              samples += csv_items[sample_id_column_index]
            }
          }
          // This return is important! (If 'true' is returned, the parsing stops.)
          return 
        }
        assert start_parsing: 
          "Sample information file does not contain [Data], [Samples] or [BCLConvert_Data] header!"
        assert samples.size() > 1:
          "Sample information file does not seem to contain any information about the samples!"
        println "Finished processing run information file, found samples: ${samples}."
        println "Looking for fastq files in ${state.input}."
        def allfastqs = state.input.listFiles().findAll{it.isFile() && it.name ==~ /^.+\.fastq.gz$/}
        println "Found ${allfastqs.size()} fastq files, matching them to the following samples: ${samples}."
        processed_samples = samples.collect { sample_id ->
          def forward_regex = ~/^${sample_id}_S(\d+)_(L(\d+)_)?R1_(\d+)\.fastq\.gz$/
          def reverse_regex = ~/^${sample_id}_S(\d+)_(L(\d+)_)?R2_(\d+)\.fastq\.gz$/
          // Sort is needed here because multiple lanes (_L00*_) might be present and they need to be in the same order in both lists
          def forward_fastq = state.input.listFiles().findAll{it.isFile() && it.name ==~ forward_regex}.sort()
          def reverse_fastq = state.input.listFiles().findAll{it.isFile() && it.name ==~ reverse_regex}.sort()
          assert forward_fastq && !forward_fastq.isEmpty(): "No forward fastq files were found for sample ${sample_id}. " +
            "All fastq files in directory: ${allfastqs.collect{it.name}}"
          assert (reverse_fastq.isEmpty() || (forward_fastq.size() == reverse_fastq.size())): 
            "Expected equal number of forward and reverse fastq files for sample ${sample_id}. " +
            "Found forward: ${forward_fastq} and reverse: ${reverse_fastq}."
          println "Found ${forward_fastq.size()} forward and ${reverse_fastq.size()} reverse " +
            "fastq files for sample ${sample_id}"

          assert sample_id == undetermined_sample_name || (forward_fastq.every{!is_empty(it)} && reverse_fastq.every{!is_empty(it)}):
            "A fastq file for sample '${sample_id}' appears to be empty!"
          def fastqs_state = [
            "fastq_forward": forward_fastq,
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