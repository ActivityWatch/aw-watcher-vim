if exists("g:loaded_activitywatch")
        finish
endif
let g:loaded_activitywatch = 1

" compatibility mode which set this script to run with default vim settings
let s:save_cpo = &cpo
set cpo&vim

let s:nvim = has('nvim')

let s:last_heartbeat = localtime()
let s:file = ''
let s:language = ''
let s:project = ''

let s:connected = 0
" Bumped by :AWStop and on every bucket create, so replies to requests sent
" earlier cannot change the connection state.
let s:session = 0
" Set once a heartbeat 404 made us re-create the bucket, cleared when a
" heartbeat succeeds again, so a persistent 404 cannot loop.
let s:bucket_recreated = 0
let s:apiurl_host = get(g:, 'aw_apiurl_host', '127.0.0.1')
let s:apiurl_port = get(g:, 'aw_apiurl_port', '5600')
let s:api_timeout = get(g:, 'aw_api_timeout', 2)
if type(s:api_timeout) == type(0.0)
    " Job argv items must be strings or numbers; a Float raises E806.
    let s:api_timeout = string(s:api_timeout)
endif
let s:base_apiurl = printf('http://%s:%s/api/0', s:apiurl_host, s:apiurl_port)
let s:hostname = get(g:, 'aw_hostname', hostname())
let s:bucketname = printf('aw-watcher-vim_%s', s:hostname)
let s:bucket_apiurl = printf('%s/buckets/%s', s:base_apiurl, s:bucketname)
let s:heartbeat_apiurl = printf('%s/heartbeat?pulsetime=30', s:bucket_apiurl)

" Pending requests keyed by job/channel id.
let s:http_requests = {}

function! HTTPPostJson(url, data)
    let l:req = ['curl', '-sS', a:url,
        \ '-H', 'Content-Type: application/json',
        \ '-X', 'POST',
        \ '-d', json_encode(a:data),
        \ '-o', '/dev/null',
        \ '-m', s:api_timeout,
        \ '-w', "%{http_code}"]
    if s:nvim
        let l:req_job = jobstart(l:req,
            \ {"detach": 1,
            \  "on_stdout": "HTTPPostOnStdoutNeovim",
            \  "on_stderr": "HTTPPostOnStderrNeovim",
            \  "on_exit": "HTTPPostOnExitNeovim",
        \ })
        let l:jobid_str = printf('%d', l:req_job)
    else
        let l:req_job = job_start(l:req,
            \ {"out_cb": "HTTPPostOnStdoutVim",
            \  "err_cb": "HTTPPostOnStderrVim",
            \  "close_cb": "HTTPPostOnExitVim",
            \  "in_mode": "raw",
        \ })
        let l:jobid_str = printf('%d', ch_info(job_getchannel(l:req_job)).id)
    endif
    let s:http_requests[l:jobid_str] = {'url': a:url, 'status': '', 'error': '', 'session': s:session}
endfunc

function! HTTPPostOnExitNeovim(jobid, exitcode, eventtype)
    let l:jobid_str = printf('%d', a:jobid)
    let l:status_code = str2nr(s:http_requests[l:jobid_str].status)
    call HTTPPostOnExit(l:jobid_str, l:status_code)
endfunc

function! HTTPPostOnExitVim(jobmsg)
    " cut out channelnum from string 'channel X running'
    let l:jobid_str = substitute(a:jobmsg, '[ A-Za-z]*', '', "g")
    let l:status_code = str2nr(s:http_requests[l:jobid_str].status)
    call HTTPPostOnExit(l:jobid_str, l:status_code)
endfunc

