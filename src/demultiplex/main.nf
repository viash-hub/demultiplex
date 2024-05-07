workflow run_wf {
  take:
    input_ch

  main:
    samples_ch = input_ch
      // untar input if needed
      | untar.run(
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
      // Gather input files from folder
      | map {id, state ->
        def interop_dir = state.input.resolve("InterOp")
        assert interop_dir.isDirectory(): "Expected InterOp directory to be present."
        def newState = state + ["interop_dir": interop_dir]
        [id, newState]
      }

      // run bcl_convert
      | bcl_convert.run(
        fromState: [
          "bcl_input_directory": "input",
          "sample_sheet": "sample_sheet",
          "output_directory": "output",
        ],
        toState: {id, result, state -> 
          def toAdd = [
            "output_bclconvert" : result.output_directory,
            "bclconvert_reports": result.reports,
            "run_id": id,
          ]
          def newState = state + toAdd
          return newState
        }
      )
      | gather_fastqs_and_validate.run(
        fromState: [
          "input": "output_bclconvert",
          "sample_sheet": "sample_sheet",
        ],
        toState: [
          "fastq_forward": "fastq_forward",
          "fastq_reverse": "fastq_reverse",
        ],
      )

    output_ch = samples_ch 
      | view {"Before combine_samples: $it"}
      | combine_samples.run(
        fromState: { id, state ->
          [
            "id": state.run_id,
            "forward_input": state.fastq_forward,
            "reverse_input": state.fastq_reverse, 
          ]
        },
        toState: [
          "forward_fastqs": "output_forward",
          "reverse_fastqs": "output_reverse",
        ]
      )
      | falco.run(
        fromState: {id, state ->
          reverse_fastqs_list = state.reverse_fastqs ? state.reverse_fastqs : []
          [
            "input": state.forward_fastqs + reverse_fastqs_list,
            "outdir": "${state.output_falco}",
            "summary_filename": null,
            "report_filename": null,
            "data_filename": null,
          ]
        },
        toState: { id, result, state ->
          state + [ "output_falco" : result.outdir ]
        },
      )
      | multiqc.run(
        fromState: {id, state ->
          [
            "input": [state.output_falco, state.interop_dir],
            "output_report": state.output_multiqc,
            "cl_config": 'sp: {fastqc/data: {fn: "*_fastqc_data.txt"}}',
          ]
        },
        toState: { id, result, state ->
          state + [ "output_multiqc" : result.output_report ]
        },
      )
      | setState(
        [
          "output": "output_bclconvert",
          "output_falco": "output_falco",
          "output_multiqc": "output_multiqc"
        ]
      )

  emit:
    output_ch
}
