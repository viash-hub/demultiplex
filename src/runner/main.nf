def date = new Date().format('yyyyMMdd_hhmmss')

def viash_config = java.nio.file.Paths.get("${moduleDir}/_viash.yaml")
def version = get_version(viash_config)

workflow run_wf {
  take:
    input_ch

  main:
    output_ch = input_ch
      | map { id, state -> 
        // The argument names for this workflow and the demultiplex workflow may overlap
        // here, we store a copy in order to make sure to not accidentally overwrite the state.
        def new_state = state + [
          "fastq_output_workflow": state.fastq_output,
          "multiqc_output_workflow": state.multiqc_output,
          "sample_qc_output_workflow": state.sample_qc_output,
          "demultiplexer_logs_workflow": state.demultiplexer_logs,
        ]
        return [id, new_state]
      }
      // Extract the ID from the input.
      // If the input is a tarball, strip the suffix.
      | map{ id, state ->
        def id_with_suffix = state.input.getFileName().toString()
        [
          id,
          state + [ run_id: id_with_suffix - ~/\.(tar.gz|tgz|tar)$/ ]
        ]
      }
      | demultiplex.run(
        fromState: { id, state ->
          def state_to_pass = [
            "input": state.input,
            "run_information": state.run_information,
            "demultiplexer": state.demultiplexer,
            "skip_copycomplete_check": state.skip_copycomplete_check,
            "output": "$id/fastq",
            "output_sample_qc": "$id/qc/fastqc",
            "multiqc_output": "$id/qc/multiqc_report.html",
            "demultiplexer_logs": "$id/demultiplexer_logs",
          ]
          if (state.run_information) {
            state_to_pass += ["output_run_information": state.run_information.getName()] 
          }
          state_to_pass
        },
        toState: { id, result, state ->
          // Duplicate the results under its own key, makes it easier to access later.
          state + result + [ to_return: result ]
        },
      )
      | publish.run(
        fromState: { id, state ->
          println(state.plain_output)
          def id1 = (state.plain_output) ? id : "${state.run_id}/${date}"
          def id2 = (state.plain_output) ? id : "${id1}_demultiplex_${version}"

          def prefix = (id2 == "run") ? "" : "${id2}/"
          // These output names are determined by arguments.
          def fastq_output_1 = "${prefix}${state.fastq_output_workflow}"
          def sample_qc_output_1 = "${prefix}${state.sample_qc_output_workflow}"
          def multiqc_output_1 = "${prefix}${state.multiqc_output_workflow}"
          def demultiplexer_logs_output = "${prefix}${state.demultiplexer_logs_workflow}"
          // The name of the output file for the run information is determined by the input file name.
          def run_information_output_1 = "${prefix}${state.output_run_information.getName()}"

          println("Publising to ${params.publish_dir}/${prefix}")

          [
            input: state.output,
            input_sample_qc: state.output_sample_qc,
            input_multiqc: state.multiqc_output,
            input_run_information: state.output_run_information,
            input_demultiplexer_logs: state.demultiplexer_logs,
            output: fastq_output_1,
            output_sample_qc: sample_qc_output_1,
            output_multiqc: multiqc_output_1,
            output_run_information: run_information_output_1,
            output_demultiplexer_logs: demultiplexer_logs_output,
          ]
        },
        toState: { id, result, state -> [ fastq_output: state.to_return.output ] },
        directives: [
          publishDir: [
            path: "${params.publish_dir}", 
            overwrite: false,
            mode: "copy"
          ]
        ]
      )

  emit:
    output_ch
}

def get_version(input) {
  def inputFile = file(input)
  if (!inputFile.exists()) {
    // When executing tests
    return "unknown_version"
  }
  def yamlSlurper = new groovy.yaml.YamlSlurper()
  def loaded_viash_config = yamlSlurper.parse(inputFile)
  def version = (loaded_viash_config.version) ? loaded_viash_config.version : "unknown_version"
  println("Version of demultiplex to be used: ${version}")
  return version
}
