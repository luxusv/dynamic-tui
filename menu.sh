#!/bin/env sh

TEMPFILE="/tmp/temp$$"

DIALOG=${DIALOG=dialog}
parent[0]=0 
menu=0
MENUFILE="/root/git/dynamic-tui/includes/menu.csv"

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

        number=$(echo ${itemarray[1]} | cut -d . -f2)
        name=${itemarray[2]}
        if [[ ${menuitems} == "" ]]; then
            menuitems="${number}/${name}"
        else
            menuitems="${menuitems}/${number}/${name}"
        fi
    done < ${TEMPFILE}

    if [[ ${menuitems} != "" ]]; then
        oIFS="${IFS}"
        IFS="/"
        local choice=$($DIALOG --clear --keep-tite --title "${menuarray[2]}" --backtitle "${backarray[3]}" --menu "${menuarray[4]}" 0 0 10 ${menuitems} 3>&1 1>&2 2>&3)
        retval=$?
        IFS=${oIFS}

        echo "retval = ${retval}"

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
        clear
        exit
    else
        menu=$(handle_parent get)
        handle_parent remove
        show_menu $menu
    fi
}

show_menu 0
