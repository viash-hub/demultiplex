workflow run_wf {
  take:
    input_ch

  main:
    output_ch = input_ch
      | map { id, state ->
        def newEvent = [state.id, state + ["_meta": ["join_id": id]]]
        newEvent
      }
      | groupTuple(by: 0, sort: "hash")
      | map {run_id, states ->
        // Gather the following state for all samples
        def forward_fastqs = states.collect{it.forward_input}.flatten()
        def reverse_fastqs = states.collect{it.reverse_input}.findAll{it != null}.flatten()
        def sample_qc_dirs = states.collect{it.sample_qc_dir}
        
        def resultState = [
          "output_forward": forward_fastqs,
          "output_reverse": reverse_fastqs,
          "output_sample_qc": sample_qc_dirs,
          // The join ID is the same across all samples from the same run
          "_meta": ["join_id": states[0]._meta.join_id]
        ]
        return [run_id, resultState]
      }
  
  emit:
    output_ch
}