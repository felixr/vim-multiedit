" *multiedit.txt* Multi-editing for Vim   

" addRegion() {{
func! multiedit#addRegion()
    if mode() != "v"
        normal! gv
    endif

    " Get region parameters
    let line = line('.')
    let startcol = col('v')
    let endcol = col('.')+1

    " add selection to list
    let sel = {'line': line, 'col': startcol, 'end': endcol, 'len': endcol-startcol, 'suffix_length': col('$')-endcol}
    if !exists("b:regions")
        let b:regions = {}
        let b:first_region = sel
    endif

    if has_key(b:regions, line)
        for region in b:regions[line]
            " Check for region overlap. If it does, overwrite the old one.
            if multiedit#isOverlapping(sel, region)
                call multiedit#clear(region)
                break
            endif
        endfor

        let b:regions[line] = b:regions[line] + [sel]
    else
        let b:regions[line] = [sel]
    endif

    " Highlight the region
    call multiedit#highlight(line, startcol, endcol)

    " Exit visual mode
    normal! v
endfunc
" }}

" addMark() {{
func! multiedit#addMark(mode)
    let mark = g:multiedit_mark_character

    " Insert the marker character and select it
    exe "normal! ".a:mode.g:multiedit_mark_character."v"

    let line = line('.')
    if exists("b:regions") && has_key(b:regions, line)
        " Check for regions on the same line that follow this region and shift
        " them to the right.
        let col = col('.')
        for region in b:regions[line]
            let offset = strlen(g:multiedit_mark_character)
            if region.col > col
                let region.col += offset
                let region.end += offset
            else
                let region.suffix_length += offset
            endif
        endfor

        call multiedit#rehighlight()
    endif

    " ...then make it a region
    call multiedit#addRegion()
endfunc
" }}

" TODO: addMatch() {{
func! multiedit#addMatch()
    if !index(['/', '?'], a:direction)
        echoe "Did not specify a valid direction to search for a match."
        return
    endif

    " Get into visual mode
    normal! v

    let text = join(getline(line('.')), "")[col('v'):col('.')]

    " Move to next iteration and reselect it
    exe "normal! ".a:direction."\V".escape(text, a:direction)."v".repeat("l", strlen(text)-1)

    " Add the region!
    call multiedit#addRegion()
endfunc
" }}

" edit() {{
func! multiedit#edit()
    if !exists("b:regions")
        return
    endif

    let lastcol = b:first_region.col + b:first_region.len

    " Move the cursor to the end of the first region
    call cursor(b:first_region.line, lastcol)

    " Set up some 'abort' mappings, because they can't be accounted for. They
    " will unmap themselves once they're pressed.
    call multiedit#maps(0)

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
        au CursorMovedI * call multiedit#update(0)

        " Once you leave INSERT, apply changes and delete this augroup
        au InsertLeave * 
                    \ call multiedit#update(1) |
                    \ call multiedit#maps(1) |
                    \ au! multiedit

        if g:multiedit_auto_reset == 1
            " Clear all regions once you exit insert mode
            au InsertLeave * call multiedit#reset()
        endif
    augroup END
endfunc
" }}

" reset() {{
func! multiedit#reset()
    if exists("b:regions")
        unlet b:regions
    endif
    if exists("b:first_region")
        unlet b:first_region
    endif

    syn clear MultieditRegions
    syn clear MultieditFirstRegion

    silent! au! multiedit
endfunc
" }}

" clear() {{
func! multiedit#clear(...)
    let line = line(".")
    if !exists("b:regions") || !has_key(b:regions, line)
        return
    endif

    let mode = mode()
    if mode == "V"
        " If in visual line mode, delete all regions on the line
        unlet b:regions[line]
        return 1
    elseif mode != "v"
        " If not in visual mode, make it so we are!
        normal! v
    endif

    " The region to delete might have been provided as an argument.
    if a:0 > 1 && type(a:1) == 4
        let sel = a:1
        let line = sel.line
    endif

    " Iterate through all regions on this line
    for region in b:regions[line]
        " If this is the first region, remove it. It will be set in the next
        " iteration of this loop.
        if region == b:first_region
            unlet b:first_region
        " ...as promised.
        elseif !exists("b:first_region")
            let b:first_region = region
        endif

        " Does this cursor overlap with this region? If so, delete it.
        if (exists("sel") && sel == region) || multiedit#isOverlapping(region, {"col": col("v"), "end": col(".")})
            unlet b:regions[line]
            break
        endif
    endfor

    " The regions have changed. Update the highlights.
    call multiedit#rehighlight()
