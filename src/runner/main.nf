def date = new Date().format('yyyyMMdd_hhmmss')

def viash_config = java.nio.file.Paths.get("$projectDir/../../../").toAbsolutePath().normalize().toString() + "/_viash.yaml"
def version = get_version(viash_config)

workflow run_wf {
  take:
    input_ch

  main:
    output_ch = input_ch
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
            "output": "fastq",
            "output_falco": "qc/fastqc",
            "output_multiqc": "qc/multiqc_report.html",
          ]
          if (state.run_information) {
            state_to_pass += ["output_run_information": state.run_information.getName()] 
          }
          state_to_pass
        },
        toState: { id, result, state ->
          state + result
        },
      )
      | publish.run(
        fromState: { id, state ->
          println(state.plain_output)
          def id1 = (state.plain_output) ? id : "${state.run_id}/${date}"
          def id2 = (state.plain_output) ? id : "${id1}_demultiplex_${version}"

          def fastq_output_1 = (id2 == "run") ? state.fastq_output : "${id2}/" + state.fastq_output
          def falco_output_1 = (id2 == "run") ? state.falco_output : "${id2}/" + state.falco_output
          def multiqc_output_1 = (id2 == "run") ? state.multiqc_output : "${id2}/" + state.multiqc_output
          def run_information_output_1 = (id2 == "run") ? "${state.output_run_information.getName()}" : "${id2}/${state.output_run_information.getName()}"

          if (id2 == "run") {
            println("Publising to ${params.publish_dir}")
          } else {
            println("Publising to ${params.publish_dir}/${id2}")
          }

          [
            input: state.output,
            input_falco: state.output_falco,
            input_multiqc: state.output_multiqc,
            input_run_information: state.output_run_information,
            output: fastq_output_1,
            output_falco: falco_output_1,
            output_multiqc: multiqc_output_1,
            output_run_information: run_information_output_1,
          ]
        },
        toState: { id, result, state -> [:] },
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

def get_version(inputFile) {
  def yamlSlurper = new groovy.yaml.YamlSlurper()
  def loaded_viash_config = yamlSlurper.parse(file(inputFile))
  def version = (loaded_viash_config.version) ? loaded_viash_config.version : "unknown_version"
  println("Version to be used: ${version}")
  return version
}
