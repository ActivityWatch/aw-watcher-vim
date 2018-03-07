if !has('python')
        finish
endif

function! AWStartVimWatcher()
        let g:aw_vimwatcher_job = job_start("python3 -u vimwatcher.py", {"out_cb": "AWRecv", "in_mode": "json"})
        let g:aw_vimwatcher_timer = timer_start(5000, 'AWSendData', {'repeat': -1})
endfunc

function! AWStopVimWatcher()
        call timer_stop(g:aw_vimwatcher_timer)
        call ch_sendexpr(g:aw_vimwatcher_job, "stop")
endfunc

function! AWRecv(channel, msg)
        echo a:msg
endfunc

function! AWSend(msg)
        call ch_sendexpr(g:aw_vimwatcher_job, a:msg)
endfunc

function! AWSendData(timer)
        call AWSend({"fname": expand('%:p')})
endfunc
        


command! AWStart call AWStartVimWatcher()
command! AWStatus echom ch_status(g:aw_vimwatcher_job)
command! AWStop  call AWStopVimWatcher()
