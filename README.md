# DataPower Secure Backup automation

This script is used to automate the DataPower Secure Backup process.

## Features

- Creates a Secure Backup on a DataPower gateway.
- Downloads the backup files to the local filesystem.
- Optionally, pushes the backup files to a git repository.

## Overview

- XML Management Interface is used to access the DataPower gateway.
- This script does not quiesce the DataPower gateway.
- The local folder name consists from the DataPower hostname, the firmware version, and the current timestamp.

## Support

Successfully tested setup:

- DataPower 10.0.5.2.

## Configuration overview

| Parameter              | Description                                                                                                                                                     | Example                                              |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| DP_SERVER0             | DataPower hostname or IP address that is configured for the XML Management Interface.                                                                           | <code>gw.myorg.com</code>                            |
| DP_SOMA_PORT_SERVER0   | DataPower XML Management Interface port number.                                                                                                                 | <code>5550</code>                                    |
| DP_USER_SERVER0        | DataPower credentials - username to access the XML Management Interface.                                                                                        | <code>admin</code>                                   |
| DP_PASSWORD_SERVER0    | DataPower credentials - password.                                                                                                                               |
| DP_CERTIFICATE_SERVER0 | DataPower Crypto Certificate that contains the public key to be used in encrypting the secure backup. The object should be preconfigured in the default domain. | <code>SB_Cert</code>                                 |
| INCLUDE_ISCSI          | Whether to back up the ISCSI device.                                                                                                                            | <code>on</code> \| <code>off</code>                  |
| INCLUDE_RAID           | Whether to back up the RAID device.                                                                                                                             | <code>on</code> \| <code>off</code>                  |
| DESTINATION            | A directory to place the multiple files that comprise the backup.                                                                                               | <code>temporary:///</code> \| <code>local:///</code> |
| ADD_TO_GIT             | Whether to push the backup files to a git repository.                                                                                                           | <code>true</code> \| <code>false</code>              |
| GIT_REMOTE_NAME        | Git repository remote name.                                                                                                                                     | <code>origin</code>                                  |
| GIT_BRANCH_NAME        | Git branch name.                                                                                                                                                | <code>main</code>                                    |

## Usage

- Duplicate the provided [project configuration template](00-project-template.conf) and fill it out.
- One configuration file per one DataPower gateway.
- Run the automation script passing the configuration file as an argument. For example:

  | <code>./01-secure-backup.sh dp1.conf</code> |
  | ------------------------------------------- |
