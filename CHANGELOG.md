# demultiplex v0.3.10

## Minor changes

* Moved the test resources to their new location (PR #37).

# demultiplex v0.3.9

## Bug fixes

* Fix defaults for output arguments in nextflow schema's.

* Fix an issue where an integer being passed to a argument with `type: double` resulted in an error (PR #44).

## Minor changes

* Bump viash to 0.9.4, which adds support for nextflow versions starting major version 25.01 (PR #43 and #44).

* Output demultiplexer logs and metrics (PR #41).
  
# demultiplex v0.3.8

## Bug fixes

* Provide a proper error when a FASTQ file is empty after demultiplexing (PR #40).

# demultiplex v0.3.7

## Minor updates

* Ignore lines starting with '#' when parsing run information CSV (PR #39).

# demultiplex v0.3.6

## Minor updates

* Allow letter case variants for headers when looking for sample information in run information CSV (PR #38).

# demultiplex v0.3.5

## Breaking changes

* The `demultiplex` workflow now outputs a list of directories
  for the `output_falco` argument (one for each barcode) instead of one directory
  for the complete run. The output from the `runner` workflow remained
  unchanged (PR #33).

## Minor updates

* In case Illumina data is detected in the input folder, check for the presence of the 'copyComplete.txt' file.
  This check can be disabled using `--skip_copycomplete_check` (PR #34).

# demultiplex v0.3.4

## Minor updates

* Resource labels are now automatically included during build (PR #32).

# demultiplex v0.3.3

## Breaking change

- The `runner` defines the output differently now:

  - The last part of the `--input` path is expected to be the run ID and this run ID is used to create the output directory.
  - If the input is `file.tar.gz` instead of a directory, the `file` part is used as the run ID.

- The output structure is then as follows:

    ```
    $publish_dir/<run_id>/<date_time_stamp>_demultiplex_<version>/
    ```

    For instance:

    ```
    $publish_dir
    └── 200624_A00834_0183_BHMTFYDRXX
        └── 20241217_051404_demultiplex_v1.2
            ├── run_information.csv
            ├── fastq
            │   ├── Sample1_S1_L001_R1_001.fastq.gz
            │   ├── Sample23_S3_L001_R1_001.fastq.gz
            │   ├── SampleA_S2_L001_R1_001.fastq.gz
            │   ├── Undetermined_S0_L001_R1_001.fastq.gz
            │   └── sampletest_S4_L001_R1_001.fastq.gz
            └── qc
                ├── fastqc
                │   ├── Sample1_S1_L001_R1_001.fastq.gz_fastqc_data.txt
                │   ├── Sample1_S1_L001_R1_001.fastq.gz_fastqc_report.html
                │   ├── Sample1_S1_L001_R1_001.fastq.gz_summary.txt
                │   ├── Sample23_S3_L001_R1_001.fastq.gz_fastqc_data.txt
                │   ├── Sample23_S3_L001_R1_001.fastq.gz_fastqc_report.html
                │   ├── Sample23_S3_L001_R1_001.fastq.gz_summary.txt
                │   ├── SampleA_S2_L001_R1_001.fastq.gz_fastqc_data.txt
                │   ├── SampleA_S2_L001_R1_001.fastq.gz_fastqc_report.html
                │   ├── SampleA_S2_L001_R1_001.fastq.gz_summary.txt
                │   ├── Undetermined_S0_L001_R1_001.fastq.gz_fastqc_data.txt
                │   ├── Undetermined_S0_L001_R1_001.fastq.gz_fastqc_report.html
                │   ├── Undetermined_S0_L001_R1_001.fastq.gz_summary.txt
                │   ├── sampletest_S4_L001_R1_001.fastq.gz_fastqc_data.txt
                │   ├── sampletest_S4_L001_R1_001.fastq.gz_fastqc_report.html
                │   └── sampletest_S4_L001_R1_001.fastq.gz_summary.txt
                └── multiqc_report.html

    ```

- This logic can be avoided by providing the flag `--plain_output`.

# Minor updates

* Added `output_run_information` argument that copies the run information file to the output (PR #31).

# demultiplex v0.3.2

# Bug fixes

* Ignore empty CSV entries when parsing sample information (PR #29).

# demultiplex v0.3.1

# Minor updates

* Add `--run_information` and `--demultiplexer` arguments to `runner` workflow (PR #27).

# Bug fixes

* Fix detection of sample IDs from Illumina V2 sample sheets (PR #28).

* Provide a clear error message when `--run_information` is provided but not `--demultiplexer` (PR #27).

# demultiplex v0.3.0

## Major updates

The outflow of the workflow has been refactored to be more flexible (PR #19). This is done by creating a wrapper workflow `runner` that wraps the native `demultiplex` workflow. The `runner` workflow is responsible for setting the output directory based on the input arguments:

3 arguments exist for specifying the relative location of the 3 _outputs_ of the workflow:

- `fastq_output`: The directory where the demultiplexed fastq files are stored.
- `falco_output`: the directory for the `fastqc`/`falco` reports.
- `multiqc_output`: The filename for the `multiqc` report.

The target location path is determined by the following logic:

- If no `id` is provided, the output directory is set to `$publish_dir`.
- If an `id` is explicitly set using Seqera Cloud or by adding `--id <>`, the output directory is set to `$publish_dir/<id>`.

The workflow has two optional flags to be used in combination with `--id`:

- `--add_date_time`: rather than publishing the results under `$publish_dir`, this adds an additional layer `$publish_dir/<date-time-stamp>/`. This is useful when you want to keep track of multiple runs of the workflow (example: `240322_143020`).
- `--add_workflow_id`: adding this flag will add `_demultiplex_<version>` to the output directory (example: `demultiplex_v0.2.0`). When starting the workflow from a non-release, the version will be set to `version_unkonwn`.

The default structure in the output directory is:

- Two sub-directories:
  - `fastq`
  - `qc` for the reports:
    - `multiqc_report.html`
    - `fastqc/` directory containing the different fastqc (falco) reports.

The `$publish_dir` variable corresponds to the argument provided with `--publish-dir`. The `date-time-stamp` is generated by the workflow based on when it was launched and is thus guaranteed to be unique.

# demultiplex v0.2.0

## Breaking changes

* `demultiplex` workflow: renamed `sample_sheet` argument to `run_information` (PR #24)

## New features

* Add support for `bases2fastq` demultiplexer (PR #24)

## Minor updates

* Add resource labels to workflows (PR #21).

# demultiplex v0.1.1

## Minor updates

* Bump viash to 0.9.0 (PR #14).

* `demultiplex` workflow: use `v0.2.0` release instead of `main` branch for `biobox` dependencies (PR #11).

* Renamed `biobase` repository to `biobox` (PR #13 and PR #15).

# demultiplex v0.1.0

Initial release
