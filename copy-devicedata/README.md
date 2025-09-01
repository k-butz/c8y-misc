# c8y-copy-devicedata
A project to copy data from one device to another within the same tenant. 

Project is utilizing https://github.com/reubenmiller/go-c8y-cli and is based on https://github.com/reubenmiller/go-c8y-cli-demos/tree/main/examples/copy-measurements-to-tenant.

# Usage

1. Either clone the repository or copy `session.json` and `copy-devicedata.sh` files to a local folder. Both files needs to be in the same folder.
2. Edit the session.json file. Please configure `host`, `username` and `password` fields to your tenant. 
````json
{
    "$schema": "https://raw.githubusercontent.com/reubenmiller/go-c8y-cli/v2/tools/schema/session.schema.json",
    "host": "https://my-tenant.cumulocity.com",
    "username": "my@user.com",
    "password": "super-secret-password",
    "settings": {
      "activitylog": {
        "enabled": false
      },
      "mode": {
        "confirmation": "PUT POST DELETE",
        "enablecreate": true,
        "enabledelete": false,
        "enableupdate": false
      }
    },
    "usetenantprefix": true
}
````
3. Open a shell and navigate towards your directory. Once there, run a Container in interactive mode (note that the two files are mounted):
````sh
docker run -it -v $(pwd)/session.json:/sessions/session.json -v $(pwd)/copy-devicedata.sh:/home/c8yuser/copy-devicedata.sh --rm ghcr.io/reubenmiller/c8y-shell
````
4. Within the container, run `set-session` once. This will configure the tooling towards using the tenant stated in session.json.
````sh
set-session
````

A confirmation about your session should be printed in console. Make sure there is no error shown, otherwise next step will not succeed.

5. Make script file executable:
```sh
chmod +x copy-devicedata.sh
```

6. Run the script. E.g. to copy all measurments, events and alarms between specific dates from Device ID 87161761932 towards ID 56161769526 this one can be used:
````sh
./copy-devicedata.sh  --dateFrom "2023-04-26T12:00:00.000Z" --dateTo "2023-04-27T23:12:34.567Z" --types measurements,events,alarms --device-tuples "87161761932:56161769526"
````

Complete usage instructions:

````
Usage:
    ./copy-devicedata.sh [--workers <number>] [--delay <duration>] [--dateFrom <date|relative>] [--dateTo <date|relative>] [--types <measurements,events,alarms>] --device-tuples "<device tuples>"

Example 1: Copy all measurements, events and alarms from devices 123 to 456, and don't prompt for confirmation

    ./copy-devicedata.sh --types measurements,events,alarms --device-tuples "123:456" --force

Example 2: Same as example 1 but with additional time filter

    ./copy-devicedata.sh --types measurements,events,alarms --device-tuples "123:456" --dateFrom "2023-04-20T00:00:00.000Z" --dateTo "2023-04-23T12:00:00.000Z" --force

Example 3: Copy measurements from Device ID 123 towards 456 and from Device ID 111 towards 222 - but only copy measurements between dates 100 days ago to 7 days ago

    ./copy-devicedata.sh --dateFrom -100d --dateTo -7d --types measurements --device-tuples "123:456 111:222"


Arguments:

  --device-tuples <string> : A list of device id tuples. Each tuple consists of two Managed object ids in format <source device id>:<destination device id>. Multiple tuples are separated by white-spaces.
  --workers <int> : Number of concurrent workers to create the measurements
  --dateFrom <date|relative_date> : Only include measurements from a specific date
  --dateTo <date|relative_date> : Only include measurements to a specific date
  --delay <interval> : Delay between after each concurrent worker. This is used to rate limit the workers (to protect the tenant)
  --types <csv_list> : CSV list of c8y data types, i.e. measurements,events,alarms
  --force|-f : Don't prompt for confirmation
````

7. You are done. The specified data should now be copied between your devices.