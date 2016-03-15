" =============================================================================
" File:          autoload/babel.vim
" Author:        Javier Blanco <http://jbgutierrez.info>
" =============================================================================

" Switch to the window for buf.
function! s:switch_window(buf)
  exec bufwinnr(a:buf) 'wincmd w'
endfunction

" Create a new scratch buffer and return the bufnr of it. After the function
" returns, vim remains in the scratch buffer so more set up can be done.
function! s:buffer_open(src, vert, size)
  let size = a:size
  if a:size <= 0
    if a:vert
      let size = winwidth(bufwinnr(a:src)) / 2
    else
      let size = winheight(bufwinnr(a:src)) / 2
    endif
  endif

  if a:vert
    vertical belowright new
    exec 'vertical resize' size
  else
    belowright new
    exec 'resize' size
  endif

  setlocal bufhidden=wipe buftype=nofile nobuflisted noswapfile nomodifiable
  nnoremap <buffer> <silent> q :hide<CR>

  return bufnr('%')
endfunction

" Replace buffer contents with text and delete the last empty line.
function! s:update(buf, text)
  " Move to the scratch buffer.
  call s:switch_window(a:buf)

  " Double check we're in the scratch buffer before overwriting.
  if bufnr('%') != a:buf
    throw 'unable to change to scratch buffer'
  endif

  setlocal modifiable
    silent exec '% delete _'
    silent put! =a:text
    silent exec '$ delete _'
  setlocal nomodifiable
endfunction

" Parse the output of babel into a qflist entry for src buffer.
function! s:parse_error(output, src, startline)
  " Babel error is always on first line?
  let match = matchlist(a:output,
  \                     '\v^SyntaxError: (\f+): (.{-}) \((\d+):(\d+)\)' . "\n")

  if !len(match)
    return
  endif

  " Consider the line number from babel as relative and add it to the beginning
  " line number of the range the command was called on, then subtract one for
  " zero-based relativity.
  call setqflist([{'bufnr': a:src, 'lnum': a:startline + str2nr(match[3]) - 1,
  \                'type': 'E', 'col': str2nr(match[4]), 'text': match[2]}], 'r')
endfunction

" Clean things up in the source buffers.
function! s:close()
  " Switch to the source buffer if not already in it.
  silent! call s:switch_window(b:babel_src_buf)
  unlet! b:babel_compile_buf
endfunction

" compile the lines between startline and endline and put the result into buf.
function! s:compile(buf, startline, endline)
  let src = bufnr('%')
  let input = join(getline(a:startline, a:endline), "\n")

  " Pipe lines into babel.
  let cmd = b:node_path . ' babel ' . b:babel_options . ' <(cat) 2>&1'
  let output = system(cmd, input)

  " Paste output into output buffer.
  call s:update(a:buf, output)

  " Highlight as JavaScript if there were no compile errors.
  if v:shell_error
    call s:parse_error(output, src, a:startline)
    setlocal filetype=
  else
    " Clear the quickfix list.
    call setqflist([], 'r')
    setlocal filetype=javascript
  endif
endfunction

" Peek at compiled script in a scratch buffer. We handle ranges like this
" to prevent the cursor from being moved (and its position saved) before the
" function is called.
function! babel#Babel(startline, endline, args)

  if globpath(&rtp, 'autoload/webapi/http.vim') ==# ''
    echohl ErrorMsg | echomsg 'Babel requires ''webapi'', please install https://github.com/mattn/webapi-vim' | echohl None
    return
  endif

  " Switch to the source buffer if not already in it.
  silent! call s:switch_window(b:babel_src_buf)

  " Build the output buffer if it doesn't exist.
  if !exists('b:babel_compile_buf')
    let src = bufnr('%')

    let vert = exists('g:babel_compile_vert') || a:args =~ '\<vert\%[ical]\>'
    let size = str2nr(matchstr(a:args, '\<\d\+\>'))

    " Build the output buffer and save the source bufnr.
    let buf = s:buffer_open(src, vert, size)
    let b:babel_src_buf = src

    " Set the buffer name.
    exec 'silent! file [Babel ' . src . ']'

    " Clean up the source buffer when the output buffer is closed.
    autocmd BufWipeout <buffer> call s:close()
    " Save the cursor when leaving the output buffer.
    autocmd BufLeave <buffer> let b:babel_compile_pos = getpos('.')

    " Switch back to the source buffer and save the output bufnr. This also
    " triggers BufLeave above.
    call s:switch_window(src)
    let b:babel_compile_buf = buf

    " Look for a file named .babelrc in the directory of the opened buffer
    " and in every parent directory
    let b:node_path  = ''
    let b:babel_options = ''
    let base_babelrc = expand('%:p:h')
    while base_babelrc != '/'
      let babelrc = base_babelrc . '/.babelrc'
      if filereadable(babelrc)
        let b:node_path = 'NODE_PATH=$NODE_PATH:' . fnameescape(base_babelrc) . '/node_modules'
        let json = join(readfile(babelrc), "\n")
        let options = webapi#json#decode(json)
        let b:options = options
        if exists('options.presets')
          let b:babel_options = b:babel_options . ' --presets ' . join(options.presets, ",")
        endif
        if exists('options.plugins')
          let b:babel_options = b:babel_options . ' --plugins ' . join(options.plugins, ",")
        endif
        break
      else
        let base_babelrc = fnamemodify(babelrc, ':p:h:h')
      endif
    endwhile
  endif

  " Fill the scratch buffer.
  call s:compile(b:babel_compile_buf, a:startline, a:endline)
  " Reset cursor to previous position.
  call setpos('.', b:babel_compile_pos)
endfunction

function! babel#BabelArgs(A,L,P)
  return [ "vertical" ]
endfunction

" vim:fen:fdm=marker:fmr=function,endfunction:fdl=0:fdc=1:ts=2:sw=2:sts=2
