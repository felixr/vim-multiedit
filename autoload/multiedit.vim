" *multiedit.txt* Multi-editing for Vim   

" addRegion() {{
func! multiedit#addRegion(is_marker)
    if mode() != 'v'
        normal! gv
    endif

    " Get region parameters
    let line = line('.')
    let startcol = col('v')
    let endcol = col('.')+1

    " add selection to list
    let sel = { 'line': line, 
        \ 'col': startcol,
        \ 'len': endcol-startcol,
        \ 'suffix_length': col('$')-endcol,
        \ 'is_marker': a:is_marker
    \ }
    if !exists("b:regions")
        let b:regions = {}
        let b:first_region = sel
    endif

    if has_key(b:regions, line)
        " Check if this overlaps with any other region
        let overlapid = s:hasOverlap(sel)
        if overlapid == -1
            let b:regions[line] = b:regions[line] + [sel]
        else
            " If so, change this to the 'main' region
            let b:first_region = b:regions[line][overlapid]
            let new_first = 1
        endif
    else
        let b:regions[line] = [sel]
    endif

    " Highlight the region
    if exists("new_first")
        call s:rehighlight()
    else
        call s:highlight(line, startcol, endcol)
    endif

    " Exit visual mode
    normal! v
endfunc
" }}

" addMark() {{
func! multiedit#addMark(mode)
    let mark = g:multiedit_mark_character

    " Insert the marker character and select it
    let line = getline('.')
    let col = col('.')

    " Insert the markers, pre or post, depending on the mode
    let precol = a:mode ==# "i" ? 2 : 1
    let sufcol = a:mode ==# "i" ? 1 : 0
    call setline(line('.'), line[0:col-precol].mark.line[(col-sufcol):])
    if a:mode ==# "a"
        normal! l
    endif
    normal! v

    let line = line('.')
    if exists("b:regions") && has_key(b:regions, line)
        " Check for regions on the same line that follow this region and shift
        " them to the right.
        let col = col('.')
        for region in b:regions[line]
            let offset = strlen(mark)
            if region.col > col
                let region.col += offset
            else
                let region.suffix_length += offset
            endif
        endfor

        call s:rehighlight()
    endif

    " ...then make it a region
    call multiedit#addRegion(1)
endfunc
" }}

" start() {{
func! multiedit#start(bang, ...)
    if !exists("b:regions") 
        if g:multiedit_auto_restore == 0 || !multiedit#again()
            return
        endif
    endif

    let lastcol = b:first_region.col + b:first_region.len

    " If bang exists, clear the word before you start editing
    if a:bang ==# '!'
        " Select the word
        call cursor(b:first_region.line, b:first_region.col)
        normal! v
        call cursor(b:first_region.line, lastcol-1)

        " Delete it, add the marker, and move the cursor ahead of it
        normal! d
        call multiedit#update(0)
        call cursor(b:first_region.line, b:first_region.col)

        " Refresh the lastcol (it's likely moved!)
        let lastcol = b:first_region.col + b:first_region.len
    else
        " Move cursor to the end of the word
        call cursor(b:first_region.line, lastcol)
    endif

    " Set up some 'abort' mappings, because they can't be accounted for. They
    " will unmap themselves once they're pressed.
    call s:maps(0)

    " Start insert mode. Since there's no way to mimic 'a' with :normal, we
    " have to do it manually:
    if col('$') == lastcol
        startinsert!
    else
        startinsert
    endif
    
    augroup multiedit
        au!
        " Update the highlights as you edit
        au CursorMovedI * call multiedit#update()

        " Once you leave INSERT, apply changes and delete this augroup
        au InsertLeave * call multiedit#finish() | au! multiedit

        if g:multiedit_auto_reset == 1
            " Clear all regions once you exit insert mode
            au InsertLeave * call multiedit#reset()
        endif
    augroup END
endfunc
" }}

" reset() {{
func! multiedit#reset()
    let b:regions_last = {}
    if exists("b:regions")
        let b:regions_last["regions"] = b:regions
        unlet b:regions
    endif
    if exists("b:first_region")
        let b:regions_last["first"] = b:first_region
        unlet b:first_region
    endif

    syn clear MultieditRegions
    syn clear MultieditFirstRegion

    silent! au! multiedit
endfunc
" }}

" clear() {{
func! multiedit#clear(...)
    if !exists("b:regions")
        return
    endif
    
    " The region to delete might have been provided as an argument.
    if a:0 == 1 && type(a:1) == 4
        let sel = a:1
    else
        let sel = {"col": col('v'), "end": col('.'), "line":line('.')}
    endif

    if !has_key(b:regions, sel.line)
        return
    endif

    " Iterate through all regions on this line
    let i = 0
    for region in b:regions[sel.line]
        " Does this cursor overlap with this region? If so, delete it.
        if s:isOverlapping(sel, region)

            if region == b:first_region
                unlet b:first_region
                if len(b:regions[sel.line]) > 1
                    let b:first_region = b:regions[sel.line][-1]
                endif
            endif

            unlet b:regions[sel.line][i]
        endif
        let i += 1
    endfor

    " The regions have changed. Update the highlights.
    call s:rehighlight()
endfunc
" }}

