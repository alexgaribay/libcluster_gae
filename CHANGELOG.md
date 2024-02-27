# Changelog for v0.2

## v0.2.0 (2024-02-26)

### Enhancements

  * Support for Google Cloud [projects created after September 6th, 2018](https://cloud.google.com/compute/docs/networking/zonal-dns)
  * `cluster_across_versions` option allows you to disable the default setting that different versions of the same service cluster together.

### Deprecation

  * Google Cloud projects created before September 6th, 2018 use Global DNS, and not Zonal DNS. For these projects, continue using v0.1
  * Similarly, old projects still using Distillary will need to use the old README.
