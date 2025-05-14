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
      // Gather input files from folder
      | map {id, state ->
        def newState = [:]
        println("Provided run information: ${state.run_information} and demultiplexer: ${state.demultiplexer}")
        // No auto-detection of run information file (it is user provided),
        // in this case the demultiplexer should also be specified.
        assert (!state.run_information || state.demultiplexer): "When setting --run_information, " +
          "you must also provide a demultiplexer"

        if (!state.run_information) {
          println("Run information was not specified, auto-detecting...")
          // The supported_platforms hashmap must be a 1-on-1 mapping
          // Also, it's keys must be present in the 'choices' field
          // for the 'run_information' argument in the viash config.
          def supported_platforms = [
            "bclconvert": "SampleSheet.csv", // Illumina
            "bases2fastq": "RunManifest.csv" // Element Biosciences
          ]
          def found_sample_information = supported_platforms.collectEntries{demultiplexer, filename ->
            println("Checking if ${filename} can be found in input folder ${state.input}.")
            def resolved_filename = state.input.resolve(filename)
            if (!resolved_filename.isFile()) {
              resolved_filename = null
            }
            println("Result after looking for run information for ${demultiplexer}: ${resolved_filename}.")
            [demultiplexer, resolved_filename]
          }
          def demultiplexer = null
          def run_information = null
          found_sample_information.each{demultiplexer_candidate, file_path ->
            if (file_path) {
              // At this point, a candicate run information file was found.
              assert !run_information: "Autodetection of run information " +
                "(SampleSheet, RunManifest) failed: " +
                "multiple candidate files found in input folder. " +
                "Please specify one using --run_information."
              run_information = file_path
              demultiplexer = demultiplexer_candidate
            }
          }
          
          // When autodetecting, the run information should have been found
          assert run_information: "No run information file (SampleSheet, RunManifest) " +
            "found in input directory."

          // When autodetecting, the demultiplexer must be set if the run information was found
          assert demultiplexer: "State error: the demultiplexer should have been autodetected. " +
            "Please report this as a bug."

          // When autodetecting, the found demultiplexer must match
          // with the demultiplexer that the user has provided (in case it was provided).
          if (state.demultiplexer) {
            assert state.demultiplexer == demultiplexer, 
              "Requested to use demultiplexer ${state.demultiplexer} " +
              "but demultiplexer based on the autodetected run information "
              "file ${run_information} seems to indicate that the demultiplexer "
              "should be ${demultiplexer}. Either avoid specifying the demultiplexer "
              "or override the autodetection of the run information by providing "
              "the file."
          }
          println("Using run information ${run_information} and demultiplexer ${demultiplexer}")
          // At this point, the autodetected state can override the user provided state.
          newState = newState + [
            "run_information": run_information,
            "demultiplexer": demultiplexer,
          ]
        } // end auto-detection logic

        if (newState.demultiplexer in ["bclconvert"]) {
          // Do not add InterOp to state because we generate the summary csv's in the next
          // step based on the run dir, not the InterOp dir.
          def interop_dir = state.input.resolve("InterOp")
          assert interop_dir.isDirectory(): "Expected InterOp directory to be present."

          def copycomplete_file = state.input.resolve("CopyComplete.txt")
          assert (copycomplete_file.isFile() || state.skip_copycomplete_check): 
            "'CopyComplete.txt' file was not found!"
        }

        def resultState = state + newState
        [id, resultState]
      }

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
      | falco.run(
        directives: [label: ["verylowcpu", "lowmem"]],
        fromState: {id, state ->
          [
            "input": [state.fastq_forward, state.fastq_reverse],
            "outdir": "$id/qc/falco",
            "summary_filename": null,
            "report_filename": null,
            "data_filename": null,
          ]
        },
        toState: { id, result, state ->
          state + [ "output_falco" : result.outdir ]
        }
      )

      | combine_samples.run(
        fromState: { id, state ->
          [
            "id": state.run_id,
            "forward_input": state.fastq_forward,
            "reverse_input": state.fastq_reverse, 
            "falco_dir": state.output_falco,
          ]
        },
        toState: [
          "forward_fastqs": "output_forward",
          "reverse_fastqs": "output_reverse",
          "output_falco": "output_falco",
        ]
      )

      | multiqc.run(
        directives: [label: ["midcpu", "midmem"]],
        fromState: {id, state ->
          def new_state = [
            "input": state.output_falco,
            "output_report": state.output_multiqc,
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
          state + [ "output_multiqc" : result.output_report ]
        }
      )

      | setState(
        [
          //"_meta": "_meta",
          "output": "output_demultiplexer",
          "output_falco": "output_falco",
          "output_multiqc": "output_multiqc",
          "output_run_information": "run_information",
          "demultiplexer_logs": "demultiplexer_logs"
        ]
      )

  emit:
    output_ch
}
