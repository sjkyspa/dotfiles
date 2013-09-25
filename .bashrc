
# Start off with the Ubuntu defaults:

# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# # DON'T use this it ruins things for e.g. emacsserver (e.g. PATH variables
# # are wrong)
# # # If not running interactively, don't do anything
# [ -z "$PS1" ] && return

# don't put duplicate lines in the history. See bash(1) for more options
# ... or force ignoredups and ignorespace
HISTCONTROL=ignoredups:ignorespace

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=100000
HISTFILESIZE=200000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# # set a fancy prompt (non-color, unless we know we "want" color)
# case "$TERM" in
#     xterm-color) color_prompt=yes;;
# esac

# # uncomment for a colored prompt, if the terminal has the capability; turned
# # off by default to not distract the user: the focus in a terminal window
# # should be on the output of commands, not on the prompt
# force_color_prompt=yes

# if [ -n "$force_color_prompt" ]; then
#     if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
#         # We have color support; assume it's compliant with Ecma-48
#         # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
#         # a case would tend to support setf rather than setaf.)
#         color_prompt=yes
#     else
#         color_prompt=
#     fi
# fi

# # enable color support of ls and also add handy aliases
# if [ -x /usr/bin/dircolors ]; then
#     test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
# fi

# # Add an "alert" alias for long running commands.  Use like so:
# #   sleep 10; alert
# alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# # Alias definitions.
# # You may want to put all your additions into a separate file like
# # ~/.bash_aliases, instead of adding them here directly.
# # See /usr/share/doc/bash-doc/examples in the bash-doc package.

# if [ -f ~/.bash_aliases ]; then
#     . ~/.bash_aliases
# fi


# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
    . /etc/bash_completion
fi

######################################################################
# EVERYTHING AFTER THIS ADDED BY ME
######################################################################

# How many cores do we have? Find out from /proc/cpuinfo (using regexp matching
# the start of info for a new processor).
NCORES=`grep --count '^processor[[:space:]]*:' /proc/cpuinfo`

# Colour codes:
# Black       0;30     Dark Gray     1;30
# Blue        0;34     Light Blue    1;34
# Green       0;32     Light Green   1;32
# Cyan        0;36     Light Cyan    1;36
# Red         0;31     Light Red     1;31
# Purple      0;35     Light Purple  1;35
# Brown       0;33     Yellow        1;33
# Light Gray  0;37     White         1;37

# # Tell programs it's an xterm (even if it's not...) so they don't complain.
# export TERM='xterm'
# Aparently this is a (very) bad idea, (arch linux wiki)

# Make sure it's using my readline config
export INPUTRC="$HOME/.inputrc"


# Aliases
# ============================================================

# Use better top with colours and stuff:
alias top='htop'

# Tail -F isn't really tail anymore...c all it rcat(refresh cat)
alias rcat='tail -F -n 100000'

# ls aliases
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Grep
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Fancy grep: with line num, with filename, exclude source control, binaries and make junk
alias mygrep='grep -n -H --color=auto --exclude-dir=.git --exclude-dir=.svn -I --exclude-dir=*.deps --exclude=*.lo --exclude=*.la --exclude=*.lai  --exclude=Makefile --exclude=Makefile.in --exclude=TAGS'

# package manager
alias inst='sudo apt-get install'
alias update='sudo apt-get update && sudo apt-get upgrade --assume-yes --quiet'
alias pm='sudo pacmatic -S'

# Open location in gnome
alias go='nautilus .'

# Git aliases
alias gs='git status'
alias gd='git diff'
alias gdc='git diff --cached'
alias gl1='git log -n1 -p'
alias gc='git cherry-pick'

# svn aliases
alias sst='svn status -q'
alias sd='svn diff'

# Make aliases
alias m='make --keep-going --silent LIBTOOLFLAGS=--silent'

# Matlab in a terminal
alias matlab='matlab -nodesktop -nosplash'

