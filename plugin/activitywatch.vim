if exists("g:loaded_activitywatch")
        finish
endif

let g:loaded_activitywatch = 1

let s:cpo_save = &cpo
set cpo&vim

let s:vimwatcher_open = 0
let s:adapter_cmd = ['python3', '-u', expand("<sfile>:p:h") . '/vimwatcher.py']

function! s:Poke()
        let s:number_of_moves += 1
        if (localtime() - s:vimwatcher_last) >= s:vimwatcher_conf['min_delay'] && s:vimwatcher_open
                call s:SendData()
                let s:vimwatcher_last = localtime()
                let s:number_of_moves = 0
        endif
endfunc

function! s:StartVimWatcher()
        if !exists("s:vimwatcher_job") || !s:CheckStatus()
                if has('nvim')
                        let s:vimwatcher_job = jobstart(s:adapter_cmd,
                                                \ {"on_stdout": "AWNeovimRecv",
                                                \ "on_stderr": "AWNeovimEcho",
                                                \ "on_exit": "AWNeovimExit"
                                                \})
                else
                        let s:vimwatcher_job = job_start(s:adapter_cmd,
                                                \ {"out_cb": "AWRecv",
                                                \ "err_io": "buffer",
                                                \ "err_name": "activtywatch_log",
                                                \ "in_mode": "json"
                                                \})
                endif

                let s:vimwatcher_last = 0
                let s:number_of_moves = 0
                let s:vimwatcher_open = 1
                let s:vimwatcher_conf = {'min_delay': 1000}
                call s:Send("config")
        endif
endfunc

function! AWNeovimExit(job_id, data, event)
        call s:CloseWatcher()
endfunc

function! AWNeovimRecv(job_id, data, event)
        call s:HandleMsg(a:data)
endfunc

function! AWNeovimEcho(job_id, data, event)
        echo a:data
endfunc

function! AWRecv(channel, msg)
        call s:HandleMsg(a:msg)
endfunc

function! s:HandleMsg(msg)
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

function! s:CheckStatus()
        if s:vimwatcher_open
                if has('nvim')
                        return 1
                elseif ch_status(s:vimwatcher_job) == "open"
                        return 1
                else
                        call s:CloseWatcher()
                        echo "Watcher has stopped unexpectedly"
                endif
        endif
        return 0
endfunc

function! s:StopVimWatcher()
        call s:Send("stop")
        call s:CloseWatcher()
endfunc

function! s:CloseWatcher()
        let s:vimwatcher_open = 0
endfunc

function! s:Send(msg)
        if s:CheckStatus()
                if has('nvim')
                        let l:json_msg = json_encode(a:msg)
                        call jobsend(s:vimwatcher_job, l:json_msg)
                else
                        call ch_sendexpr(s:vimwatcher_job, a:msg)
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
        autocmd BufEnter * call s:StartVimWatcher()
        autocmd CursorMoved,CursorMovedI * call s:Poke()
augroup END

command! AWStart call s:StartVimWatcher()
if has('nvim')
        command! AWStatus echom s:CheckStatus()
else
        command! AWStatus echom ch_status(s:vimwatcher_job)
endif
command! AWStop  call s:StopVimWatcher()
command! AWConf  call s:Send("config")

let &cpo = s:cpo_save
unlet s:cpo_save
