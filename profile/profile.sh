#!/bin/bash
tmux new-session -d -c "$PWD" -s vimprofile 'vim -u ./profile.vim' \; \
        send-key -t vimprofile 'i'

for i in `seq 1 600`; do
        sleep 0.01
        tmux send-key -t vimprofile 'a'
done
tmux send-key -t vimprofile 'Escape' ':q!' 'Enter'
