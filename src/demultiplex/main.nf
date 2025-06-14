workflow run_wf {
  take:
    input_ch

  main:
    samples_ch = input_ch

      // untar input if needed
      | untar.run(
        directives: [label: ["lowmem", "lowcpu"]],
        runIf: {id, state ->
          def inputStr = state.input.toString()
          inputStr.endsWith(".tar.gz") || \
          inputStr.endsWith(".tar") || \
          inputStr.endsWith(".tgz") ? true : false
        },
        fromState: [
          "input": "input",
        ],
        toState: { id, result, state ->
          state + ["input": result.output]
        },
      )

      // detect demultiplexer
      | detect_demultiplexer.run(
        fromState: [
          "input": "input",
          "run_information": "run_information",
          "demultiplexer": "demultiplexer",
        ],
        toState: { id, result, state ->
          state + [
            "demultiplexer": result.demultiplexer_output,
            "run_information": result.run_information_output
          ]
        }
      )

      | interop_summary_to_csv.run(
        runIf: {id, state -> state.demultiplexer in ["bclconvert"]},
        directives: [label: ["lowmem", "verylowcpu"]],
        fromState: [
          "input": "input", 
        ],
        toState: [
          "interop_run_summary": "output_run_summary",
          "interop_index_summary": "output_index_summary",
        ]
      )
      // run bcl_convert
      | bcl_convert.run(
        runIf: {id, state -> state.demultiplexer in ["bclconvert"]},
        directives: [label: ["highmem", "midcpu"]],
        fromState: { id, state ->
          [
            bcl_input_directory: state.input,
            sample_sheet: state.run_information,
            output_directory: state.output,
            reports: state.demultiplexer_logs,
            logs: state.demultiplexer_logs,
          ]
        },
        toState: {id, result, state -> 
          def toAdd = [
            "output_demultiplexer" : result.output_directory,
            "run_id": id,
            "demultiplexer_logs": result.reports,
          ]
          def newState = state + toAdd
          return newState
        }
      )
      // run bases2fastq
      | bases2fastq.run(
        runIf: {id, state -> state.demultiplexer in ["bases2fastq"]},
        directives: [label: ["highmem", "midcpu"]],
        fromState: { id, state ->
          [
            "analysis_directory": state.input,
            "run_manifest": state.run_information,
            "output_directory": state.output,
            "report": state.demultiplexer_logs + "/report.html",
            "logs": state.demultiplexer_logs,
          ]
        },
        args: [
          "no_projects": true, // Do not put output files in a subfolder for project
          //"split_lanes": true,
          "legacy_fastq": true, // Illumina style output names
          "group_fastq": true, // No subdir per sample
        ],
        toState: {id, result, state -> 
          def toAdd = [
            "output_demultiplexer" : result.output_directory,
            "run_id": id,
            "demultiplexer_logs": result.logs,

          ]
          def newState = state + toAdd
          return newState
        }
      )
      | gather_fastqs_and_validate.run(
        fromState: [
          "input": "output_demultiplexer",
          "sample_sheet": "run_information",
        ],
        toState: [
          "fastq_forward": "fastq_forward",
          "fastq_reverse": "fastq_reverse",
        ],
      )

    output_ch = samples_ch 
      | fastqc.run(
        directives: [label: ["verylowcpu", "lowmem"]],
        fromState: {id, state ->
          def output_base = "$id/qc/fastqc/*"
          [
            "input": [state.fastq_forward, state.fastq_reverse],
            "html": "${output_base}_fastqc_report.html",
            "summary": "${output_base}_summary.txt",
            "data": "${output_base}_fastqc_data.txt",
          ]
        },
        toState: { id, result, state ->
          // The output directory for all files above is the same:
          // take the directory from one of the files
          state + [ "output_sample_qc": result.html[0].parent ]
        }
      )

      | combine_samples.run(
        fromState: { id, state ->
          [
            "id": state.run_id,
            "forward_input": state.fastq_forward,
            "reverse_input": state.fastq_reverse, 
            "sample_qc_dir": state.output_sample_qc,
          ]
        },
        toState: [
          "forward_fastqs": "output_forward",
          "reverse_fastqs": "output_reverse",
          "output_sample_qc": "output_sample_qc",
        ]
      )

      | multiqc.run(
        directives: [label: ["midcpu", "midmem"]],
        fromState: {id, state ->
          def new_state = [
            "input": state.output_sample_qc,
            "output_report": state.multiqc_output,
            "cl_config": 'sp: {fastqc/data: {fn: "*_fastqc_data.txt"}}'
          ]
          if (state.demultiplexer == "bclconvert") {
            new_state["input"] += [
              state.interop_run_summary.getParent(),
              state.interop_index_summary.getParent()
            ]
          }
          return new_state
        },
        toState: { id, result, state ->
          state + [ "multiqc_output" : result.output_report ]
        }
      )

      | setState(
        [
          //"_meta": "_meta",
          "output": "output_demultiplexer",
          "output_sample_qc": "output_sample_qc",
          "multiqc_output": "multiqc_output",
          "output_run_information": "run_information",
          "demultiplexer_logs": "demultiplexer_logs"
        ]
      )

  emit:
    output_ch
}
