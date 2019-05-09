if exists("g:loaded_activitywatch")
        finish
endif
let g:loaded_activitywatch = 1

" compatibility mode which set this script to run with default vim settings
let s:save_cpo = &cpo
set cpo&vim

let s:last_heartbeat = localtime()
let s:file = ''
let s:language = ''
let s:project = ''

let s:connected = 0
let s:base_apiurl = '127.0.0.1:5600/api/0'
let s:hostname = hostname()
let s:bucketname = printf('aw-watcher-vim_%s', s:hostname)
let s:bucket_apiurl = printf('%s/buckets/%s', s:base_apiurl, s:bucketname)
let s:heartbeat_apiurl = printf('%s/heartbeat?pulsetime=10', s:bucket_apiurl)

" dict of all responses
" the key is the jobid and the value the HTTP status code
let s:http_response_code = {}

function! s:HTTPPostJson(url, data)
    let l:req = ['curl', '-s', a:url,
        \ '-H', 'Content-Type: application/json',
        \ '-X', 'POST',
        \ '-d', json_encode(a:data),
        \ '-o', '/dev/null',
        \ '-w', "%{stderr}%{http_code}"]
    let l:req_job = jobstart(l:req,
        \ {"on_stdout": "s:HTTPPostOnStdout",
        \  "on_stderr": "s:HTTPPostOnStderr",
        \  "on_exit": "s:HTTPPostOnExit",
    \ })
    call jobwait([l:req_job])
endfunc

function! s:HTTPPostOnExit(jobid, exitcode, eventtype)
    let l:jobid_str = printf('%d', a:jobid)
    let l:status_code = str2nr(s:http_response_code[l:jobid_str][0])
    if l:status_code == 0
        " We cannot connect to aw-server
        echoerr "aw-watcher-vim: Failed to send requests to aw-server, logging will be disabled. You can retry to connect with ':AWStart'"
        let s:connected = 0
    elseif l:status_code >= 100 && l:status_code < 300 || l:status_code == 304
        " We are connected!
        let s:connected = 1
    else
        " aw-server didn't like our request
        echoerr printf("aw-watcher-vim: aw-server did not accept our request with status code %d. See aw-server logs for reason or stop aw-watcher-vim with :AWStop", l:status_code)
    endif
    " Cleanup response code
    unlet s:http_response_code[l:jobid_str]
endfunc

function! s:HTTPPostOnStdout(jobid, data, event)
    "let l:jobid_str = printf('%d', a:jobid)
    "echo printf('aw-watcher-vim job %d stdout: %s', a:jobid, json_encode(a:data))
endfunc

function! s:HTTPPostOnStderr(jobid, data, event)
    if a:data != ['']
        let l:jobid_str = printf('%d', a:jobid)
        let s:http_response_code[l:jobid_str] = a:data
        "echo printf('aw-watcher-vim job %d stderr: %s', a:jobid, a:data)
    endif
endfunc

function! s:CreateBucket()
    let l:body = {
        \ 'name': s:bucketname,
        \ 'hostname': hostname(),
        \ 'client': 'aw-watcher-vim',
        \ 'type': 'app.editor'
    \}
    call s:HTTPPostJson(s:bucket_apiurl, l:body)
endfunc

function! s:Heartbeat()
    " Only send heartbeats if we can connect to aw-server
    if s:connected < 1
        return
    endif
    let l:duration = 0
    let l:localtime = localtime()
    let l:timestamp = strftime('%FT%H:%M:%S%z')
    let l:file = expand('%p')
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
        call s:HTTPPostJson(s:heartbeat_apiurl, l:req_body)
        let s:file = l:file
        let s:language = l:language
        let s:project = l:project
        let s:last_heartbeat = l:localtime
    endif
endfunc

function! AWStart()
    call s:CreateBucket()
endfunc

function! AWStop()
    let s:connected = 0
endfunc

augroup ActivityWatch
    autocmd VimEnter * call AWStart()
    autocmd BufEnter,CursorMoved,CursorMovedI * call s:Heartbeat()
augroup END

command! AWHeartbeat call s:Heartbeat()
command! AWStart call AWStart()
command! AWStop call AWStop()
command! AWStatus echom printf('aw-watcher-vim running: %b', s:connected)

" reset compatibility mode
let &cpo = s:save_cpo
