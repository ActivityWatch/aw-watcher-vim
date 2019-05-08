
let s:last_heartbeat = localtime()
let s:file = ''
let s:language = ''
let s:project = ''

function! s:Poke()
    let l:duration = 0
    let l:localtime = localtime()
    let l:timestamp = strftime('%FT%H:%M:%S%z')
    let l:file = expand('%p')
    let l:language = &filetype
    let l:project = getcwd()
    if    s:file != l:file ||
        \ s:language != l:language ||
        \ s:project != l:project ||
        \ l:localtime - s:last_heartbeat > 1

        let l:curl_cmd = ['curl', '-s',
            \ '127.0.0.1:5666/api/0/buckets/aw-watcher-web-firefox/heartbeat?pulsetime=10',
            \ '-H', 'Content-Type: application/json',
            \ '-X', 'POST']
        let l:req_body = {
            \ 'duration': 0,
            \ 'timestamp': l:timestamp,
            \ 'data': {
                \ 'file': l:file,
                \ 'language': l:language,
                \ 'project': l:project
            \ }
        \}
        let l:req = l:curl_cmd
        call add(l:req, "-d")
        call add(l:req, json_encode(l:req_body))
        "echom json_encode(l:req)
        call jobstart(l:req,
    \ {"on_stdout": "AWNeovimEcho",
    \  "on_stderr": "AWNeovimEcho",
    \ })
        let s:file = l:file
        let s:language = l:language
        let s:project = l:project
        let s:last_heartbeat = l:localtime
    endif
endfunc

function! AWNeovimEcho(job_id, data, event)
    if a:data != ['']
        echo a:data
    endif
endfunc

function! AWEcho(channel, msg)
        echo a:msg
endfunc

augroup ActivityWatch
        autocmd CursorMoved,CursorMovedI * call s:Poke()
augroup END

command! AWPoke call s:Poke()

