nextflow.enable.dsl=2

include { demultiplex } from params.rootDir + "/target/nextflow/demultiplex/main.nf"

params.resources_test = params.rootDir + "/testData/"

workflow test_illumina {
  output_ch = Channel.fromList([
        [
          // sample_sheet: resources_test.resolve("bcl_convert_samplesheet.csv"),
          // input: resources_test.resolve("iseq-DI/"),
          //sample_sheet: "https://raw.githubusercontent.com/nf-core/test-datasets/demultiplex/testdata/NovaSeq6000/SampleSheet.csv",
          input: params.resources_test + "200624_A00834_0183_BHMTFYDRXX.tar.gz",
          publish_dir: "output_dir/",
        ]
      ])
    | map { state -> [ "run", state ] }
    | demultiplex.run(
        toState: { id, output, state ->
          output + [ orig_input: state.input ] }
      )
    | view { output ->
        assert output.size() == 2 : "outputs should contain two elements; [id, file]"
        "Output: $output"
      }
    | map {id, state ->
      assert state.output.isDirectory(): "Expected bclconvert output to be a directory"
      assert state.output_falco.isDirectory(): "Expected falco output to be a directory"
      assert state.output_multiqc.isFile(): "Expected multiQC output to be a file"
      fastq_files = state.output.listFiles().collect{it.name}
      assert ["Undetermined_S0_L001_R1_001.fastq.gz", "Sample23_S3_L001_R1_001.fastq.gz", 
        "sampletest_S4_L001_R1_001.fastq.gz", "Sample1_S1_L001_R1_001.fastq.gz", 
        "SampleA_S2_L001_R1_001.fastq.gz"].toSet() == fastq_files.toSet(): \
        "Output directory should contain the expected FASTQ files"
      fastq_files.each{
        assert it.length() != 0: "Expected FASTQ file to not be empty"
      }
    }
}

workflow test_bases2fastq {
  output_ch = Channel.fromList([
        [
          input: "http://element-public-data.s3.amazonaws.com/bases2fastq-share/bases2fastq-v2/20230404-bases2fastq-sim-151-151-9-9.tar.gz",
          publish_dir: "output_dir/",
        ]
      ])
    | map { state -> [ "run", state ] }
    | demultiplex.run(
        toState: { id, output, state ->
          output + [ orig_input: state.input ] }
      )
    | view { output ->
        assert output.size() == 2 : "outputs should contain two elements; [id, file]"
        "Output: $output"
      }
    | map {id, state ->
      assert state.output.isDirectory(): "Expected bases2fastq output to be a directory"
      assert state.output_falco.isDirectory(): "Expected falco output to be a directory"
      assert state.output_multiqc.isFile(): "Expected multiQC output to be a file"
    }
}