endfunc
" }}

" update() {{
func! multiedit#update(change)
    if !exists('b:regions')
        return
    endif

    " Save cursor position
    let b:save_cursor = getpos('.')

    " Clear highlights so we can make changes and redo them later
    syn clear MultieditRegions
    syn clear MultieditFirstRegion

    " Prepare the new, altered line
    let linetext = getline(b:first_region.line)
    let linelen = len(linetext)
    let newtext = linetext[(b:first_region.col-1): (linelen-b:first_region.suffix_length-1)]

    " Iterate through the lines where regions exist. And sort them by
    " sequence.
    for line in sort(keys(b:regions))
        let regions = b:regions[line]
        let regions = sort(regions, "multiedit#entrySort")
        let s:offset = 0

        " Iterate through each region on this line
        for region in regions

            " If this region is on the same line as first_region...
            if region.line == b:first_region.line
                
                " ...move the highlight offset of regions after it
                if region.col >= b:first_region.col
                    let region.col += s:offset 
                    let s:offset = s:offset + len(newtext) - region.len
                endif

                " ...and update the length of the first_region
                if region.col == b:first_region.col
                    let region.len = len(newtext)
                endif

            endif

            if a:change != 0 && (region.line != b:first_region.line || region.col != b:first_region.col)
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

            call multiedit#highlight(region.line, region.col, region.col+region.len)

        endfor
    endfor

    " Remeasure the strlen from first_region.end to $
    let b:first_region.suffix_length = col([b:first_region.line, '$']) - b:first_region.col - b:first_region.len

    " Restore cursor position
    call setpos('.', b:save_cursor)
endfunc
" }}

""""""""""""""""""""""""""
" isOverlapping(selA, selB) {{
func! multiedit#isOverlapping(selA, selB)
    " Check for invalid input
    if type(a:selA) != 4 || type(a:selB) != 4
        return
    endif

    " If they're not on the same line, don't even try.
    if a:selA.line != a:selB.line
        return
    endif

    return a:selB.col == a:selA.col || a:selB.col == a:selA.end 
            \ || a:selB.end == a:selA.col || a:selB.end == a:selA.end
            \ || (a:selB.col > a:selA.col && a:selB.end < a:selA.end)
            \ || (a:selB.col < a:selA.col && a:selB.end > a:selA.end)
endfunc
" }}

" highlight(line, start, end) {{
func! multiedit#highlight(line, start, end)
    if !exists("b:first_region") || b:first_region.line == a:line && b:first_region.col == a:start
        let synid = "MultieditFirstRegion"
    else
        let synid = "MultieditRegions"
    endif
    execute "syn match ".synid." '\\%".a:line."l\\%".a:start."c\\_.*\\%".a:line."l\\%".a:end."c' containedin=ALL"
endfunc
" }}

" rehighlight() {{
func! multiedit#rehighlight()
    syn clear MultieditRegions
    syn clear MultieditFirstRegion

    " Go through regions and rehighlight them
    for line in keys(b:regions)
        for sel in b:regions[line]
            call multiedit#highlight(line, sel.col, sel.end)
        endfor
    endfor
endfunc
" }}

" unmap() {{
func! multiedit#maps(unmap)
    if a:unmap
        iunmap <buffer><silent> <CR>
        iunmap <buffer><silent> <Up>
        iunmap <buffer><silent> <Down>
    else
        inoremap <buffer><silent> <CR> <Esc><CR>:call multiedit#maps(1)<CR>
        inoremap <buffer><silent> <Up> <Esc><Up>:call multiedit#maps(1)<CR>
        inoremap <buffer><silent> <Down> <Esc><Down>:call multiedit#maps(1)<CR>
    endif
endfunc
" }}

" entrySort() {{
func! multiedit#entrySort(a, b)
    return a:a.col == a:b.col ? 0 : a:a.col > a:b.col ? 1 : -1
endfunc
" }}

" vim: set foldmarker={{,}} foldlevel=0 foldmethod=marker
