#!/bin/bash

#Permet de se retirer des projets Gitlab partagés, notamment, par les étudiants
#Pour une année donnée, trouver tous les projets partagés, et les lister dans un fichier csv.
#ATTENTION : liste tous les projets partagés, pas uniquement ceux des étudiants ! Ci besoin, faire le tri dans le fichier csv généré
#L'option --leave parcourt le fichier csv et quitte le projet correspondant à la ligne parcourue

#Pierre STRAEBLER - Septembre 2024

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/.env"
leave=false
year=""

#verifie si une précédente version d'un csv généré existe
function checkCSV(){
    if [ -f "$CSV_FILE" ] ; then
        return 0
    else
        return 1
    fi
}

#verifie si le csv des projets à supprimer existe
function checkCSVToLeave(){
    if [ -f "$CSV_FILE_TOLEAVE" ] ; then
        return 0
    else
        return 1
    fi
}

#les varaibles sont déclarées dans le fichier .env du projet
function checkVar(){
    if [ -z "$USER_ID" ] || [ -z "$PRIVATE_TOKEN" ] || [ -z "$GITLAB_SERVER" ]  ; then
        return 1
    else
        return 0
    fi
}

#recuperer les id des projets de l'année passée en paramètre
# malgré &owned=false, l'api me renvoie aussi mes propres projets.
#On doit pouvoir exclure avec jq les entrées dont le owner.id correspond à notre propre id. Mes quelques tests n'ont pas été concluants.
#Du coup, je filtre manuellement avec un grep
#Sinon, possible de jouer avec les 'access_level' ?
function getProjects(){
    #supprimer un éventuel ancien fichier csv
    if checkCSV ; then
        rm -f "$CSV_FILE"
    fi
    #l'API ne peut renvoyer que 100 résultats par page max. Il faut donc d'abord trouver le nombre total de page (via le header HTTP), puis les parcourir
    URL="https://$GITLAB_SERVER/api/v4/projects?membership=true&owned=false&per_page=100"
    echo "Finding total pages for all projects..."
    currentPage="1"
    totalPages=1 #en cas d'erreur de la requete ci-dessous, totalPage sera tout de même cohérent
    totalPages=$(curl --silent --head --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" "$URL&page=$currentPage" \
    | grep -i 'x-total-pages:' | awk -F' ' '{print $2}' | tr -d '\r') #le tr permet de supprimer le caractère de retour chariot
    echo "Found $totalPages pages."
    sleep 2
    echo "Fetching all shared projects created in $year..."
    while [[ $currentPage -le $totalPages ]]; do
        curl --silent --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" "$URL&page=$currentPage" \
        | jq -r 'map(select(.created_at | startswith('\""$year"\"')) | [.owner.id, .id, .name_with_namespace] | @csv) | .[]'\
         | grep -v "$USER_ID" >> "$CSV_FILE"
        currentPage=$((currentPage + 1))
    done
    #si le fichier est vide, on arrete le script
    if ! [ -s "$CSV_FILE" ] ; then
        echo "No shared projects found in $year."
        rm -f "$CSV_FILE"
        return 1
    fi
    return 0    
    }

#verifier les parametres passés
function checkArgs(){
    for arg in "$@" ; do
        if [[ "$arg" == "--leave" ]]; then
            leave=true
        fi
        if [[ $arg =~ ^[0-9]{4}$ ]] ; then
            year="$arg"
            CSV_FILE="$SCRIPT_DIR/projects-$year.csv"
            CSV_FILE_TOLEAVE="projects-to-leave-$year.csv"
        fi
    done
}

#parcourir le fichier csv et se désincrire de chaque projet via l'api
function leaveProject(){
    if [ -f "$CSV_FILE_TOLEAVE" ] ; then
        while IFS= read -r project ; do
            projectID=$(echo "$project" | awk -F"," '{print $2}')
            projectName=$(echo "$project" | awk -F"," '{print $3}')
            echo "Leaving project $projectName (project id $projectID)..."
            sleep 1
            curl --silent --request DELETE --header "PRIVATE-TOKEN: $PRIVATE_TOKEN" "https://$GITLAB_SERVER/api/v4/projects/$projectID/members/$USER_ID"
        done < "$CSV_FILE_TOLEAVE"
        return 0
    else
        echo "Cannot find $CSV_FILE_TOLEAVE. Exiting here."
        return 1
    fi
}

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
        echo "Ctrl-C pressed. Exiting."
        exit 1
}

function main(){
    checkArgs "$@"
    if ! checkVar ; then
        echo "Missing GITLAB_SERVER, USER_ID and / or PRIVATE_TOKEN variable(s). Check your .env file"
        exit 1
    fi
    if [ -z "$year" ] ; then
        echo "Usage : $0 [--leave] YEAR-TO-LEAVE"
        exit 1
    fi
    if ! $leave ; then #si le parametre --leave a ete passé, on passe directement à la suppression des projets de l'année concernée
        if getProjects "$@" ; then
            echo ""
            echo "You will find all your shared projects into $CSV_FILE."
            echo "CAUTION : Please note that all projects shared with you are displayed, including those not belonging to students."
            echo "Please create a file named $CSV_FILE_TOLEAVE containing the csv rows corresponding to the projects you want to **leave**."
            echo "Once done, use '$0 $year --leave' to leave projects in the csv file."
            exit 0
        else
            exit 1
        fi
    else
        if checkCSVToLeave ; then
            echo "CAUTION : You will be removed from all shared projects presents in the file $CSV_FILE_TOLEAVE !"
            echo "Press Ctrl-C within 5 seconds to stop the script."
            sleep 5
            leaveProject
            return 0
        else
            echo "Cannot find $CSV_FILE_TOLEAVE file."
            return 1
        fi
    fi
}

main "$@"