function! HTTPPostOnExit(jobid_str, status_code)
    let l:request = remove(s:http_requests, a:jobid_str)
    if l:request.session != s:session
        " Sent before :AWStop or a bucket (re-)create; it must not undo them
        return
    endif
    let l:heartbeat = l:request.url ==# s:heartbeat_apiurl
    if a:status_code == 0
        " We cannot connect to aw-server
        let s:connected = 0
        echoerr printf("aw-watcher-vim: Failed to connect to aw-server at %s. %s Logging will be disabled. You can retry with ':AWStart'", l:request.url, trim(l:request.error))
    elseif a:status_code >= 100 && a:status_code < 300 || a:status_code == 304
        " We are connected!
        let s:connected = 1
        if l:heartbeat
            let s:bucket_recreated = 0
        endif
    elseif a:status_code == 404 && l:heartbeat && !s:bucket_recreated
        " The bucket is gone (deleted in the web UI, or aw-server restarted
        " onto a fresh database): re-create it once, pausing heartbeats until
        " the create succeeds.
        let s:connected = 0
        let s:bucket_recreated = 1
        call s:CreateBucket()
    else
        " aw-server didn't like our request
        let s:connected = 0
        echoerr printf("aw-watcher-vim: aw-server did not accept our request with status code %d. Logging will be disabled. See aw-server logs for the reason. You can retry with ':AWStart'", a:status_code)
    endif
endfunc

function! HTTPPostOnStdoutVim(jobmsg, data)
    " cut out channelnum from string 'channel X running'
    let l:jobid_str = substitute(a:jobmsg, '[ A-Za-z]*', '', "g")
    let s:http_requests[l:jobid_str].status .= a:data
    "echo printf('aw-watcher-vim job %d stdout: %s', l:jobid_str, json_encode(a:data))
endfunc

function! HTTPPostOnStdoutNeovim(jobid, data, event)
    if a:data != ['']
        let l:jobid_str = printf('%d', a:jobid)
        let s:http_requests[l:jobid_str].status .= join(a:data, "\n")
        "echo printf('aw-watcher-vim job %d stdout: %s', a:jobid, json_encode(a:data))
    endif
endfunc

function! HTTPPostOnStderrVim(jobmsg, data)
    let l:jobid_str = substitute(a:jobmsg, '[ A-Za-z]*', '', "g")
    let s:http_requests[l:jobid_str].error .= a:data . "\n"
endfunc

function! HTTPPostOnStderrNeovim(jobid, data, event)
    let l:jobid_str = printf('%d', a:jobid)
    let s:http_requests[l:jobid_str].error .= join(a:data, "\n")
endfunc

function! s:CreateBucket()
    let s:session += 1
    let l:body = {
        \ 'name': s:bucketname,
        \ 'hostname': s:hostname,
        \ 'client': 'aw-watcher-vim',
        \ 'type': 'app.editor.activity'
    \}
    call HTTPPostJson(s:bucket_apiurl, l:body)
endfunc

function! s:Heartbeat()
    " Only send heartbeats if we can connect to aw-server
    if s:connected < 1
        return
    endif
    let l:duration = 0
    let l:localtime = localtime()
    let l:timestamp = strftime('%FT%H:%M:%S%z')
    let l:file = expand('%:p')
    let l:language = &filetype
    let l:project = getcwd()
    " Only send heartbeat if data was changed or more than 1 second has passed
    " since last heartbeat
    if    s:file != l:file ||
        \ s:language != l:language ||
        \ s:project != l:project ||
        \ l:localtime - s:last_heartbeat > 1

        let l:req_body = {
            \ 'duration': 0,
            \ 'timestamp': l:timestamp,
            \ 'data': {
                \ 'file': l:file,
                \ 'language': l:language,
                \ 'project': l:project
            \ }
        \}
        call HTTPPostJson(s:heartbeat_apiurl, l:req_body)
        let s:file = l:file
        let s:language = l:language
        let s:project = l:project
        let s:last_heartbeat = l:localtime
    endif
endfunc

function! AWStart()
    let s:bucket_recreated = 0
    call s:CreateBucket()
endfunc

function! AWStop()
    let s:session += 1
    let s:connected = 0
endfunc

augroup ActivityWatch
    autocmd VimEnter * call AWStart()
    autocmd BufEnter,CursorMoved,CursorMovedI * call s:Heartbeat()
    autocmd CmdlineEnter,CmdlineChanged * call s:Heartbeat()
augroup END

command! AWHeartbeat call s:Heartbeat()
command! AWStart call AWStart()
command! AWStop call AWStop()
command! AWStatus echom printf('aw-watcher-vim running: %b', s:connected)

" reset compatibility mode
let &cpo = s:save_cpo
