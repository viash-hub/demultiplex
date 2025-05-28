import java.nio.file.Files
import nextflow.exception.WorkflowScriptErrorException

// Create temporary directory
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

// The module inherits the parameters defined before the include statement, 
// therefore any parameters set afterwards will not be used by the module.

params.publish_dir = tempDir
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
    workflow.onComplete = {
        try {
            // Nexflow only allows exceptions generated using the 'error' function (which throws WorkflowScriptErrorException).
            // So in order for the assert statement to work (or allow other errors to let the tests to fail)
            // We need to wrap these in WorkflowScriptErrorException. See https://github.com/nextflow-io/nextflow/pull/4458/files
            // The error message will show up in .nextflow.log
            def publish_subdir = file("${tempDir}/200624_A00834_0183_BHMTFYDRXX")
            assert publish_subdir.isDirectory() 
            def all_files = publish_subdir.listFiles()
            assert all_files.size() == 1
            def publish_dir = file(all_files[0])
            assert publish_dir.name.endsWith("_demultiplex_unknown_version")
            def published_items = publish_dir.listFiles()
            assert published_items.size() == 4
            assert published_items.collect{it.name}.toSet() == ["demultiplexer_logs", "fastq", "qc", "SampleSheet.csv"].toSet()
            def fastqc_files = publish_dir.resolve("qc/fastqc").listFiles()
            assert fastqc_files.collect{it.name}.toSet() == [
                "Sample1_S1_L001_R1_001_fastqc_data.txt",
                "Sample1_S1_L001_R1_001_fastqc_report.html",
                "Sample1_S1_L001_R1_001_summary.txt",
                "Sample23_S3_L001_R1_001_fastqc_data.txt",
                "Sample23_S3_L001_R1_001_fastqc_report.html",
                "Sample23_S3_L001_R1_001_summary.txt",
                "SampleA_S2_L001_R1_001_fastqc_data.txt",
                "SampleA_S2_L001_R1_001_fastqc_report.html",
                "SampleA_S2_L001_R1_001_summary.txt",
                "sampletest_S4_L001_R1_001_fastqc_data.txt",
                "sampletest_S4_L001_R1_001_fastqc_report.html",
                "sampletest_S4_L001_R1_001_summary.txt",
                "Undetermined_S0_L001_R1_001_fastqc_data.txt",
                "Undetermined_S0_L001_R1_001_fastqc_report.html",
                "Undetermined_S0_L001_R1_001_summary.txt"
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

