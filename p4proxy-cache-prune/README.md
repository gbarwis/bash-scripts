# p4proxy-cache-clean.sh

This script, **p4proxy-cache-clean.sh**, is designed to help maintain a Perforce proxy server by cleaning up the cache and removing old files that are no longer needed. It offers both a safe test mode and a full purge mode, allowing you to decide how you want to handle file deletions.

## Features

- **Test Mode** (`-t` or `--test`): Simulates the cleanup process without actually deleting files. It provides detailed information on which files would be deleted and how much space would be freed, allowing you to verify the behavior before taking any action.
- **Purge Mode** (`-p` or `--purge`): Deletes files that meet the specified conditions to free up space in the cache.
- **Report Options** (`-r` or `--report`, `-n` or `--noreport`): Optionally sends a report of the cleanup process via AWS SNS to notify administrators of the operation results.

## Usage

```sh
./p4proxy-cache-clean.sh {-p|--purge | -t|--test} {-r|--report | -n|--noreport}
```

- **`-p, --purge`**: Take full action, deleting all files that meet the criteria.
- **`-t, --test`**: Do not delete any files, but display what would happen.
- **`-r, --report`**: Send a notification (via email, AWS SNS, etc.) with the results.
- **`-n, --noreport`**: No notification, but still display and log the results.

### Example

To simulate the cleanup process without deleting any files and send a report:

```sh
./p4proxy-cache-clean.sh --test --report
```

To perform a full cleanup and suppress notifications:

```sh
./p4proxy-cache-clean.sh --purge --noreport
```

## Requirements

- **AWS CLI**: The script uses AWS SNS to send reports, so the AWS CLI must be configured properly.
- **Perforce Proxy Server**: This script is intended to be run on a Perforce proxy server to clean up old cached files.
- **Environment File**: The script sources configuration variables from an environment file (`p4proxy-cache-clean.env`). Make sure to provide and configure this file appropriately. A sample file is provided (`p4proxy-cache-clean.env`).

## Environment Variables

The script uses an environment file (`p4proxy-cache-clean.env`) to load the following variables:

- **`DAYS_OLD`**: The number of days after which files should be considered for deletion.
- **`P4P_DIR`**: The path to the Perforce proxy cache directory.
- **`LOG_FILE`**: The path to the log file where the script records its actions.
- **`HOST_LOCATION`**: A description of the host server's location (e.g., "Narnia").
- **`AWS_ACCOUNT`**: The AWS account ID used for SNS notifications.
- **`AWS_SNS_TOPIC_NAME`**: The name of the SNS topic used for notifications.
- **`AWS_SNS_REGION`**: The AWS region where the SNS topic is located.

## Disclaimer

Use this script at your own risk. Always test it in **test mode** before running in **purge mode** to ensure it behaves as expected. Make sure you understand the impact of deleting cached files on your Perforce proxy server.

## License

This script is licensed under the MIT License. Please see the LICENSE file for more details.
