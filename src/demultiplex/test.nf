nextflow.enable.dsl=2

include { demultiplex } from params.rootDir + "/target/nextflow/demultiplex/main.nf"

workflow test_wf {
  output_ch = Channel.fromList([
        [
          // sample_sheet: resources_test.resolve("bcl_convert_samplesheet.csv"),
          // input: resources_test.resolve("iseq-DI/"),
          sample_sheet: "https://raw.githubusercontent.com/nf-core/test-datasets/demultiplex/testdata/NovaSeq6000/SampleSheet.csv",
          input: "https://raw.githubusercontent.com/nf-core/test-datasets/demultiplex/testdata/NovaSeq6000/200624_A00834_0183_BHMTFYDRXX.tar.gz",
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
}
