#!/usr/bin/env bash
#
#  Author: Hari Sekhon
#  Date: 2015-11-05 20:53:32 +0000
#

# ============================================================================ #
#                                  D o c k e r
# ============================================================================ #

# shellcheck disable=SC1090
[ -f ~/.docker_vars ] && . ~/.docker_vars

alias dps='docker ps'
alias dpsa='docker ps -a'
alias dst="dockerhub_show_tags.py"
# -l shows latest container, -q shows only ID
alias dl='docker ps -lq'
alias dockerimg='$EDITOR $HOME/docker-images.txt'

# wipe out exited containers
alias dockerrm='docker rm $(docker ps -qf status=exited)'

# wipe out dangling image layers
#alias dockerrmi='docker rmi $(docker images -q --filter dangling=true)'
dockerrmi(){
    # want word splitting here
    # shellcheck disable=SC2046
    docker rmi $(docker images -q --filter dangling=true)
}

# starts the docker VM, shows ASCII whale, but slow
#alias dockershell="/Applications/Docker/Docker\ Quickstart\ Terminal.app/Contents/Resources/Scripts/start.sh"
# better
#alias dockervm="VBoxManage controlvm startvm default"
#alias dockervm="docker-machine start default"

#alias dm="docker-machine"
#alias dockerrr="docker-machine restart default"
#alias dockerreload="docker-machine env default > '$srcdir/.docker_vars'; . '$srcdir/.docker_vars'"

#dockerstart(){
#    if ! docker-machine status default | grep -q Running; then
#        docker-machine start default
#        sleep 20
#    fi
#    docker start $(cat "$srcdir/docker-start.txt")
#}

# avoid external commands per shell, slows down new shells and wastes battery
# switched to using ~/.docker_vars file which is cheaper due to less forks and picked up in each new shell
#if which docker-machine &>/dev/null; then
#    if docker-machine status default | grep -q -e Started -e Running; then
#        eval $(docker-machine env default)
#    fi
#fi

#alias dockerr="docker run --rm -ti"
function dockerr(){
    local args=""
    for x in "$@"; do
        if [ "${x:0:1}" = "/" ]; then
            if [[ "$x" != */Users/* && "$x" != */home/* ]] &&
               [ "$(strLastIndexOf "$x" / )" -eq 1 ]; then
                x="harisekhon$x"
            fi
        fi
        args="$args $x"
    done
    eval docker run --rm -ti "$args"
}

dockerrma(){
    # would use xargs -r / --no-run-if-empty but that is GNU only, doesn't work on Mac
    local ids
    ids="$(
        docker ps -a --format "{{.ID}} {{.Names}}" |
        grep -vi -f ~/docker-perm.txt 2>/dev/null |
        awk '{print $1}'
    )"
    if [ -n "$ids" ]; then
        docker rm -f "$@"
        # shellcheck disable=SC2086
        docker rm $ids
    fi
}

dockerrmigrep(){
    for x in "$@"; do
        docker images | grep "$x" | grep -v "<none>" | awk '{print $1":"$2}' | xargs docker rmi
    done
}

dockerip(){
    docker inspect --format '{{ .NetworkSettings.IPAddress }}' "$@"
}

# this goes to the last created and sometimes exited container
#alias dockere='docker exec -ti $(docker ps -lq) /bin/bash'
dockere(){
    if [ $# -gt 0 ]; then
        container="$(docker ps | grep -i "$1" | awk '{print $1}' | head -n1)"
    else
        container="$(docker ps -q | head -n1)"
    fi
    docker exec -ti "$container" /bin/sh
}

docker_get_images(){
    # uniq_order_preserved.pl is in the DevOps-Perl-tools repo on github and should be in the $PATH
    echo "$(dockerhub_search.py harisekhon -n 1000 | tail -n +2 | awk '{print $1}' | sort) $(sed 's/#.*//;/^[[:space:]]*$/d' ~/docker-images.txt | uniq_order_preserved.pl)"
}

dockerpull1(){
    # pull only latest tag, mine first, then official
    local images="${*:-}"
    [ -z "$images" ] && images="$(docker_get_images)"
    images="$(grep -v ":" <<< "$images")"
    whendone "docker pull" # must be first arg so quoted, [l] trick not needed as grep -v grep's
    for image in $images; do
        #whendone "docker pull" # must be first arg so quoted, [l] trick not needed as grep -v grep's
        timestamp "docker pull $image"
        #docker pull "$image" | cat &
        docker pull "$image"
        # wipe out dangling image layers
        # don't quote, we want splitting
        # shellcheck disable=
        dockerrmi
        echo
    done
}
dockerpullgithub(){
    dockerpull1 harisekhon/{nagios-plugins,pytools,tools,centos-github,debian-github,ubuntu-github,alpine-github}
}

dockerpull(){
    local images="${*:-}"
    [ -z "$images" ] && images="$(docker_get_images)"
    dockerpull1 "$images"
    images="$(grep -i -e harisekhon -e ":" <<< "$images")"
    #local images="$(grep -i -e ":" <<< "$images")"
    # now pull all tags, mine first, then official
    whendone "docker pull" # must be first arg so quoted, [l] trick not needed as grep -v grep's
    for image in $images; do
        #whendone "docker pull" # must be first arg so quoted, [l] trick not needed as grep -v grep's
        if [[ "$image" = harisekhon/* && ! "$image" =~ ":" ]]; then
            [[ "$image" =~ presto.*-dev ]] && continue
            for tag in $(dockerhub_show_tags.py -q "$image" | grep -v '^latest$'); do
                timestamp "docker pull $image:$tag"
                #docker pull "$image":"$tag" | cat &
                docker pull "$image":"$tag"
                echo
            done
        else
            timestamp docker pull "$image"
            #docker pull "$image" | cat &
            docker pull "$image"
            echo
        fi
        # wipe out dangling image layers
        dockerrmi
    done
}

dockerpull1r(){
    while true; do
        dockerpull1 "$@"
        wait
        echo -e "\n\nsleeping for 1 hour\n\n"
        sleep 3600
    done
}

dockerpullr(){
    while true; do
        dockerpull "$@"
        wait
        echo -e "\n\nsleeping for 1 hour\n\n"
        sleep 3600
    done
}

# quick, only pull things for which we don't already have local images
dockerpullq(){
    for x in $(docker_get_images); do
        docker images | grep -q "^${x}[[:space:]]" && continue
        whendone "docker pull" # must be first arg so quoted, [l] trick not needed as grep -v grep's
        timestamp docker pull "$x"
        docker pull "$x"
    done
    # wipe out dangling image layers
    dockerrmi
}