" finish() {{
" Do changes across all regions
func! multiedit#finish()
    " Undo maps
    call s:maps(0)

    " Save cursor position
    let b:save_cursor = getpos('.')

    " Prepare the new, altered line
    let linetext = getline(b:first_region.line)
    let linelen = len(linetext)
    let newtext = linetext[(b:first_region.col-1): (linelen-b:first_region.suffix_length-1)]

    " Iterate through the lines where regions exist. And sort them by
    " sequence.
    for line in sort(keys(b:regions))
        let s:offset = 0
        let regions = sort(b:regions[line], "s:entrySort")

        " Iterate through each region on this line
        for region in regions
            let region.col += s:offset 
            if region.line != b:first_region.line || region.col != b:first_region.col
                " Get the old line
                let oldline = getline(region.line)

                " ...and assemble a new one
                let prefix = ''
                if region.col > 1
                    let prefix = oldline[0:region.col-2]
                endif
                let suffix = oldline[(region.col+region.len-1):]

                " Update the line
                call setline(region.line, prefix.newtext.suffix) 
            endif

            let s:offset = s:offset + len(newtext) - region.len
            let region.len = len(newtext)
        endfor
    endfor

    " Restore cursor position
    call setpos('.', b:save_cursor)

    " Clean up
    call multiedit#reset()
endfunc
" }}

" update() {{
" Update highlights when changes are made
func! multiedit#update()
    if !exists('b:regions')
        return
    endif

    let line = b:first_region.line

    " Prepare the new, altered line
    let linetext = getline(line)
    let newtext = linetext[(b:first_region.col-1): (len(linetext)-b:first_region.suffix_length-1)]
    let regions = sort(b:regions[line], "s:entrySort")
    let s:offset = 0

    " Iterate through each region on this line
    for region in regions
        " ...move the highlight offset of regions after it
        if region.col >= b:first_region.col
            let region.col += s:offset 
            let s:offset = s:offset + len(newtext) - b:first_region.len
        endif
        
        " ...and update the length of the first_region
        if region.col == b:first_region.col
            let region.len = len(newtext)
        endif
    endfor

    " Remeasure the strlen
    let b:first_region.suffix_length = col([b:first_region.line, '$']) - b:first_region.col - b:first_region.len

    " Redo highlights because they've likely moved
    call s:rehighlight()
endfunc
" }}

" again() {{
" Restore last region selections. Returns 1 on success, 0 on failure.
func! multiedit#again()
    if !exists("b:regions_last")
        echom "No regions to restore!"
        return
    endif

    let b:first_region = b:regions_last["first"]
    let b:regions = b:regions_last["regions"]

    call multiedit#update(0)
    return 1
endfunc
" }}

""""""""""""""""""""""""""(
" isOverlapping(selA, selB) {{
" Checks to see if selA overlaps with selB
func! s:isOverlapping(selA, selB)
    " Check for invalid input
    if type(a:selA) != 4 || type(a:selB) != 4
        return
    endif

    " If they're not on the same line, don't even try.
    if a:selA.line != a:selB.line
        return
    endif

    " Check for overlapping
    let selAend = a:selA.col + a:selA.len
    let selBend = a:selB.col + a:selB.len
    return a:selA.col == a:selB.col || selAend == selBend 
                \ || a:selA.col == selBend || selAend == a:selB.col
                \ || (a:selA.col > a:selB.col && a:selA.col < selBend)
                \ || (selAend < selBend && selAend > a:selB.col)
endfunc
" }}

" hasOverlap(sel) {{
" Checks to see if any other regions overlap with this one. Returns -1 if not,
" and the id of it otherwise (e.g. b:regions[line][id])
func! s:hasOverlap(sel)
    if type(a:sel) != 4 || !has_key(b:regions, a:sel.line)
        return -1
    endif

    for i in range(len(b:regions[a:sel.line]))
        if s:isOverlapping(a:sel, b:regions[a:sel.line][i])
            return i
        endif
    endfor
    return -1
endfunc
" }}

" highlight(line, start, end) {{
func! s:highlight(line, start, end)
    if !exists("b:first_region") || (b:first_region.line == a:line && b:first_region.col == a:start)
        let synid = "MultieditFirstRegion"
    else
        let synid = "MultieditRegions"
    endif
    execute "syn match ".synid." '\\%".a:line."l\\%".a:start."c\\_.*\\%".a:line."l\\%".a:end."c' containedin=ALL"
endfunc
" }}

" rehighlight() {{
func! s:rehighlight()
    syn clear MultieditRegions
    syn clear MultieditFirstRegion

    " Go through regions and rehighlight them
    for line in keys(b:regions)
        for sel in b:regions[line]
            call s:highlight(line, sel.col, sel.col + sel.len)
        endfor
    endfor
endfunc
" }}

" unmap() {{
func! s:maps(unmap)
    if a:unmap
        iunmap <buffer><silent> <CR>
        iunmap <buffer><silent> <Up>
        iunmap <buffer><silent> <Down>
    else
        inoremap <buffer><silent> <CR> <Esc><CR>:call s:maps(1)<CR>
        inoremap <buffer><silent> <Up> <Esc><Up>:call s:maps(1)<CR>
        inoremap <buffer><silent> <Down> <Esc><Down>:call s:maps(1)<CR>
    endif
endfunc
" }}

" entrySort() {{
func! s:entrySort(a, b)
    return a:a.col == a:b.col ? 0 : a:a.col > a:b.col ? 1 : -1
endfunc
" }}

" vim: set foldmarker={{,}} foldlevel=0 foldmethod=marker
