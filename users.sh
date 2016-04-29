#!/bin/env sh

# Get cli options
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

#Define variables
DIALOG=${DIALOG=dialog}
USERFILE="/root/git/dynamic-tui/includes/users.csv"
MENUFILE="/root/git/dynamic-tui/includes/menu.csv"

reset_var()
{
NAME=""
PASS=""
NEWNAME=""
NEWPASS=""
NEWMEMBERS=""
NEWRIGHTS=""
MENUTEXT=""
RETURN=false
}

get_item()
{
    local choice=
    local itemtype="${1}"
    local menutype="${2}"
    local spacer=""
    local members=
    local tmplist=
    local itemlist=

    tmplist=($(awk -F',' -v itemtype=${itemtype} '{ if (itemtype == "all" && $1 == "user") 
                                                        print $2;
                                                    else if (itemtype == "all" && $1 == "group")
                                                        print "@"$2;
                                                    else if ($1 == itemtype)
                                                        print $2;
                                                  }' ${USERFILE}))

    if [[ ${menutype} == "checklist" && ${TYPE} == "user" ]]; then
        members=" $(awk -F',' -v name="${NAME}" '{ if ($1 == "group" && $3 ~ "(^|\\s)"name"(\\s|$)") print $2 }' ${USERFILE} | tr '\n' ' ') "
    elif [[ ${menutype} == "checklist" && ( ${TYPE} == "group") ]]; then
        members=" $(awk -F',' -v group="${NAME}" '{ if ($1 == "group" && $2 == group) print $3 }' ${USERFILE}) "
    fi

    for item in ${tmplist[@]}; do
        [[ ${itemlist} != "" ]] && spacer="/"
        case ${menutype} in
            "menu") 
                itemlist="${itemlist}${spacer}${item}";;
            "radiolist")
                itemlist="${itemlist}${spacer}${item}";;
            "checklist")
                if [[ " ${NEWMEMBERS:-$members} " =~ " ${item} " ]]; then
                    itemlist="${itemlist}${spacer}${item}/ON"
                else
                    itemlist="${itemlist}${spacer}${item}/OFF"
                fi
        esac
    done

    #If there's only one item add // for dialog not to crash
    if [[ ! ${itemlist} =~ "/" ]]; then
        itemlist="${itemlist}//"
    fi

    oIFS=${IFS}
    IFS="/"
    choice=($($DIALOG --keep-tite --no-items --title "${ACTION} ${TYPE}" --${menutype} "Make a choice" 0 0 0 ${itemlist} 3>&1 1>&2 2>&3))
    retval=$?
    IFS=${oIFS}

    case ${retval} in
        0)
            if [[ ${itemtype} == "all" && ${choice} == "" ]]; then
                choice="clear-it"
            fi
            echo "${choice}";;
        1)
            exit 1;;
        255)
            exit 255;;
    esac
}

get_menu()
{
    local menu=${1:-"0"}
    local spacer=${2:-""}

    grep "^item,$menu\." $MENUFILE > /tmp/mypipe${menu}
    members="${NEWRIGHTS:-$(awk -F',' -v itype=${TYPE} -v iname=${NAME} '{ if ($1 == itype && $2 == iname) print $4 }' ${USERFILE})}"

    while read item;
    do
        local selectstatus="OFF"

        # Temporarily set field seperator to , and read row into array
        oIFS=${IFS}
        IFS=","
        local itemarray=(${item})
        IFS=${oIFS}

        [[ " ${members} " =~ " ${itemarray[1]} " ]] && local selectstatus="ON"

        if [[ ${MENUTEXT} == "" ]]; then
            MENUTEXT="${itemarray[1]}/${spacer}${itemarray[2]}/${selectstatus}"
        else
            MENUTEXT="${MENUTEXT}/${itemarray[1]}/${spacer}${itemarray[2]}/${selectstatus}"
        fi

        [[ ${itemarray[3]} == "menu" ]] && get_menu ${itemarray[4]} "${spacer}|  "
    done < /tmp/mypipe${menu}

    rm /tmp/mypipe${menu} 2>/dev/null
}

