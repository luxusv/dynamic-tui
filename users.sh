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

DIALOG=${DIALOG=dialog}
USERFILE="/root/git/dynamic-tui/includes/users.csv"
MENUFILE="/root/git/dynamic-tui/includes/menu.csv"

NAME=
NEWNAME=
NEWPASS=
NEWRIGHTS=
MENUTEXT=

get_item()
{
    local choice=
    local itemtype="${1}"
    local menutype="${2}"
    local group="${3}"
    local spacer=""

    tmplist=($(awk -F',' -v itemtype="${itemtype}" '{ if ($1 == itemtype) print $2 }' ${USERFILE}))

    for item in ${tmplist[@]}; do
        [[ ${itemlist} != "" ]] && spacer="/"
        case ${menutype} in
            "menu") 
                itemlist="${itemlist}${spacer}${item}";;
            "radiolist")
                itemlist="${itemlist}${spacer}${item}";;
            "checklist")
                members=" $(awk -F',' -v group="${group}" '{ if ($1 == "group" && $2 == group) print $3 }' ${USERFILE}) "
                if [[ " ${members} " =~ ${item} ]]; then
                    itemlist="${itemlist}${spacer}${item}/ON"
                else
                    itemlist="${itemlist}${spacer}${item}/OFF"
                fi
        esac
    done

    oIFS=${IFS}
    IFS="/"
    choice=($($DIALOG --keep-tite --no-items --title "${ACTION} ${TYPE}" --${menutype} "Make a choice" 0 0 0 ${itemlist} 3>&1 1>&2 2>&3))
    retval=$?
    IFS=${oIFS}

    case ${retval} in
        0)
            echo "${choice}";;
        1)
            ;;
        255)
            ;;
    esac
}

set_user_pass()
{
    local choice=
    local currentname="${1}"
    local userflag="0"
    local passflag="1"

    if [[ ${ACTION} == "edit" ]]; then
        if [[ ${2} == "username" ]]; then
            passflag="2"
        elif [[ ${2} == "password" ]]; then
            userflag="2"
        fi
    fi

    choice=($($DIALOG --keep-tite --title "${ACTION} ${TYPE}" --ok-label "Submit" --insecure \
                      --mixedform " " 0 0 0 \
                      "Username        :" 1 1 "${currentname}" 1 20 20 0 ${userflag} \
                      "Password        :" 2 1 "" 2 20 20 0 ${passflag} \
                      "Retype password :" 3 1 "" 3 20 20 0 ${passflag} 3>&1 1>&2 2>&3))

    local retval=$?

    case $retval in
        0)
            if [[ ( ${2} == "password" || ( ${choice[0]} != "" && ! $(grep "${TYPE},${choice[0]}," ${USERFILE}) ) ) && 
                  ( ${2} == "username" || ( ${choice[1]} == ${choice[2]} && ${choice[1]} != "" ) ) ]]; then
                NEWNAME="${choice[0]}"
                NEWPASS=$(echo "${choice[1]}" | sha256sum | awk '{ print $1 }')
            elif [[ ${choice[1]} != ${choice[2]} ]]; then
                sent_message "Password incorrect" "The passwords don't match" set_user_pass
            elif [[ ${choice[1]} == "" ]]; then
                sent_message "Password empty" "The password can't be empty" set_user_pass
            elif [[ ${choice[0]} == "" ]]; then
                sent_message "Username empty" "The username can't be empty" set_user_pass
            else
                sent_message "User exists" "This username already exists" set_user_pass
            fi;;
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
    choice=$($DIALOG --keep-tite --title "${ACTION} ${TYPE}" --no-tags --checklist " " 0 0 0 ${MENUTEXT} 3>&1 1>&2 2>&3)
    retval=$?
    IFS=${oIFS}

    case $retval in
    0)
        NEWRIGHTS=${choice[@]};;
    1)
        exit;;
    255)
        exit;;
    esac
}

write_changes()
{
    if [[ ${TYPE} == "user" ]]; then
        if [[ ${ACTION} == "create" ]]; then
            echo "${TYPE},${NEWNAME},${NEWPASS},${NEWRIGHTS}" >> ${USERFILE}
        else
            oIFS=${IFS}
            IFS=","
            local entry=($(grep "${TYPE},${USER}," ${USERFILE}))
            IFS=${oIFS}
            local oldentry=$(grep "${TYPE},${USER}," ${USERFILE})
            local user="${entry[1]}"
            local pass="${entry[2]}"
            local rights="${entry[3]}"

            sed -i "s/${oldentry}/${TYPE},${NEWNAME:-$user},${NEWPASS:-$pass},${NEWRIGHTS:-$rights}/" ${USERFILE}
        fi
#    elif [[ ${TYPE} == "group" ]]; then
#        if [[ ${ACTION} == "create" ]]; then
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

    $DIALOG --keep-tite --title "${title}" --msgbox "${message}" 0 0
    ${action}
}

get_menu()
{
    local menu=${1:-"0"}
    local spacer=${2:-""}

    grep "^item,$menu\." $MENUFILE > /tmp/mypipe${menu}

    while read item;
    do

            local selectstatus="OFF"

            # Temporarily set field seperator to ,
            oIFS=${IFS}
            IFS=","

            # Read row into array
            local itemarray=(${item})

            # Reset field seperator
            IFS=${oIFS}

            if [[ ${ACTION} != "create" ]]; then
                members="$(awk -F',' -v username=${NAME} '{ if ($1 == "user" && $2 == username) print $4 }' ${USERFILE})"

                if [[ " ${members} " =~ ${itemarray[1]} ]]; then
                    local selectstatus="ON"
                fi
            fi

            if [[ ${MENUTEXT} == "" ]]; then
                MENUTEXT="${itemarray[1]}/${spacer}${itemarray[2]}/${selectstatus}"
            else
                MENUTEXT="${MENUTEXT}/${itemarray[1]}/${spacer}${itemarray[2]}/${selectstatus}"
            fi


            if [[ ${itemarray[3]} == "menu" ]]; then
                get_menu ${itemarray[4]} "${spacer}|  "
            fi
    done < /tmp/mypipe${menu}

    rm /tmp/mypipe${menu} 2>/dev/null
}

select_edit_action()
{

}

handle_action()
{
    case ${TYPE} in
        "user")
            case ${ACTION} in
                "show")
                    get_item "user" "menu"
                    ;;
                "create")
                    set_user_pass
                    set_rights
                    write_changes
                    ;;
                "copy")
                    ;;
                "edit")
                    NAME=$(get_item "user" "menu")
                    select_edit_action
                    ;;
                "delete")
                    get_item "user" "checklist"
                    ;;
            esac;;
        "group")
            case ${ACTION} in
                "show")
                    get_item "group" "menu"
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
