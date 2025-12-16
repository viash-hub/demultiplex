import java.nio.file.Files
import nextflow.exception.WorkflowScriptErrorException

// Create temporary directory for the publish_dir if it is not defined
if (params.containsKey("publish_dir") && params.publishDir) {
    params.publish_dir = params.publishDir
}

if (!params.containsKey("publish_dir")) {
    def tempDir = Files.createTempDirectory("demultiplex_runner_integration_test")
    println "Created temp directory: $tempDir"
    // Register shutdown hook to delete it on JVM exit
    Runtime.runtime.addShutdownHook(new Thread({
        try {
            // Delete directory recursively
            Files.walk(tempDir)
                .sorted(Comparator.reverseOrder())
                .forEach { Files.delete(it) }
            println "Deleted temp directory: $tempDir"
        } catch (Exception e) {
            println "Failed to delete temp directory: $e"
        }
    }))
    params.publish_dir = tempDir.toString()
}
// The module inherits the parameters defined before the include statement, 
// therefore any parameters set afterwards will not be used by the module.

include { runner } from params.rootDir + "/target/nextflow/runner/main.nf"
params.resources_test = params.rootDir + "/testData/"

workflow test {
    output_ch = Channel.fromList([
        [
          id: "test",
          input: params.resources_test + "200624_A00834_0183_BHMTFYDRXX.tar.gz",
        ]
    ])
    | map {event -> [event.id, event] }
    | runner.run(
        fromState: {id, state -> state }
    )
    
    all_events_ch = output_ch
      | toSortedList()
      | map{states ->
        assert states.size() == 1
      }

    output_ch 
      | map {id, state ->
        assert id == "test"
        assert state.fastq_output.isDirectory()
        assert state.sample_qc_output.isDirectory()
        assert state.multiqc_output.isFile()
        assert state.demultiplexer_logs.isDirectory()
      }

    workflow.onComplete = {
        try {
            // Nexflow only allows exceptions generated using the 'error' function (which throws WorkflowScriptErrorException).
            // So in order for the assert statement to work (or allow other errors to let the tests to fail)
            // We need to wrap these in WorkflowScriptErrorException. See https://github.com/nextflow-io/nextflow/pull/4458/files
            // The error message will show up in .nextflow.log
            def publish_subdir = file("${params.publish_dir}/test")
            assert publish_subdir.isDirectory() 
            def all_files = publish_subdir.listFiles()
            assert all_files.size() == 1
            def publish_dir = file(all_files[0])
            // version can be unknown_version (local tests) or actual version configured in _viash.yaml
            // with the new approach to fetching the version from _viash.yaml, this will be the branch name during CI builds
            // Disabling this test temporarily and creating an issue for it
            // assert publish_dir.name.endsWith("_demultiplex_unknown_version")
            def published_items = publish_dir.listFiles()
            assert published_items.size() == 6
            assert published_items.collect{it.name}.toSet() == ["demultiplexer_logs", "fastq", "qc", "SampleSheet.csv", "params.yaml", "transfer_completed.txt"].toSet()
            def fastqc_files = publish_dir.resolve("qc/fastqc").listFiles()
            assert fastqc_files.collect{it.name}.toSet() == [
                "Sample1_S1_L001_R1_001.fastq.gz_fastqc_data.txt",
                "Sample1_S1_L001_R1_001.fastq.gz_fastqc_report.html",
                "Sample1_S1_L001_R1_001.fastq.gz_summary.txt",
                "Sample23_S3_L001_R1_001.fastq.gz_fastqc_data.txt",
                "Sample23_S3_L001_R1_001.fastq.gz_fastqc_report.html",
                "Sample23_S3_L001_R1_001.fastq.gz_summary.txt",
                "SampleA_S2_L001_R1_001.fastq.gz_fastqc_data.txt",
                "SampleA_S2_L001_R1_001.fastq.gz_fastqc_report.html",
                "SampleA_S2_L001_R1_001.fastq.gz_summary.txt",
                "sampletest_S4_L001_R1_001.fastq.gz_fastqc_data.txt",
                "sampletest_S4_L001_R1_001.fastq.gz_fastqc_report.html",
                "sampletest_S4_L001_R1_001.fastq.gz_summary.txt",
                "Undetermined_S0_L001_R1_001.fastq.gz_fastqc_data.txt",
                "Undetermined_S0_L001_R1_001.fastq.gz_fastqc_report.html",
                "Undetermined_S0_L001_R1_001.fastq.gz_summary.txt"
            ].toSet()
            assert publish_dir.resolve("qc/multiqc_report.html").exists()
            def fastq_files = publish_dir.resolve("fastq").listFiles()
            assert fastq_files.collect{it.name}.toSet() == [
                "Sample1_S1_L001_R1_001.fastq.gz",
                "Sample23_S3_L001_R1_001.fastq.gz",
                "SampleA_S2_L001_R1_001.fastq.gz",
                "sampletest_S4_L001_R1_001.fastq.gz",
                "Undetermined_S0_L001_R1_001.fastq.gz"
            ].toSet()
            assert publish_dir.resolve("SampleSheet.csv").exists()
        } catch (Exception e) {
            throw new WorkflowScriptErrorException("Integration test failed!", e)
        }
    }

}


workflow test_multiple_runs {
    output_ch = Channel.fromList([
        [
          id: "test",
          input: params.resources_test + "200624_A00834_0183_BHMTFYDRXX.tar.gz",
        ],
        [
          id: "what_about_second_test",
          input: params.resources_test + "200624_A00834_0183_BHMTFYDRXX.tar.gz",
        ]
    ])
    | map {event -> [event.id, event] }
    | runner.run(
        fromState: {id, state -> state }
    )
    
    all_events_ch = output_ch
      | toSortedList()
      | map{states ->
        assert states.size() == 2
      }

}


workflow test_empty_channel {
    output_ch = channel.empty()
    | runner.run(
        fromState: {id, state -> state }
    )
    
    all_events_ch = output_ch
      | toSortedList()
      | map{states ->
        assert states.size() == 0
      }

}