set_name_pass()
{
    local choice=
    local extrabutton=""
    local edittype="${1}"
    local userflag="0"
    local passflag="1"
    if [[ ${ACTION} == "copy" ]]; then
        local currentname="${NEWNAME}"
    else
        local currentname="${NEWNAME:-${NAME}}"
    fi

    [[ ${ACTION} != "create" ]] && local extrabutton="--extra-button"

    [[ ${TYPE} == "group" ]] && edittype="username"

    if [[ ${ACTION} == "edit" ]]; then
        if [[ ${edittype} == "username" ]]; then
            passflag="2"
        elif [[ ${edittype} == "password" ]]; then
            userflag="2"
        fi
    fi

    if [[ ${TYPE} == "user" ]]; then
        choice=($($DIALOG --keep-tite --title "${ACTION} ${TYPE}" --ok-label "Submit" --insecure ${extrabutton} --extra-label "Return" \
                          --mixedform " " 0 0 0 \
                          "Username        :" 1 1 "${currentname}" 1 20 20 0 ${userflag} \
                          "Password        :" 2 1 "${PASS}" 2 20 20 0 ${passflag} \
                          "Retype password :" 3 1 "${PASS}" 3 20 20 0 ${passflag} 3>&1 1>&2 2>&3))
    else
        choice=($($DIALOG --keep-tite --title "${ACTION} ${TYPE}" --ok-label "Submit" --insecure ${extrabutton} --extra-label "Return" \
                          --mixedform " " 0 0 0 \
                          "Groupname        :" 1 1 "${currentname}" 1 20 20 0 0 3>&1 1>&2 2>&3))
    fi

    local retval=$?

    case $retval in
        0)
            if [[ ( ${edittype} == "password" || ( ${choice[0]} != "" && ! $(grep "${TYPE},${choice[0]}," ${USERFILE}) ) ) && 
                  ( ${edittype} == "username" || ( ${choice[1]} == ${choice[2]} && ${choice[1]} != "" ) ) ]]; then
                NEWNAME="${choice[0]}"
                if [[ ${edittype} != "username" ]]; then
                    PASS="${choice[1]}"
                    NEWPASS=$(echo "${choice[1]}" | sha256sum | awk '{ print $1 }')
                fi
                if [[ ${ACTION} == 'edit' ]]; then
                    write_changes
                fi
            elif [[ ${choice[1]} != ${choice[2]} ]]; then
                sent_message "Password incorrect" "The passwords don't match" set_name_pass
            elif [[ ${edittype} != "username" && ${choice[1]} == "" ]]; then
                sent_message "Password empty" "The password can't be empty" set_name_pass
            elif [[ ${choice[0]} == "" ]]; then
                sent_message "${TYPE}name empty" "The ${TYPE}name can't be empty" set_name_pass
            else
                sent_message "${TYPE} exists" "This ${TYPE}name already exists" set_name_pass
            fi;;
        1)
            exit;;
        3)
            RETURN=true
            handle_action;;
        255)
            exit;;
    esac
}

set_rights()
{
    local retval=
    local choice=

    MENUTEXT=""

    get_menu

    oIFS=${IFS}
    IFS="/"
    choice=$($DIALOG --keep-tite --title "${ACTION} ${TYPE}" --no-tags --extra-button --extra-label "Return" --checklist " " 0 0 0 ${MENUTEXT} 3>&1 1>&2 2>&3)
    retval=$?
    IFS=${oIFS}

    case $retval in
        0)
            NEWRIGHTS=${choice[@]}
            if [[ ${ACTION} == 'edit' ]]; then
                write_changes
            fi;;
        1)
            exit;;
        3)
            NEWRIGHTS=${choice[@]}
            RETURN=true
            handle_action;;
        255)
            exit;;
    esac
}

set_group_membership()
{
    if [[ ${TYPE} == "user" ]]; then
        NEWMEMBERS=$(get_item "group" "checklist")
        retval=$?
    else
        NEWMEMBERS=$(get_item "all" "checklist")
        retval=$?
    fi

    if [[ ${ACTION} == 'edit' && ${retval} -eq 0 ]]; then
        write_changes
    fi
}

write_changes()
{
    ${DIALOG} --keep-tite --title "Confirm changes" --yesno "Are you sure you want to save the changes?" 0 0
    local retval=$?
    case ${retval} in
        0)
            if [[ ${ACTION} == "create" || ${ACTION} == "copy" ]]; then
                echo "${TYPE},${NEWNAME},${NEWPASS:-"$NEWMEMBERS"},${NEWRIGHTS}" >> ${USERFILE}
                write_group_membership
            else
                local oldentry=$(grep "${TYPE},${NAME}," ${USERFILE})
                oIFS=${IFS}
                IFS=","
                local entry=(${oldentry})
                IFS=${oIFS}
                local user="${entry[1]}"
                local pass_or_members="${entry[2]}"
                local rights="${entry[3]}"

                if [[ ${TYPE} == "user" ]]; then
                    sed -i "s/${oldentry}/${TYPE},${NEWNAME:-$user},${NEWPASS:-$pass_or_members},${NEWRIGHTS:-$rights}/" ${USERFILE}
                    write_group_membership
                else
                    if [[ ${NEWMEMBERS} == "clear-it" ]]; then
                        sed -i "s/${oldentry}/${TYPE},${NEWNAME:-$user},,${NEWRIGHTS:-$rights}/" ${USERFILE}
                    else
                        sed -i "s/${oldentry}/${TYPE},${NEWNAME:-$user},${NEWMEMBERS:-$pass_or_members},${NEWRIGHTS:-$rights}/" ${USERFILE}
                    fi
                fi
            fi;;
        1)
            exit;;
        3)
            RETURN=true
            handle_action;;
        255)
            exit;;
    esac
}

