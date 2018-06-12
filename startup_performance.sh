#!/bin/bash

E=/bin/vim
#E=/bin/nvim

$E -u /dev/null -c "profile start startup.profile" -c "profile file ./plugin/activitywatch.vim" -c "source ./plugin/activitywatch.vim" -c "AWStatus" -c "AWStop" -c "exit"
