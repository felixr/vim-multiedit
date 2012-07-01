" |buffer-variable|    b:	  Local to the current buffer.
" |window-variable|    w:	  Local to the current window.
" |tabpage-variable|   t:	  Local to the current tab page.
" |global-variable|    g:	  Global.
" |local-variable|     l:	  Local to a function.
" |script-variable|    s:	  Local to a |:source|'ed Vim script.
" |function-argument|  a:	  Function argument (only inside a function).
" |vim-variable|	     v:	  Global, predefined by Vim.

hi default MultiSelections gui=reverse term=reverse cterm=reverse

function! s:highlight(line, start, end)
    execute "syn match MultiSelections '\\%".a:line."l\\%".a:start."c\\_.*\\%".a:line."l\\%".a:end."c' containedin=ALL"
endfunction

function! s:addSelection()

    " restore selection
    normal! gv

    " get selection parameters
    let lnum = line('.')
    let startcol = col('v')
    let endcol  = col('.')+1
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


function! s:reset()
    if exists('b:selections')
        unlet b:selections
    endif
    if exists('b:first_selection')
        unlet b:first_selection
    endif
    syn clear MultiSelections
    aug multiedit 
        au!
    aug END
endfunction


function! s:startEdit()
    if !exists('b:selections')
        return
    endif
    call cursor(b:first_selection.line, (b:first_selection.col + b:first_selection.len))
    augroup multiedit 
        au!
        au CursorMovedI <buffer> * call s:updateSelections(0)
        " au InsertLeave <buffer> * call s:updateSelections(1)
    augroup END
endfunction


function! s:EntrySort(a,b)
    return a:a.col == a:b.col ? 0 : a:a.col > a:b.col ? 1 : -1
endfunction

function! s:updateSelections(flag)

    " Save cursor position
    let b:save_cursor = getpos('.')
    let b:save_col = col(".")
    let b:save_line = line(".")
    let genutils#SaveHardPosition('multi')

    echo a:flag
    if !exists('b:selections')
        return
    endif

    if a:flag == 1
        au! multiedit 
    endif 


    syn clear MultiSelections

    let editline = getline(b:first_selection.line)
    let line_length = len(editline)
    let newtext = editline[ (b:first_selection.col-1): (line_length-b:first_selection.suffix_length-1)]


    for line in sort(keys(b:selections))
        let entries = b:selections[line]
        let entries = sort(entries, "s:EntrySort")
        let s:offset = 0

        for entry in entries
            let entry['offset'] = s:offset
            if entry.line != b:first_selection.line || entry.col != b:first_selection.col 
                let entry.col = entry.col + s:offset
                let oldline = getline(entry.line)
                let prefix = ''
                if entry.col > 1
                    let prefix = oldline[0:entry.col-2]
                endif
                let suffix = oldline[(entry.col+entry.len-1):]
        
                call setline(entry.line, prefix.newtext.suffix) 
            endif
            let s:offset = s:offset + len(newtext) - entry.len 

            let entry.len = len(newtext)

            call s:highlight(entry.line, entry.col, entry.col+entry.len)
        endfor
    endfor

    let b:first_selection.suffix_length = col([b:first_selection.line, '$']) - b:first_selection.col - b:first_selection.len

    " restore cursor position
    call cursor(b:save_line, b:save_col) 

endfunction

map <Plug>(multiedit-add) :<C-U>call <SID>addSelection()<CR>
map <Plug>(multiedit-edit) :<C-U>call <SID>startEdit()<CR>
map <Plug>(multiedit-reset) :<C-U>call <SID>reset()<CR>

vmap ,f <Plug>(multiedit-add)
nmap ,f viw,fb
nmap  ,i <Plug>(multiedit-edit)i
map  ,r <Plug>(multiedit-reset)
