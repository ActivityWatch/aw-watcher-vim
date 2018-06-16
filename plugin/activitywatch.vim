if exists("g:loaded_activitywatch")
        finish
endif

let g:loaded_activitywatch = 1

let s:cpo_save = &cpo
set cpo&vim

let s:adapter_cmd = ['python3', expand("<sfile>:p:h") . '/vimwatcher.py']

function! s:StartVimWatcher()
        if !exists("s:vimwatcher_job") || !s:CheckStatus()
                if has('nvim')
                        let s:vimwatcher_job = jobstart(s:adapter_cmd,
                                    \ {"on_stdout": "AWNeovimEcho",
                                    \  "on_stderr": "AWNeovimEcho",
                                    \ })
                else
                        let s:vimwatcher_job = job_start(s:adapter_cmd,
                                    \ {"out_cb": "AWEcho",
                                    \  "err_cb": "AWEcho",
                                    \  "in_mode": "raw"
                                    \ })
                endif
        endif
endfunc

function! AWNeovimEcho(job_id, data, event)
        echo a:data
endfunc
function! AWEcho(channel, msg)
        echo a:msg
endfunc

function! s:CheckStatus()
        if has('nvim')
                if s:vimwatcher_job
                        return 1
                endif
        elseif ch_status(s:vimwatcher_job) == "open"
                return 1
        endif
        return 0
endfunc

function! s:StopVimWatcher()
        if has('nvim')
                call jobstop(s:vimwatcher_job)
                let s:vimwatcher_job = 0
        else
                call job_stop(s:vimwatcher_job)
        endif
endfunc

function! s:Send(msg)
        if s:CheckStatus()
                let l:json_msg = json_encode(a:msg)
                if has('nvim')
                        call jobsend(s:vimwatcher_job, l:json_msg . "\n")
                else
                        call ch_sendraw(s:vimwatcher_job, l:json_msg . "\n")
                endif
        endif
endfunc

function! s:Poke()
        call s:Send({'action': 'update', 'data': {'filename': expand('%:p')}})
endfunc

call s:StartVimWatcher()

augroup ActivityWatch
        autocmd BufEnter * call s:StartVimWatcher()
        autocmd CursorMoved,CursorMovedI * call s:Poke()
augroup END

command! AWStart call s:StartVimWatcher()
command! AWStatus echom s:CheckStatus()
command! AWStop  call s:StopVimWatcher()

let &cpo = s:cpo_save
unlet s:cpo_save
