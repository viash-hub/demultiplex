# Demultiplex.vsh

Demultiplex.vsh is a workflow for demultiplexing of raw sequencing data.Currently data from Illumina and Element Biosciences sequencers are supported.

[![ViashHub](https://img.shields.io/badge/ViashHub-demultiplex-7a4baa.svg)](https://web.viash-hub.com/packages/demultiplex)
[![GitHub](https://img.shields.io/badge/GitHub-viash--hub%2Fdemultiplex-blue.svg)](https://github.com/viash-hub/demultiplex)
[![GitHub
License](https://img.shields.io/github/license/viash-hub/demultiplex.svg)](https://github.com/viash-hub/demultiplex/blob/main/LICENSE)
[![GitHub
Issues](https://img.shields.io/github/issues/viash-hub/demultiplex.svg)](https://github.com/viash-hub/demultiplex/issues)
[![Viash
version](https://img.shields.io/badge/Viash-v0.9.1-blue)](https://viash.io)

## Workflow Overview
The workflow executes of the following steps: 
1. Unpacking the input data (when a TAR archive is provided)
2. Run `bclconvert` or `bases2fastq`
3. Run `falco` and convert Illumina InterOp information to csv
4. Run `multiqc` to generate a report

## Usage

Two variants of the same workflow are provided, depending on the flexibility in the ouput structure required:

* The `runner` workflow provides a predifined output structure. It requires the minimal amount of parameters to be provided, at the cost of being less flexible. It is located at `target/nextflow/runner/main.nf`
* The `demultiplex` workflow (`target/nextflow/demultiplex/main.nf`) allows for more fine-grained tuning, but required more parameters to be provided.

### Test data

We have provided test data at `gs://viash-hub-test-data/demultiplex/v3/demultiplex_htrnaseq_meta/SingleCell-RNA_P3_2`, but please feel free to bring your own. The URL of the test data can be provided as-is to the workflow, or you can download download everything and specify a local path.

### Setup

In order to use the workflows in this package, you'll need to do the following:
* Install [nextflow](https://www.nextflow.io/docs/latest/install.html)
* Install a nextflow compatible executor. This workflow provides a profile for [docker](https://docs.docker.com/get-started/).

### Setting up SCM

In order to let nextflow use any viash-hub workflow, you need to setup a [SCM](https://www.nextflow.io/docs/latest/git.html#git-configuration) file. This can be done once by creating `$HOME/.nextflow/scm` and adding the following:
```
providers {
   vsh {
    platform = 'gitlab'
    server = "packages.viash-hub.com"
  }
}
```

Alternatively, a custom location for the SCM file can be specified using the `NXF_SCM_FILE` environment variable.

You can check if everything is working by getting the `--help` for a workflow:
```bash
nextflow run \
https://packages.viash-hub.com/vsh/demultiplex \
-r v0.3.4 \
--help
```

### (Optional) Resource usage tuning

Nextflow's labels can be used to specify the amount of resources a process can use. This workflow uses the following labels for CPU and memory:
* `verylowmem`, `lowmem`, `midmem`, `highmem`
* `verylowcpu`, `lowcpu`, `midcpu`, `highcpu`

The defaults for these labels can be found at `src/config/labels.config`. Nextflow checks that the specified resources for a process do not exceed what is available on the machine and will not start if it does. Create your own config file to tune the labels to your needs, for example:

```
// Resource labels
withLabel: verylowcpu { cpus = 2 }
withLabel: lowcpu { cpus = 8 }
withLabel: midcpu { cpus = 16 }
withLabel: highcpu { cpus = 16 }

withLabel: verylowmem { memory = 4.GB }
withLabel: lowmem { memory = 8.GB }
withLabel: midmem { memory = 8.GB }
withLabel: highmem { memory = 8.GB }
```

When starting nextflow using the CLI, you can use `-c` to provide the file to nextflow and overwrite the defaults.

### Example

```bash
nextflow run https://packages.viash-hub.com/vsh/demultiplex \
-r v0.3.4 \
-main-script target/nextflow/runner/main.nf \
--input "gs://viash-hub-test-data/demultiplex/v3/demultiplex_htrnaseq_meta/SingleCell-RNA_P3_2"  \
--demultiplexer bclconvert \
--publish_dir example_output/ \
-profile docker \
-c labels.config
```

## Acknowledgements

Developed in collaboration with Data Intuitive and Open Analytics.


