workflow run_wf {
  take:
    input_ch

  main:
    output_ch = input_ch
      // untar input if needed
      | untar.run(
        runIf: {id, state -> 
          state.input.toString().endsWith(".tar.gz") ? true : false
        },
        fromState: [
          "input": "input",
        ],
        toState: { id, result, state ->
          [output: result.output]
        },
      )
      // run bcl_convert
      | bcl_convert.run(
          fromState: { id, state ->
            [
              bcl_input_directory: state.input,
              sample_sheet: state.sample_sheet,
            ]
          },
          toState: { id, result, state -> [ output: result.output_directory ] }
        )

  emit:
    output_ch
}
