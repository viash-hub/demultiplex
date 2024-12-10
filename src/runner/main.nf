def date = new Date().format('yyyyMMdd_hhmmss')

def viash_config = java.nio.file.Paths.get("$projectDir/../../../").toAbsolutePath().normalize().toString() + "/_viash.yaml"
def version = get_version(file(viash_config).text)

workflow run_wf {
  take:
    input_ch

  main:
    output_ch = input_ch
      | demultiplex.run(
        fromState: [
          "input": "input",
          "output": "fastq",
          "output_falco": "qc/fastqc",
          "output_multiqc": "qc/multiqc_report.html",
        ],
        toState: { id, result, state ->
          state + result
        },
      )
      | publish.run(
        fromState: { id, state ->
          def id1 = (params.add_date_time) ? "${id}_${date}" : id
          def id2 = (params.add_workflow_id) ? "${id1}_demultiplex_${version}" : id1
          def fastq_output_1 = (id == "run") ? state.fastq_output : "${id2}/" + state.fastq_output
          def falco_output_1 = (id == "run") ? state.falco_output : "${id2}/" + state.falco_output
          def multiqc_output_1 = (id == "run") ? state.multiqc_output : "${id2}/" + state.multiqc_output
          println("Publising to ${params.publish_dir}/${id2}")
          [
            input: state.output,
            input_falco: state.output_falco,
            input_multiqc: state.output_multiqc,
            output: fastq_output_1,
            output_falco: falco_output_1,
            output_multiqc: multiqc_output_1
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

def get_version(txt) {
  matcher = txt =~ /(?m)^version:\s+(.*)$/
  if (matcher.size() == 0) {
    println("No version found, setting version to 'unknown_version'")
    return "unknown_version"
  } else {
    println("Version found: ${matcher[0][1]}")
    return matcher[0][1]
  }
}
