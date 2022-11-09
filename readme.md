### user_manager.sh

A simple user management script that takes a collection of public ssh keys and creates user accounts on multiple servers. Originally made to handle a university laboratory excercise network, not recommended for enterprise use.

The script takes a collection of public ssh keys, converts them to openssh format, generates user accounts using the public key's filename as username, and creates a private/public key pair for the local network authentication.


**Usage**: user_manager.sh command

commands
  - `create`
    - create new user accounts
  - `clean`
    - remove all user accounts created with this script except the ones on the filter list
  - `purge`
    - remove all user accounts except the ones on the filter list
  - `test`
    - test the functionality of the script (for debugging)

#### Configuration:

- **FILTERED_USERS**: accounts protected from removal
- **USER_GROUP**: user group to be used when creating the users
- **LOCAL_MACHINES**: array of ssh connections to create accounts on other servers on the local network
- **CONFIG_TEMPLATE**: template for ssh config
- **BROKEN_KEYS**: log file for broken public keys
