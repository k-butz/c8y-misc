#!/usr/bin/env bash

# configure service details
SERVICE_NAME=your-service-name
CONTEXT_PATH=your-service-ctx
# should match the category for your tenant options
SETTINGS_CATEGORY=your-category 
# the required roles for each API call can be found in https://cumulocity.com/api/core/
SERVICE_ROLES='["ROLE_OPTION_MANAGEMENT_READ","ROLE_MEASUREMENT_ADMIN","ROLE_EVENT_ADMIN","ROLE_INVENTORY_READ","ROLE_INVENTORY_ADMIN","ROLE_IDENTITY_READ","ROLE_IDENTITY_ADMIN","ROLE_NOTIFICATION_2_ADMIN"]'

# configure tenant connection
TENANT_BASEURL=https://example.cumulocity.com
TENANT_ID=t1234
TENANT_ADMIN_USER=korbinian.butz@cumulocity.com
TENANT_ADMIN_PASS="your-secret-pass"

# if TRUE script deletes existing application with given name if already existing (useful for testing & updating roles)
REMOVE_APP_IF_EXISTS=TRUE

echo "Script started..."
echo ""

AUTHORIZATION="Basic $(echo -n "$TENANT_ID/$TENANT_ADMIN_USER:$TENANT_ADMIN_PASS" | base64 | tr -d '\n')"

# 0. Optional step: remove application if it already exists
if [ "$REMOVE_APP_IF_EXISTS" = "TRUE" ]; then
    echo "Setting 'remove app if exists' is activated. Checking for existance..."
    response=$(curl -s -k -X 'GET' -H 'Accept: application/json' \
        -H "Authorization: $AUTHORIZATION" \
        "$TENANT_BASEURL/application/applications?pageSize=2000&type=MICROSERVICE")
    current_app_id=$(echo "$response" |  jq -r '.applications[] | select(.name == "'"$SERVICE_NAME"'") | .id')
    if [ ${#current_app_id} -gt 0 ]; then
        echo "Application already existing (ID = $current_app_id). Removing now..."
        curl -s -k -X 'DELETE' -H 'Accept: application/json'\
            -H "Authorization: $AUTHORIZATION" \
            "$TENANT_BASEURL/application/applications/$current_app_id"
        echo "Application removed"
    else
        echo "No application with current name existing yet. Nothing to remove."
    fi
    echo ""
fi

# 1. Create an Application including the required permissions/roles
echo "Creating an (empty) application..."
response=$(curl -s -k -X 'POST' \
    -d '{"contextPath":"'"$CONTEXT_PATH"'","key":"'"$SERVICE_NAME"'-key","name":"'"$SERVICE_NAME"'","settingsCategory":"'"$SETTINGS_CATEGORY"'","requiredRoles":'"$SERVICE_ROLES"',"type":"MICROSERVICE"}' \
    -H 'Accept: application/json' \
    -H "Authorization: $AUTHORIZATION" \
    -H 'Content-Type: application/json' \
    "$TENANT_BASEURL/application/applications")
echo "Server Response: $response"
app_id=$(echo "$response" | jq -r .id)
echo "Extracted Application ID: $app_id"
echo ""

# 2. Activate this application
echo "Activating the application..."
response=$(curl -s -k -X 'POST' -d '{"application":{"id":"'"$app_id"'"}}' -H 'Accept: application/json' -H "Authorization: $AUTHORIZATION" \
    -H 'Content-Type: application/json' "$TENANT_BASEURL/tenant/tenants/$TENANT_ID/applications")
echo "Server Response: $response"
echo ""

# 3. Get Bootstrap User from this application
echo "Extracting bootstrap user from the application..."
response=$(curl -s -k -X 'GET' -H 'Accept: application/json' -H "Authorization: $AUTHORIZATION" "$TENANT_BASEURL/application/applications/$app_id/bootstrapUser")
bootstrap_user=$(echo "$response" | jq -r .name)
bootstrap_pass=$(echo "$response" | jq -r .password)
echo ""

# 4. Get Service-User from this application (important: do this call using the bootstrap user of step 3!)
echo "Getting Service User..."
AUTHORIZATION_BOOTSTRAP_USER="Basic $(echo -n "$TENANT_ID/$bootstrap_user:$bootstrap_pass" | base64 | tr -d '\n')"
response=$(curl -s -k -X 'GET' -H 'Accept: application/json' -H "Authorization: $AUTHORIZATION_BOOTSTRAP_USER" "$TENANT_BASEURL/application/currentApplication/subscriptions")
echo "Server response: $response"
service_user=$(echo "$response" | jq -r '.users[0].name')
service_pass=$(echo "$response" | jq -r '.users[0].password')
service_tenant=$(echo "$response" | jq -r '.users[0].tenant')
echo ""

# 5. Now login via this user and query user-details and granted permissions
AUTHORIZATION_SERVICE_USER="Basic $(echo -n "$TENANT_ID/$service_user:$service_pass" | base64 | tr -d '\n')"
echo "Login as your new service-user and query its granted permissions ..."
response=$(curl -s -k -X 'GET' -H 'Accept: application/json' \
    -H "Authorization: $AUTHORIZATION_SERVICE_USER" \
    "$TENANT_BASEURL/user/currentUser")
user_id=$(echo "$response" | jq -r .userName)
user_permissions=$(echo "$response" | jq '[.effectiveRoles[].id]' -c)


echo ""
echo "Script finished. Here are your service credentials:"
echo "C8Y_BASEURL=${TENANT_BASEURL}"
echo "C8Y_BOOTSTRAP_TENANT=${service_tenant}"
echo "C8Y_BOOTSTRAP_USER=${bootstrap_user}"
echo "C8Y_BOOTSTRAP_PASSWORD=${bootstrap_pass}"
echo "C8Y_TENANT=${service_tenant}"
echo "C8Y_USER=${service_user}"
echo "C8Y_PASSWORD=${service_pass}"
echo "Assigned permissions: ${user_permissions}"