write_group_membership()
{
    # Add user to new groups
    for group in ${NEWMEMBERS}; do
        local oldgroupentry=$(grep "group,${group}," ${USERFILE})
        oIFS=${IFS}
        IFS=","
        local groupentry=(${oldgroupentry})
        IFS=${oIFS}

        if ! [[ " ${groupentry[2]} " =~ " ${NEWNAME:-$user} " ]]; then
            if [[ ${groupentry[2]} != "" ]]; then
                sed -i "s/${oldgroupentry}/group,${group},${groupentry[2]} ${NEWNAME:-$user},${groupentry[3]}/" ${USERFILE}
            else
                sed -i "s/${oldgroupentry}/group,${group},${NEWNAME:-$user},${groupentry[3]}/" ${USERFILE}
            fi
        fi
    done

    if [[ ${ACTION} == "edit" ]]; then
        # Remove user from deselected groups
        local oldgroups="$(awk -F',' -v name="${NAME}" '{ if ($1 == "group" && $3 ~ "(^|\\s)"name"(\\s|$)") print $2 }' ${USERFILE} | tr '\n' ' ')"
        for group in ${oldgroups}; do
            if ! [[ " ${NEWMEMBERS} " =~ " ${group} " ]]; then
                local oldgroupentry=$(grep "group,${group}," ${USERFILE})
                local newgroupentry=$(echo ${oldgroupentry} | sed "s/ ${NEWNAME:-$user} / /" | sed "s/,${NEWNAME:-$user} /,/" | sed "s/ ${NEWNAME:-$user},/,/" | sed "s/group,${group},${NEWNAME:-$user},/group,${group},,/")
                sed -i "s/${oldgroupentry}/${newgroupentry}/" ${USERFILE}
            fi
        done
    
        # Rename user in groups
        if [[ ${NEWNAME} != "" ]]; then
            sed -i "s/,${user},/,${NEWNAME},/" ${USERFILE}
            sed -i "s/,${user} /,${NEWNAME},/" ${USERFILE}
            sed -i "s/ ${user},/,${NEWNAME},/" ${USERFILE}
            sed -i "s/ ${user} /,${NEWNAME},/" ${USERFILE}
        fi
    fi
}

delete_user_group()
{
    ${DIALOG} --keep-tite --title "Confirm removal" --extra-button --extra-label "Return" --yesno "Are you sure you want to delete the selected ${TYPE}(s)?" 0 0
    local retval=$?
    case ${retval} in
        0)
            for item in ${NAME[@]}; do
                sed -i "/^${TYPE},${item},*/d" ${USERFILE}
            done;;
        1)
            exit;;
        3)
            RETURN=true
            handle_action;;
        255)
            exit;;
    esac
}

sent_message()
{
    local title="${1}"
    local message="${2}"
    local action="${3}"

    $DIALOG --keep-tite --title "${title}" --msgbox "${message}" 0 0
    ${action}
}

select_edit_action()
{

    if [[ ${TYPE} == "user" ]]; then
        options=("Username" "Password" "Memberships" "Rights")
    else
        options=("Groupname" "Members" "Rights")
    fi

    choice=($($DIALOG --keep-tite --no-items --title "${ACTION} ${TYPE}" --no-tags --extra-button --extra-label "Return" --menu "What would you like to change?" 0 0 0 ${options[@]} 3>&1 1>&2 2>&3))
    retval=$?

    case $retval in
    0)
        case ${choice} in
        Username|Groupname)
            set_name_pass "username";;
        Password)
            set_name_pass "password";;
        Members|Memberships)
            set_group_membership;;
        Rights)
            set_rights;;
        esac;;
    1)
        exit;;
    3)
        RETURN=true
        handle_action;;
    255)
        exit;;
    esac
}

handle_action()
{
    if [[ ! ${RETURN} ]]; then
        reset_var
    else
        RETURN=false
    fi

    case ${ACTION} in
        "show")
            NAME=$(get_item "${TYPE}" "menu")
            ;;
        "create")
            set_name_pass
            set_rights
            set_group_membership
            write_changes
            ;;
        "copy")
            NAME=$(get_item "${TYPE}" "menu")
            if [[ ${NAME} != "" ]]; then
                set_name_pass
                set_rights
                set_group_membership
                write_changes
            fi;;
        "edit")
            NAME=$(get_item "${TYPE}" "menu")
            if [[ ${NAME} != "" ]]; then
                select_edit_action
            fi;;
        "delete")
            NAME=($(get_item "${TYPE}" "checklist"))
            if [[ ${NAME} != "" ]]; then
                delete_user_group
            fi;;
    esac
}

handle_action
