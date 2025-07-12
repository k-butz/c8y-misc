#!/bin/bash

print_permissions_for_role () {
    role="$1"
    permission_type="$2"

    all_roles=$(c8y userroles getRoleReferenceCollectionFromGroup --group "${role}" --includeAll -n )

    # filter roles (ec vs global)
    filtered_roles=""
    if [ "${permission_type}" = "global" ]; then
        filtered_roles=$(echo "${all_roles}" | grep -v "EC_")
    elif [ "${permission_type}" = "ec" ]; then
        filtered_roles=$(echo "${all_roles}" | grep "EC_")
    fi

    # print prettified CSV
    if [[ -n ${filtered_roles} ]]; then
        echo ${filtered_roles} | jq -r .role.id | sort | sed 's/^\|$/"/g' | paste -sd "," - | sed 's/,/, /g'
    else
        echo "invalid permission type"
    fi 
}

print_applications_for_role () {
    role="${1}"

    # check if user has application mgmt read
    has_app_mgmt_read=false
    app_role=$( c8y userroles getRoleReferenceCollectionFromGroup --group "${1}" --includeAll -n \
        | jq -r '.role.id' | grep 'ROLE_APPLICATION_MANAGEMENT_READ' )
    if [[ -n ${app_role} ]]; then
        has_app_mgmt_read="true"
    fi

    # Collect applications and print prettified CSV
    apps=""
    if [ "${has_app_mgmt_read}" = "true" ]; then
        echo "ALL"
    else
        echo $( c8y usergroups get -n --id "${role}" | jq -r '.applications[].name' | sort | sed 's/^\|$/"/g' | paste -sd "," - | sed 's/,/, /g' )
    fi
}

print_markdown_role_x_permission () {
    echo '| Role | EC Permissions | Applications | Global Permissions |'
    echo '|--|--|--|--|'
    while IFS= read -r role
    do
        echo "| \`${role}\` | $(print_permissions_for_role "${role}" ec) | $(print_applications_for_role "${role}") | $(print_permissions_for_role "${role}" global) |"
    done <<< "$( c8y usergroups list -n --includeAll | jq -r .name | grep '^EC ' | sort --reverse )"
}

print_markdown_permssion_x_role () {
    # create mapping role-to-permission
    # creates a string with each line: 
    #   {role name}={csv of permissions}
    # can be used later together with grep to find all roles for a given permission
    role_permission_mapping=""
    while IFS= read -r role
    do
        line=$( c8y userroles getRoleReferenceCollectionFromGroup --group "${role}" --includeAll -n \
            | jq -r '.role.id' | sed 's/^\|$/"/g' | paste -sd "," - | sed "s/^/${role}=/" )
        role_permission_mapping="${role_permission_mapping}\n${line}"
        line=""
    done <<< "$( c8y usergroups list -n --includeAll | jq -r .name | grep '^EC ' | sort --reverse )"

    # print header
    echo '| Permission | Roles |'
    echo '|--|--|'

    # loop through all permissions assigned to Administrator
    while IFS= read -r permission
    do
        roles_with_permission=$( printf "${role_permission_mapping}" \
            | grep "$permission" | awk -F "=" '{print $1}' | sed 's/^\|$/"/g' | paste -sd "," - | sed 's/,/, /g' )
        echo "| \`${permission}\` | $roles_with_permission |"
    done <<< "$( c8y userroles list --includeAll | jq -r .id | sort )"
}

echo "### Permissions x Groups"
echo ""
print_markdown_permssion_x_role

echo ""
echo ""

echo "### Groups x Permissions"
echo ""
print_markdown_role_x_permission