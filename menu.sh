#!/bin/env sh

tempfile=$(tempfile 2>/dev/null) || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15

DIALOG=${DIALOG=whiptail}
parent[0]=0 
menu=0
menufile="/root/git/dynamic-tui/includes/menu.csv"

show_menu()
{
    if [[ ! $(grep "menu,${1}," ${menufile}) ]]; then
        handle error "No menu with ID ${1} has been defined!"
    fi

    menutitle=$(grep "^menu,${menu}" ${menufile} | cut -d , -f3)
    backtitle=$(grep "^menu,${menu}" ${menufile} | cut -d , -f4)
    menutext=$(grep "^menu,${menu}" ${menufile} | cut -d , -f5)
    menuitems=""
    while read line; do
        if [[ $(echo ${line} | grep "^item,${menu}\.") ]]; then
            number=$(echo ${line} | cut -d , -f2 | cut -d . -f2)
            name=$(echo ${line} | cut -d , -f3)
            if [[ ${menuitems} == "" ]]; then
                menuitems="${number}/${name}"
            else
                menuitems="${menuitems}/${number}/${name}"
            fi
        fi
    done < ${menufile}

    if [[ ${menuitems} != "" ]]; then
        oIFS="${IFS}"
        IFS="/"
        $DIALOG --clear --title "${menutitle}" --backtitle "${backtitle}" --menu "${menutext}" 0 0 10 ${menuitems} 2>$tempfile
        retval=$?
        IFS=${oIFS}

        choice=$(cat $tempfile)

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
    line=$(grep "$menu\.$choice" $menufile)
    itemtype=$(echo $line | cut -d , -f4)
    itemvalue=$(echo $line | cut -d , -f5)
    if [[ $itemtype == "menu" ]]; then
        handle_parent add ${menu}
        menu=${itemvalue}
        show_menu $menu
    elif [[ $itemtype == "script" ]]; then
        if [[ -f ${itemvalue} && -x ${itemvalue} ]]; then
            ${itemvalue}
        else
            handle_error "No script ${itemvalue} available or executable!"
        fi
    fi
    exit
}

handle_error()
{
    errortext=$1

    $DIALOG --clear --title "Error" --msgbox "${errortext}" 0 0

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
