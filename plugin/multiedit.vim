" *multiedit.txt* Multi-editing for Vim   
" 
" Version: 0.1.1
" Author: Felix Riedel <felix.riedel at gmail.com> 
" Maintainer: Henrik Lissner <henrik at lissner.net>
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
" 
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}


if exists('g:loadedMultiedit') || &cp
    finish
endif
let g:loadedMultiedit = 1

if !exists('g:multieditNoMappings')
    let g:multieditNoMappings = 0
endif

if !exists('g:multieditAutoReset')
    let g:multieditAutoReset = 1
endif

if !exists('g:multieditAutoUpdate')
    let g:multieditAutoUpdate = 1
endif


hi default MultiSelections gui=reverse term=reverse cterm=reverse

function! s:highlight(line, start, end)
    execute "syn match MultiSelections '\\%".a:line."l\\%".a:start."c\\_.*\\%".a:line."l\\%".a:end."c' containedin=ALL"
endfunction

function! s:EntrySort(a,b)
    return a:a.col == a:b.col ? 0 : a:a.col > a:b.col ? 1 : -1
endfunction


function! s:addSelection()
    " restore selection
    normal! gv

    " get selection parameters
    let lnum = line('.')
    let startcol = col('v')
    let endcol = col('.')+1
    let line_end = col('$')

    " add selection to list
    let sel = { 'line': lnum, 'col': startcol, 'end': endcol, 'len': endcol-startcol, 'suffix_length': line_end-endcol }

    if !exists('b:selections')
        let b:selections = {}
        let b:first_selection = sel
    endif

    if has_key(b:selections, lnum)
        let b:selections[lnum] = b:selections[lnum] + [sel]
    else
        let b:selections[lnum] = [sel]
    endif

    call s:highlight(lnum, startcol, endcol)

    "exit visual mode
    normal! v 
endfunction


function! s:startEdit(posMode)
    if !exists('b:selections')
        return
    endif
    let colno = b:first_selection.col

    " posMode == 0 => place cursor at the start of selection (insert)
    " posMode == 1 => place after the selection (append)
    " posMode == 2 => change
    if a:posMode == 1
        let colno = b:first_selection.col + b:first_selection.len
    endif

    call cursor(b:first_selection.line, colno)
    if a:posMode == 2
        normal! v
        call cursor(b:first_selection.line, (b:first_selection.col + b:first_selection.len)-1)
        normal! c
        call s:updateSelections()
    endif

    augroup multiedit 
        au!
        if g:multiedit_autoupdate == 1
            au CursorMovedI * call s:updateSelections()
        else
            au InsertLeave * call s:updateSelections()
        endif
        " au InsertEnter * call s:updateSelections(1)
        if g:multiedit_autoreset == 1
            au InsertLeave * call s:reset()
        endif
        au InsertLeave * autocmd! multiedit
    augroup END
endfunction


function! s:reset()
    if exists('b:selections')
        unlet b:selections
    endif
    if exists('b:first_selection')
        unlet b:first_selection
    endif
    syn clear MultiSelections
    au! multiedit 
endfunction


function! s:updateSelections()
    " Save cursor position
    let b:save_cursor = getpos('.')

    if !exists('b:selections')
        return
    endif

    syn clear MultiSelections

    let editline = getline(b:first_selection.line)
    let line_length = len(editline)
    let newtext = editline[(b:first_selection.col-1): (line_length-b:first_selection.suffix_length-1)]

    for line in sort(keys(b:selections))
        let entries = b:selections[line]
        let entries = sort(entries, "s:EntrySort")
        let s:offset = 0

        for entry in entries
            " skip the entry of the first selection
            if entry.line != b:first_selection.line || entry.col != b:first_selection.col 
                " selection is moved by offset if this is not
                " the first selection in the line
                let entry.col = entry.col + s:offset
                let oldline = getline(entry.line)
                let prefix = ''
                if entry.col > 1
                    let prefix = oldline[0:entry.col-2]
                endif
                let suffix = oldline[(entry.col+entry.len-1):]
        
                " update the line
                call setline(entry.line, prefix.newtext.suffix) 
            endif
            
            " update the offset for the next selection in this line
            let s:offset = s:offset + len(newtext) - entry.len 

            " update the length of the selection to fit the new content
            let entry.len = len(newtext)

            call s:highlight(entry.line, entry.col, entry.col+entry.len)
        endfor
    endfor

    let b:first_selection.suffix_length = col([b:first_selection.line, '$']) - b:first_selection.col - b:first_selection.len

    " restore cursor position
    call setpos('.', b:save_cursor)
endfunction


function s:addMatches()
    let save_cursor = getpos('.')

    let mode = mode()
    if mode == "n"
        normal viw
        exe 'normal /\V'.escape(<cword>, '/').'/:<C-U>call '.<SID>.'addSelection()'
    else
        if mode == "V"
            let len = strlen(text) - 1
            let text = input("Search: ")
        elseif mode == "v"
            let len = (col('.') - col('v')) - 1
            let text = join(getline(line('v'), line('.')), '')
        else
            call <SID>reset()
            call setpos('.', save_cursor)
            return
        endif
        exe 'normal /\V'.escape(text, '/').'/v'.repeat('l', len).':<C-U>call '.<SID>.'addSelection()'
    endif
    silent exe ':nohlsearch'

    " restore cursor position
    call setpos('.', save_cursor)
endfunction


"""""""""""""""""
"  Keybindings  "
"""""""""""""""""
map <Plug>MultiEditAdd :<C-U>call <SID>addSelection()<CR>
map <Plug>MultiEditAll :<C-U>call <SID>addMatches()<CR>
map <Plug>MultiEditInsert :<C-U>call <SID>startEdit(0)<CR>
map <Plug>MultiEditAppend :<C-U>call <SID>startEdit(1)<CR>
map <Plug>MultiEditChange :<C-U>call <SID>startEdit(2)<CR>
map <Plug>MultiEditReset :<C-U>call <SID>reset()<CR>

if g:multiedit_nomappings != 1
    vmap <leader>m <Plug>MultiEditAdd
    nmap <leader>m v<Plug>MultiEditAdd
    nmap <leader>M <Plug>MultiEditAll
    vmap <leader>M <Plug>MultiEditAll
    nmap <leader>I <Plug>MultiEditInserti
    nmap <leader>A <Plug>MultiEditAppendi
    nmap <leader>C <Plug>MultiEditchangea
endif 
