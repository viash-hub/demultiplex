workflow run_wf {
  take:
    input_ch // Channel with [id, state] pairs

  main:
    output_ch = input_ch 
    
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

    | setState(["demultiplexer_output": "demultiplexer",
                "run_information_output": "run_information"])

  emit:
    output_ch
}