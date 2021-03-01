# The Common Pre-commit Framework Configuration Template

This project provides a common base of Pre-commit's configuration file(.pre-commit-config.yaml)
that should be easily adaptable for most project's with little modifications.

[![Continuous Integration(CI) Status Badge](https://cloud.drone.io/api/badges/Lin-Buo-Ren/common-precommit-config-template/status.svg "Continuous Integration(CI) Status")](https://cloud.drone.io/Lin-Buo-Ren/common-precommit-config-template)

## How to use

* Copy the [common.pre-commit-config.yaml](common.pre-commit-config.yaml) file to your preferred
  location as .pre-commit-config.yaml
* Download the source code and run [Installer.bash](Installer.bash) program to setup template
  files for desktop environments.  If you specify a directory as argument it will install the
  template file to the directory instead.

## License

Unless otherwise specified, this product is released with [the Creative Commons Attribution-ShareAlike License,
version 4.0](https://creativecommons.org/licenses/by-sa/4.0), or any more recent version of your choice, with an
exception of the license only covers the configuration file itself, but not other assets in your project.

For the attribution requirement, please retain the "This file is based on ..." mention and link to this project.

### Identify licenses applicable to a certain product/development asset

If the asset is in plaintext format:

1. Check the `SPDX-License-Identifier` tag in the file's header
1. Check the [.reuse/dep5](.reuse/dep5) file from the source tree/release tree directory

If the asset is not in plaintext format:

Check the [.reuse/dep5](.reuse/dep5) file from the source tree/release tree directory
