nextflow run . \
  -main-script src/demultiplex/test.nf \
  -profile docker,no_publish \
  -entry test_wf \
  -c src/config/tests.config
