#!/bin/env sh

#Define variables
DIALOG=${DIALOG=dialog}
MENUFILE="/root/git/dynamic-tui/includes/menu.csv"
PARENT=""
SCRIPTID=""
SCRIPTNAME=""
SCRIPTPATH=""
SCRIPTPARM=""

get_menu()
{
    if [[ $1 == "all" ]]; then
        local searchoption=".*"
    else
        local searchoption=${1:-".*"}
    fi

    local menu=${2:-"0"}
    local spacer=${3:-"|  "}

    grep "^item,$menu\.[0-9]*,.*,${searchoption},.*" $MENUFILE > /tmp/mypipe${menu}

    while read item;
    do
        # Temporarily set field seperator to , and read row into array
        oIFS=${IFS}
        IFS=","
        local itemarray=(${item})
        IFS=${oIFS}

        if [[ ${MENUTEXT} == "" ]]; then
            MENUTEXT="0/Main menu/${itemarray[1]}/${spacer}${itemarray[2]}"
        else
            MENUTEXT="${MENUTEXT}/${itemarray[1]}/${spacer}${itemarray[2]}"
        fi

        [[ ${itemarray[3]} == "menu" ]] && get_menu "${searchoption}" "${itemarray[4]}" "${spacer}|  "
    done < /tmp/mypipe${menu}


    rm /tmp/mypipe${menu} 2>/dev/null
}

select_top_level()
{
    get_menu "menu"
    oIFS=${IFS}
    IFS="/"
    choice=$(${DIALOG} --keep-tite --stdout --title "Menu" --no-tags --menu " " 0 0 0 ${MENUTEXT})
    retval=$?
    IFS=${oIFS}
    
    case ${retval} in
        0)
            if [[ ${choice} == "0" ]]; then
                PARENT="0"
            else
                PARENT=$(grep "^item,${choice}," ${MENUFILE} | awk -F',' '{ print $5 }')
            fi;;
        1)
            exit;;
        255)
            exit;;
    esac
}

select_id()
{
    local id="1"
    items="$(awk -F',' -v parent=${PARENT} '{ if ( $1 == "item" && $2 ~ "^"parent"." ) print $2 }' ${MENUFILE} | tr '\n' ' ')"

    while true; do
        if ! [[ " ${items} " =~ " ${PARENT}.${id} " ]]; then
            SCRIPTID=${id}
            break
        fi
        id=$(($id+1))
    done

    echo ${id}
}

add_script()
{
    local choice=
    local repeat=true

    while ${repeat}; do
        choice=($(${DIALOG} --keep-tite --stdout --title "Add script" --extra-button --extra-label "Browse" \
                            --form " " 0 0 0 \
                            "Name       :" 1 1 "${SCRIPTNAME}" 1 14 30 30 \
                            "Path       :" 2 1 "${SCRIPTPATH}" 2 14 30 300 \
                            "Parameters :" 3 1 "${SCRIPTPARM}" 3 14 30 300))
    
        local retval=$?
    
        case ${retval} in
            0)
                SCRIPTNAME=${choice[0]}
                SCRIPTPATH=${choice[1]}
                SCRIPTPARM=${choice[2]}
                repeat=false;;
            1)
                repeat=false;;
            3)
                SCRIPTNAME=${choice[0]}
                SCRIPTPATH=${choice[1]}
                SCRIPTPARM=${choice[2]}
                get_script_path
                repeat=true;;
            255)
                repeat=false;;
        esac
    done
}

get_script_path()
{
    local choice=
    local repeat=true

    while ${repeat}; do
        choice=$(${DIALOG} --keep-tite --stdout --help-button --title "Search script" --fselect ${HOME} 30 50)
    
        local retval=$?
    
        case ${retval} in
            0)
                SCRIPTPATH=${choice}
                repeat=false;;
            1)
                repeat=false;;
            2)
                ${DIALOG} --keep-tite --msgbox "blblblalalala" 0 0
                repeat=true;;
            255)
                repeat=false;;
        esac
    done
}

handle_action()
{
    exit
}

select_top_level
select_id
echo "id=${PARENT}.${SCRIPTID}"
#add_script

#add_script
#echo -e "${MENUTEXT}"
#handle_action
