" vimspector - A multi-language debugging system for Vim
" Copyright 2018 Ben Jackson
"
" Licensed under the Apache License, Version 2.0 (the "License");
" you may not use this file except in compliance with the License.
" You may obtain a copy of the License at
"
"   http://www.apache.org/licenses/LICENSE-2.0
"
" Unless required by applicable law or agreed to in writing, software
" distributed under the License is distributed on an "AS IS" BASIS,
" WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
" See the License for the specific language governing permissions and
" limitations under the License.


" Boilerplate {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

function! s:_OnServerData( channel, data ) abort
  py3 << EOF
_vimspector_session.OnChannelData( vim.eval( 'a:data' ) )
EOF
endfunction

function! s:_OnServerError( channel, data ) abort
  echom "Channel received error: " . a:data
endfunction

function! s:_OnExit( channel, status ) abort
  echom "Channel exit with status " . a:status
endfunction

function! s:_OnClose( channel ) abort
  echom "Channel closed"
  " py3 _vimspector_session.OnChannelClosed()
endfunction

function! s:_Send( msg ) abort
  if job_status( s:job ) != 'run'
    echom "Server isnt running"
    return
  endif

  let ch = job_getchannel( s:job )
  if ch == 'channel fail'
    echom "Channel was closed unexpectedly!"
    return
  endif

  call ch_sendraw( ch, a:msg )
endfunction

function! vimspector#internal#job#StartDebugSession( config ) abort
  if exists( 's:job' )
    echo "Job is already running"
    return v:none
  endif

  let s:job = job_start( a:config[ 'command' ],
        \                {
        \                    'in_mode': 'raw',
        \                    'out_mode': 'raw',
        \                    'err_mode': 'raw',
        \                    'exit_cb': funcref( 's:_OnExit' ),
        \                    'close_cb': funcref( 's:_OnClose' ),
        \                    'out_cb': funcref( 's:_OnServerData' ),
        \                    'err_cb': funcref( 's:_OnServerError' ),
        \                    'stoponexit': 'term',
        \                }
        \              )

  if job_status( s:job ) != 'run'
    echom 'Fail whale. Job is ' . job_status( s:job )
    return v:none
  endif

  return funcref( 's:_Send' )
endfunction

function! vimspector#internal#job#StopDebugSession() abort
  if job_status( s:job ) == 'run'
    call job_stop( s:job, 'term' )
  endif

  unlet s:job
endfunction

function! vimspector#internal#job#Reset() abort
  if exists( 's:job' )
    call vimspector#internal#job#StopDebugSession()
  endif
endfunction

function! vimspector#internal#job#ForceRead() abort
  if exists( 's:job' )
    let data = ch_readraw( job_getchannel( s:job ), { 'timeout': 1000 } )
    if data != ''
      call s:_OnServerData( job_getchannel( s:job ), data )
    endif
  endif
endfunction

" Boilerplate {{{
let &cpo=s:save_cpo
unlet s:save_cpo
" }}}
