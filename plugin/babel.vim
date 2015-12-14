" =============================================================================
" File:          plugin/babel.vim
" Author:        Javier Blanco <http://jbgutierrez.info>
" =============================================================================

if ( exists('g:loaded_babel') && g:loaded_babel ) || &cp
  finish
endif

let g:loaded_babel = 1

command! -range=% -bar -nargs=* -complete=customlist,babel#BabelArgs Babel call babel#Babel(<line1>, <line2>, <q-args>)

" vim:fen:fdm=marker:fmr=function,endfunction:fdl=0:fdc=1:ts=2:sw=2:sts=2
