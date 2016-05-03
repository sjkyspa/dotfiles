#! /bin/zsh

bgulpl()
{
    # subshell to avoid changing directory
    (
        cd ~/code/boron-unstable/boron/web_applications/;
        gulp --silent --reporter=simple "$@"
    )
}

alias bgulp='bgulpl --nolint'

alias lbiosite='/home/david/code/boron-unstable/scripts/launch-biosite-single-terminal.sh'

bgulpr()
{
    bgulp "$@" && refresh-browser.sh
}

bgulplr()
{
    bgulpl "$@" && refresh-browser.sh
}

aburl()
{
    burl "$1" \
         -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJyb290In0.KeGNGBnBlQ5aiWv_3k1tMuxySXQwaEwbkb__Dqgu9T8' \
         "${@:2}"
}

acurl() {
    curl "$1" \
         -k \
         -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJyb290In0.KeGNGBnBlQ5aiWv_3k1tMuxySXQwaEwbkb__Dqgu9T8' \
         "${@:2}"
}

burl()
{
    if [[ "$#" < 1 ]] || [[ "$1" = "-h" ]]; then
        echo "Usage: bcurl [boron_api_server_path] [curl opts]" 1>&2
        return 1
    fi

    curl \
        -k  \
        "https://localhost:8088${1}" \
        "${@:2}"
}

alias boron-client='/home/david/code/boron-unstable/build/bin/boron-client'
