#!/bin/env sh

while [[ $# > 1 ]]; do
    key="$1"

    case $key in
        -t|--type)
            TYPE="${2}"
            shift #past argument
            ;;
        -a|--action)
            ACTION="${2}"
            shift #past argument
            ;;
    esac
shift
done

tempfile=$(tempfile 2>/dev/null) || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15

DIALOG=${DIALOG=dialog}
USERFILE="/root/git/dynamic-tui/includes/users.csv"
MENUFILE="/root/git/dynamic-tui/includes/menu.csv"

NAME=
NEWNAME=
NEWPASS=
MENUTEXT=

get_items()
{
    local iii=0
    while read line; do
        if [[ $(echo "${line}" | grep "^${TYPE}") ]]; then
            local items[iii]=$(echo -n "${line}" | cut -d , -f2)
            local items[iii+1]=""
            ((iii+=2))
        fi
    done < $USERFILE

    $DIALOG --clear --title "Choose ${TYPE}" \
            --menu "Choose a ${TYPE}" 0 0 10 "${items[@]}" 2>$tempfile

    local retval=$?
    local choice=$(cat $tempfile)

    case $retval in
        0)
            NAME="${choice}"
            menu_ $choice;;
        1)
            exit;;
        255)
            exit;;
    esac
}

set_name()
{
    local currentname="${1}"
    $DIALOG --clear --title "${ACTION} ${TYPE}" --inputbox "${TYPE}name" 0 0 "${currentname}" 2>$tempfile

    local retval=$?
    local choice="$(cat $tempfile)"

    case $retval in
        0)
            if [[ ! $(grep "${TYPE},${choice}," ${USERFILE}) ]]; then
                NEWNAME="${choice}"
            else
                sent_message "User exists" "This username already exists" set_name
            fi;;
        1)
            exit;;
        255)
            exit;;
    esac
}

set_password()
{
    local retval=""
    local newpass1=""
    local newpass2=""

    $DIALOG --clear --title "Enter password" --passwordbox " " 0 0 2>$tempfile

    retval=$?
    newpass1="$(cat $tempfile)"

    case $retval in
        0)
            $DIALOG --clear --title "Verify password" --passwordbox " " 0 0 2>$tempfile

            retval=$?
            newpass2="$(cat $tempfile)"

            case $retval in
                0)
                    if [[ ${newpass1} == ${newpass2} ]]; then
                        NEWPASS=$(echo "${newpass1}" | sha256sum | awk '{ print $1 }')
                    else
                        sent_message "Password incorrect" "The passwords don't match" set_password
                    fi;;
                1)
                    exit;;
                255)
                    exit;;
            esac;;
        1)
            exit;;
        255)
            exit;;
    esac
}

set_rights()
{
    local retval=
    local choice=
    get_menu
    oIFS=${IFS}
    IFS="/"
    $DIALOG --clear --title "${ACTION} ${TYPE}" --checklist " " 17 0 10 ${MENUTEXT} 2>$tempfile

    retval=$?
    IFS=${oIFS}
    choice=$(cat $tempfile)

    case $retval in
    0)
        echo "choice = ${choice} $"
        exit;;
    1)
        exit;;
    255)
        exit;;
    esac
}

write_changes()
{
    if [[ "${TYPE}" -eq "user" ]]; then
        if [[ "${ACTION}" -eq "create" ]]; then
            echo "${TYPE},${NEWNAME},${NEWPASS},${NEWRIGHTS}" >> ${USERFILE}
        else
            local entry="$(grep "${TYPE},${USER}," ${USERFILE})"
            local user="$(echo "${entry}" | cut -d , -f2)"
            local pass="$(echo "${entry}" | cut -d , -f3)"
            local rights="$(echo "${entry}" | cut -d , -f4)"

            sed -i "s/${entry}/${TYPE},${NEWNAME:-$user},${NEWPASS:-$pass},${NEWRIGHTS:-$rights}/" ${USERFILE}
        fi
#    elif [[ "${TYPE}" -eq "group" ]]; then
#        if [[ "${ACTION}" -eq "create" ]]; then
#
#        else
#
#        fi
    fi
}

sent_message()
{
    local title="${1}"
    local message="${2}"
    local action="${3}"

    $DIALOG --clear --title "${title}" --msgbox "${message}" 0 0
    ${action}
}

get_menu()
{
    local menu=${1:-"0"}
    local spacer=${2:-""}

    grep "^item,$menu\." $MENUFILE > /tmp/mypipe${menu}

    while read item;
    do

            # Temporarily set field seperator to ,
            oIFS=${IFS}
            IFS=","

            # Read row into array
            local itemarray=(${item})

            # Reset field seperator
            IFS=${oIFS}

            if [[ ${MENUTEXT} == "" ]]; then
                MENUTEXT="${itemarray[1]}/${spacer}${itemarray[2]}/OFF"
            else
                MENUTEXT="${MENUTEXT}/${itemarray[1]}/${spacer}${itemarray[2]}/OFF"
            fi

            if [[ ${itemarray[3]} == "menu" ]]; then
                get_menu ${itemarray[4]} "${spacer}  "
            fi
    done < /tmp/mypipe${menu}

    rm /tmp/mypipe${menu} 2>/dev/null
}

handle_action()
{
    case ${TYPE} in
        "user")
            case ${ACTION} in
                "show")
                    ;;
                "create")
#                    set_name
#                    set_password
                    set_rights
#                    write_changes
                    ;;
                "edit")
                    ;;
                "delete")
                    ;;
            esac;;
        "group")
            case ${ACTION} in
                "show")
                    ;;
                "create")
                    ;;
                "edit")
                    ;;
                "delete")
                    ;;
            esac
        
    esac
}

handle_action
