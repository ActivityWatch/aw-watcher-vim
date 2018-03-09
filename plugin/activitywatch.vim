if exists("g:loaded_activitywatch")
        finish
endif

let g:loaded_activitywatch = 1

let s:cpo_save = &cpo
set cpo&vim

let s:vimwatcher_open = 0

function! s:Poke()
        let s:number_of_moves += 1
        if (localtime() - s:vimwatcher_last) >= s:vimwatcher_conf['min_delay'] && s:vimwatcher_open
                call s:SendData()
                let s:vimwatcher_last = localtime()
                let s:number_of_moves = 0
        endif
endfunc

function! s:StartVimWatcher()
        let s:vimwatcher_job = job_start("python3 -u" . expand("<sfile>:p:h") . "vimwatcher.py",
                                \ {"out_cb": "AWRecv",
                                \ "in_mode": "json"
                                \})
        let s:vimwatcher_last = 0
        let s:number_of_moves = 0
        let s:vimwatcher_open = 1
        let s:vimwatcher_conf = {'min_delay': 1000}
        call s:Send("config")
endfunc

function! s:StopVimWatcher()
        call ch_sendexpr(s:vimwatcher_job, "stop")
        let s:vimwatcher_open = 0
endfunc

function! AWRecv(channel, msg)
        let l:json_msg = json_decode(a:msg)
        if json_msg[0] == "config"
                let s:vimwatcher_conf = json_msg[1]
        else
                echo json_msg
        endif
endfunc

function! AWEcho(channel, msg)
        echo a:msg
endfunc

function! s:Send(msg)
        if s:vimwatcher_open
                if ch_status(s:vimwatcher_job) == "open"
                        call ch_sendexpr(s:vimwatcher_job, a:msg)
                else
                        let s:vimwatcher_open = 0
                        echo "Watcher has stopped unexpectedly"
                endif
        else
                echo "Watcher not running"
        endif
endfunc

function! s:SendData()
        call s:Send({'timestamp': localtime(),
                                \ 'fname': expand('%:p')
                                \})
endfunc

call s:StartVimWatcher()

augroup ActivityWatch
        autocmd CursorMoved,CursorMovedI * call s:Poke()
augroup END

command! AWStart call s:StartVimWatcher()
command! AWStatus echom ch_status(s:vimwatcher_job)
command! AWStop  call s:StopVimWatcher()
command! AWConf  call s:Send("config")

let &cpo = s:cpo_save
unlet s:cpo_save
