# About

A script to create a Service-User in Cumulocity (without having an actual Service running/hosted in Cumulocity). This is useful to create technical-users that can be used in third party applications to access Cumulocity's API. 

# Prerequisites

The script requires to be installed:
* curl (https://curl.se/)
* tr (part of https://www.gnu.org/software/coreutils/)
* jq (https://jqlang.github.io/jq/download/)

In case your system is missing these, one can also start a container via `docker run -it --rm ghcr.io/reubenmiller/c8y-shell` and run it from there. 

# Run the script

First, configure Service Name, it's desired API permissions and the tenant details in the header of the script. Now make this script executable and start it:

```sh
$ chmod +x create-service-user.sh
$ ./create-service-user.sh
```

Once started, the script will create the service-user and output its users name, password and granted permissions to console. Sample output:

```text
$ ./create-service-user.sh
Script started...

Setting 'remove app if exists' is activated. Checking for existance...
Application already existing (ID = 106526). Removing now...
Application removed

Creating an (empty) application...
Server Response: {"owner":{"self":"https://t12345.eu-latest.cumulocity.com/tenant/tenants/t12345","tenant":{"id":"t12345"}},"requiredRoles":["ROLE_EVENT_READ","ROLE_EVENT_ADMIN","ROLE_ALARM_READ","ROLE_ALARM_ADMIN"],"manifest":{"requiredRoles":[],"roles":[],"billingMode":"RESOURCES","noAppSwitcher":true,"settingsCategory":null},"roles":[],"contextPath":"your-service-name","availability":"PRIVATE","type":"MICROSERVICE","name":"your-service-name","self":"https://t12345.eu-latest.cumulocity.com/application/applications/106527","id":"106527","key":"your-service-name-key"}
Extracted Application ID: 106527

Activating the application...
Server Response: {"self":"http://t12345.eu-latest.cumulocity.com/tenant/tenants/t12345/106527","application":{"owner":{"self":"https://t12345.eu-latest.cumulocity.com/tenant/tenants/t12345","tenant":{"id":"t12345"}},"requiredRoles":["ROLE_EVENT_READ","ROLE_EVENT_ADMIN","ROLE_ALARM_READ","ROLE_ALARM_ADMIN"],"manifest":{"requiredRoles":[],"roles":[],"billingMode":"RESOURCES","noAppSwitcher":true,"settingsCategory":null},"roles":[],"contextPath":"your-service-name","availability":"MARKET","type":"MICROSERVICE","name":"your-service-name","self":"https://t12345.eu-latest.cumulocity.com/application/applications/106527","id":"106527","key":"your-service-name-key"}}

Extracting bootstrap user from the application...
Found bootstrap user: servicebootstrap_your-service-name

Getting Service User...
Server response: {"users":[{"password":"{obfuscated}","name":"service_your-service-name","tenant":"t12345"}]}

Login as your new service-user and query its granted permissions ...

Script finished. Here are your service credentials:
C8Y_BASEURL=https://example.cumulocity.com
C8Y_BOOTSTRAP_TENANT=t1234
C8Y_BOOTSTRAP_USER=servicebootstrap_your-service-name
C8Y_BOOTSTRAP_PASSWORD=...
C8Y_TENANT=t1234
C8Y_USER=service_your-service-name
C8Y_PASSWORD=...
Assigned permissions: ["ROLE_IDENTITY_ADMIN","ROLE_MEASUREMENT_ADMIN","ROLE_INVENTORY_READ","ROLE_IDENTITY_READ","ROLE_SYSTEM","ROLE_NOTIFICATION_2_ADMIN","ROLE_INVENTORY_ADMIN","ROLE_OPTION_MANAGEMENT_READ","ROLE_EVENT_ADMIN"]
