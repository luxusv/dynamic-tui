#!/bin/env sh

# Define variables
TEMPFILE="/tmp/temp$$"

DIALOG=${DIALOG=dialog}
parent[0]=0 
menu=0
MENUFILE="/root/git/dynamic-tui/includes/menu.csv"
USERFILE="/root/git/dynamic-tui/includes/users.csv"
USER=""
RIGHTS=

login()
{
    local choice=

    choice=($($DIALOG --keep-tite --title "Login" --ok-label " Login" --insecure --mixedform " " 0 0 0 \
                      "Username :" 1 1 "" 1 20 20 0 0 \
                      "Password :" 2 1 "" 2 20 20 0 1 3>&1 1>&2 2>&3))

    local retval=$?

    case $retval in
        0)
            local pass=$(echo ${choice[1]} | sha256sum | awk '{ print $1 }')
            oIFS=${IFS}
            IFS=","
            local entry=($(grep "^user,${choice[0]},${pass}," ${USERFILE}))
            IFS=${oIFS}

            if [[ ${entry[0]} == "user" ]]; then
                USER="${entry[1]}"
                RIGHTS="${entry[3]} $(awk -F',' -v user="${USER}" '{ if ( $1 == "group" && $3 ~ "(^|\\s)"user"(\\s|$)" ) print $4 }' ${USERFILE})"
                # Deduplicate the rights
                RIGHTS=$(echo "${RIGHTS}" | tr ' ' '\n' | sort -u | tr '\n' ' ')

                show_menu 0
            fi;;
        1)
            exit;;
        255)
            exit;;
    esac
}

show_menu()
{
    oIFS="${IFS}"
    IFS=","
    local menuarray=($(grep "menu,${1}," ${MENUFILE}))
    IFS=${oIFS}

    if [[ ${menustring[0]} == "menu"  ]]; then
        handle_error "No menu with ID ${1} has been defined!"
    fi

    local menuitems=""

    grep "^item,${menu}\." ${MENUFILE} > ${TEMPFILE}

    while read line; do
        oIFS="${IFS}"
        IFS=","
        local itemarray=(${line})
        IFS=${oIFS}

        color=""
        [[ " ${RIGHTS} " =~ " ${itemarray[1]} " ]] || color="\Z4"

        number=$(echo ${itemarray[1]} | cut -d . -f2)
        name=${itemarray[2]}
        if [[ ${menuitems} == "" ]]; then
            menuitems="${number}/${color}${name}\Zn"
        else
            menuitems="${menuitems}/${number}/${color}${name}\Zn"
        fi
    done < ${TEMPFILE}

    if [[ ${menuitems} != "" ]]; then
        oIFS="${IFS}"
        IFS="/"
        choice=$($DIALOG --keep-tite --colors --title "${menuarray[2]}" --backtitle "${backarray[3]}" --menu "${menuarray[4]}" 0 0 10 ${menuitems} 3>&1 1>&2 2>&3)
        retval=$?
        IFS=${oIFS}

        case ${retval} in
            0)
                handle_choice ${choice};;
            1)
                finish;;
            255)
                finish;;
        esac
    else
        handle_error "A menu with ID $1 has been defined but has no items!"
    fi
}

handle_choice()
{
    choice=$1

    if [[ " ${RIGHTS} " =~ " ${menu}.${choice} " ]]; then
        oIFS="${IFS}"
        IFS=","
        line=($(grep "$menu\.$choice" $MENUFILE))
        IFS=${oIFS}
    
        itemtype=${line[3]}
        itemvalue=${line[4]}
        itemparameters=${line[5]}
    
        if [[ $itemtype == "menu" ]]; then
            handle_parent add ${menu}
            menu=${itemvalue}
            show_menu $menu
        elif [[ $itemtype == "script" ]]; then
            if [[ -f ${itemvalue} && -x ${itemvalue} ]]; then
                ${itemvalue} ${itemparameters}
                show_menu $menu
            else
                handle_error "No script ${itemvalue} available or executable!"
            fi
        fi
        exit
    else
        handle_error "The chosen action is not allowed!"
    fi
}

handle_error()
{
    errortext=$1

    $DIALOG --clear --keep-tite --title "Error" --msgbox "${errortext}" 0 0

    finish "noexit"
}

handle_parent()
{
    count=${#parent[@]}

    case $1 in
        add)
            parent[${count}]=$2;;
        remove)
            unset parent[$((count-1))];;
        get)
            echo ${parent[$((count-1))]};;
    esac
}

finish()
{
    if [[ $(handle_parent get) == 0 && ${menu} == 0 && ${1} != "noexit" ]]; then
        exit
    elif [[ ${1} == "noexit" ]]; then
        show_menu $menu
    else
        menu=$(handle_parent get)
        handle_parent remove
        show_menu $menu
    fi
}

login
