import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.atomic.AtomicBoolean

def date = new Date().format('yyyyMMdd_hhmmss')
def viash_config = java.nio.file.Paths.get("${moduleDir}/_viash.yaml")
def version = get_version(viash_config)

session = nextflow.Nextflow.getSession()
final service = session.publishDirExecutorService()


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
      | map {id, state ->
          def id1 = (state.plain_output) ? id : "${state.run_id}/${date}"
          def id2 = (state.plain_output) ? id : "${id1}_demultiplex_${version}"
          def prefix = (id2 == "run") ? "" : "${id2}/"
          def new_state = state + ["prefix": prefix]
          [id, new_state]
      }
      | publish.run(
        fromState: { id, state ->
          def prefix = state.prefix
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
        toState: { id, result, state -> [ "fastq_output": state.to_return.output, "prefix": state.prefix ] },
        directives: [
          publishDir: [
            path: "${params.publish_dir}", 
            overwrite: false,
            mode: "copy"
          ]
        ]
      )

has_published = new AtomicBoolean(false)

interval_ch = channel.interval('10s'){ i ->
  // Allow this channel to stop generating events based on a later signal
  if (has_published.get()) {
    return channel.STOP
  }
  i
}

await_ch = output_ch
  // Wait for demultiplexing processes to be done
  | toSortedList()
  // Create periodic events in order to check for the publishing to be done
  | combine(interval_ch)
  | until { event ->
    println("Checking if publishing has finished in service ${service}")
    def running_tasks = null
    if(service instanceof ThreadPoolExecutor) {
      def completed_tasks = service.getCompletedTaskCount()
      def task_count = service.getTaskCount()
      running_tasks = completed_tasks - task_count
    }
    else if( System.getenv('NXF_ENABLE_VIRTUAL_THREADS') ) {
      running_tasks = service.threadCount()
    }
    else {
      error("Publishing service of class ${service.getClass()} is not supported.")
    }
    
    if (running_tasks == 0) {
      println("Publishing has finished all current tasks. Continuing execution.")
      return true
    }
    println("Workflow is publishing. Waiting...")
    return false
  }
  | last()
  | map{ event ->
      // Signal to interval channel to stop generating events.
      has_published.compareAndSet(false, true)
      return event[0]
  }
  | map {id, state ->
      println("Creating transfer_complete.txt file.")
      def complete_file = file("${params.publish_dir}/${state.prefix}/transfer_completed.txt")
      complete_file.text = "" // This will create a file when it does not exist.
      [id, state]
  }
  | setState(["fastq_output"])


  emit:
    await_ch
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
