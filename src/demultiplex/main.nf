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
        }
      )
      // Gather input files from folder
      | map {id, state ->
        def newState = [:]
        if (!state.sample_sheet) {
          def sample_sheet = state.input.resolve("SampleSheet.csv")
          assert (sample_sheet && sample_sheet.isFile()): "Could not find 'SampleSheet.csv' file in input directory."
          newState["sample_sheet"] = sample_sheet
        }

        // Do not add InterOp to state because we generate the summary csv's in the next
        // step based on the run dir, not the InterOp dir.
        def interop_dir = state.input.resolve("InterOp")
        assert interop_dir.isDirectory(): "Expected InterOp directory to be present."

        def resultState = state + newState
        [id, resultState]
      }

      | interop_summary_to_csv.run(
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
            "input": [
              state.output_falco,
              state.interop_run_summary.getParent(),
              state.interop_index_summary.getParent()
            ],
            "output_report": state.output_multiqc,
            "cl_config": 'sp: {fastqc/data: {fn: "*_fastqc_data.txt"}}',
          ]
        },
        toState: { id, result, state ->
          state + [ "output_multiqc" : result.output_report ]
        },
        directives: [
          publishDir: [
            path: "${params.publish_dir}/my_foo/abc/def/",
            overwrite: false,
            mode: "copy"
          ]
        ]
      )

  emit:
    output_ch
}
