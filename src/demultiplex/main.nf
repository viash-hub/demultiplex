workflow run_wf {
  take:
    input_ch

  main:
    output_ch = input_ch

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