# Maple in a terminal
alias maple="~/code/maple17/bin/maple"

# Move thing to trash
alias trsh='trash-put'

# Simplified find comamnds
function fname() { find . -iname "*$@*"; }
alias findc="find \( -name '*.cc' -o -name '*.h' -o -name '*.cpp' -o -name '*.hpp' \)"

# python
alias pylab='ipython --pylab'
alias nosetests="nosetests --processes="$NCORES

# Get a sorted list of disk usage (take from http://www.commandlinefu.com/commands/view/4786/nice-disk-usage-sorted-by-size-see-description-for-full-command )
sdu()
{
du -sk ./* | sort -nr | awk 'BEGIN{ pref[1]="K"; pref[2]="M"; pref[3]="G";} { total = total + $1; x = $1; y = 1; while( x > 1024 ) { x = (x + 1023)/1024; y++; } printf("%g%s\t%s\n",int(x*10)/10,pref[y],$2); } END { y = 1; while( total > 1024 ) { total = (total + 1023)/1024; y++; } printf("Total: %g%s\n",int(total*10)/10,pref[y]); }'
}

# oomph-lib
OOMPH="$HOME/oomph-lib"
OOMPHMM="$OOMPH/user_drivers/micromagnetics"

alias quickautogen="quickautogen.sh -C $OOMPH"
# alias quickcheck="$HOME/oomph-lib/bin/parallel_self_test.py -C \"$HOME/oomph-lib\""
alias quickcheck="python3 $HOME/oomph-lib/bin/parallel_self_test.py -C $OOMPH"
alias micromagcheck="make -k -s -C $OOMPHMM; make -k -s -C $OOMPHMM install; python3 $HOME/oomph-lib/bin/parallel_self_test.py -C $OOMPHMM"
alias oopt="echo -e \"$OOMPH/config/configure_options/current contains:\n\n\"; cat $OOMPH/config/configure_options/current"

alias mm="make -k -s LIBTOOLFLAGS=--silent -C $OOMPHMM && make -k -s LIBTOOLFLAGS=--silent -C $OOMPHMM install && make -k -s LIBTOOLFLAGS=--silent -C $OOMPHMM/control_scripts/llg_driver"

full_test()
{
    # Arguments are passed to quickautogen and used to label files

    mkdir test_results

    oomphfile="test_results/oomph_tests_$@"
    oomphfile2=$(echo $oomphfile | sed 's/ /_/g')

    mmfile="test_results/mm_tests_$@"
    mmfile2=$(echo $mmfile | sed 's/ /_/g')

    buildfile="test_results/build_trace_$@"
    buildfile2=$(echo $buildfile | sed 's/ /_/g')

    quickautogen $@ 2>&1 | tee $buildfile2 && \
        quickcheck --no-colour | tee $oomphfile2 && \
        micromagcheck | tee $mmfile2
}

# Run all tests with debug, mpi and mpi+opt settings (assuming we are
# starting in a debug build).
alias oomphtestall="cd ~/oomph-lib && touch test_results && mv test_results test_results.old && full_test -d && full_test -am && full_test -an"

# Aliases for using emacs with a daemon, ec just starts a client, emacs starts a new window.
alias ec='emacsclient -n'
alias emacs='emacsclient -c -n'
alias e='emacsclient -c -n'


# Build thesis tex file
alias tb='cd ~/Dropbox/phd/reports/ongoing-writeup/ && ./build.sh'


# cd aliases/changes
# ============================================================
# Quickly cd to useful directorys
alias om='cd $OOMPHMM'

alias hs='cd ~/Dropbox/programming/helperscripts'
alias wr='cd ~/Dropbox/phd/reports/ongoing-writeup'
# alias sr='cd ~/Dropbox/phd/talks/second_year_progression'
# alias rs='cd ~/Dropbox/phd/results'
# alias sicp='cd ~/programming/sicp/exercises4'
alias rc='cd ~/Dropbox/linux_setup/rcfiles'

alias sp='cd ~/programming/simpleode/'
alias spe='cd ~/programming/simpleode/experiments'

# Cd to currently used dirs
function now ()
{
    cd ~/oomph-lib/user_drivers/micromagnetics/control_scripts/semi_implicit_mm_driver
}
function now2 ()
{
    cd ~/oomph-lib-2/user_drivers/micromagnetics/control_scripts/llg_driver
}

# Aliases for cds upwards
alias ....='cd ../../..'
alias ...='cd ../..'
alias ..='cd ../'

# Set cd to correct small spelling mistakes
shopt -s cdspell

# A function to cd then ls
function cs ()
{
    cd $1;
    ls --color=auto;
}


# Emacs
# ============================================================
# For some reason this runs an emacs daemon if emacs is not already running and
# you try to run an emacsclient
export EDITOR="emacsclient -c -n"
export ALTERNATE_EDITOR=""


# General PATH additions
# ============================================================
# Add my scripts to PATH
export PATH="$PATH:$HOME/Dropbox/programming/helperscripts/gnuplot:$HOME/Dropbox/programming/helperscripts/oomph-lib:$HOME/Dropbox/programming/helperscripts:$HOME/Dropbox/programming/helperscripts/python"
PATH="$PATH:$HOME/Dropbox/programming/oomph-scripts"
PATH="$PATH:$HOME/bin"

# Add oomph-lib bin to path
export PATH="$PATH:$HOME/oomph-lib/bin"

# Paraview
export PATH="$PATH:$HOME/code/paraview/bin"

# Matlab
export PATH="$PATH:$HOME/code/matlab/bin:/usr/local/MATLAB/R2013a/bin"


# nsim/nmag stuff
# ============================================================
# Add nsim to PATH
export PATH="$PATH:$HOME/code/nmag-0.2.1/bin"

# # Some other variables
# PATH="/home/david/code/nmag/bin:/home/david/code/nmag/lib/mpich2/bin:$PATH"
# PETSC_DIR="/home/david/code/nmag/lib/petsc"
# LD_LIBRARY_PATH="/home/david/code/nmag/lib:/home/david/code/nmag/lib/petsc/linux-gnu-c-opt/lib:/home/david/code/nmag/lib/mpich2/lib:$LD_LIBRARY_PATH"

# Stupid netgen!!
export NETGENDIR="/usr/share/netgen/"


# oomph-lib aliases
# ============================================================



# Colour in man pages
# ============================================================
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'


# Fancy prompt
# ============================================================

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# Set the prompt (notice the space between use name and location, for
# easy cut+paste). Mostly from Ubuntu defaults..
PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]: \[\033[01;34m\]\w\[\033[00m\]'

# In git line in prompt: show symbols for non-clean state
GIT_PS1_SHOWDIRTYSTATE=1

gitbranch()
{
    if type __git_ps1 &> /dev/null
    then
        __git_ps1
    else
        echo
    fi
}


# Append git branch followed by newline and $ to prompt. Note that we HAVE to
# use single quotes for the __git_ps1 part. Stuff in \[ \] is colour commands.
PS1="$PS1"'\[\033[1;36m\]$(gitbranch " (%s)")\[\033[0m\] \$\n '


# Changes to defaults for "make"
# ============================================================

# Apparently make runs fastest with one more job than there are cores.
NJOBS=$(($NCORES + 1))
export MAKEFLAGS="-j$NJOBS"


# Python
# ============================================================
# Add my scripts to python path
export PYTHONPATH="$HOME/programming/"

alias opython="ipython scipy"


# magnum.fe
# ============================================================
if [ -d $HOME/code/dorsal_code ]; then
    # Add FEniCS environment variables
    source $HOME/code/dorsal_code/FEniCS/share/fenics/fenics.conf
    export PYTHONPATH=$PYTHONPATH:$HOME/code/magnum.fe/site-packages
fi
