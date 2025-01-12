bye
"Mapping for cnext, cprev, cnfile, cpfile
nmap	<silent>	<RIGHT>	:cnext<CR>
nmap	<silent>	<RIGHT><RIGHT> 	:cnfile<CR><C-G>
nmap	<silent>	<LEFT>	:cprev<CR>
nmap	<silent>	<LEFT><LEFT>	:cpfile<CR><G-G>

"Tab navigation
nmap	<silent>	<UP>	:tabn<CR>
nmap	<silent>	<DOWN>	:tabp<CR>


"Only apply to .txt files...
augroup HelpInTabs
	autocmd!
	autocmd BufEnter  *.txt	  call	HelpInNewTab()
augroup END

"Only apply to help files...
function! HelpInNewTab ()
	if &buftype == 'help'
		"Convert the help window to a tab...
		execute "normal \<C-W>T"
	endif
endfunction	

set matchpairs+=<:>
set matchpairs+=":"
set matchpairs+==:;
"Can deleteback paststart of edit
"Can delete back past autoindent
"Can delete back to previous line
set backspace=indent,eol,start

nnoremap  /  /\v
set ic
set sc
set is
set hlsearch
nmap <silent> <BS>  :nohlsearch<CR>
"set wildchar=<TAB> character that initiate completion
set wildmode=list:longest,full

" undo files
if has('persistent_undo')
	set undofile
endif
set undodir=$HOME/.VIM_UNDO_FILES
set undolevels=5000
set history=2000		" keep 2000 lines of command line history

highlight Cursorline	term=bold	cterm=inverse
highlight CursorColumn	cterm=inverse   ctermfg=white	ctermbg=magenta
set cursorline
set cursorcolumn
"set colorcolumn=81
highlight ColorColumn ctermbg=magenta
call matchadd('ColorColumn', '\%>81v', 100)
let &t_ti.="\e[1 q"
let &t_SI.="\e[5 q"
let &t_EI.="\e[1 q"
let &t_te.="\e[0 q"

"Folding indent or syntax
"syntax enable
"foldmethod=syntax

"set foldexpr=strlen(matchstr(getline(v:lnum),'^_*'))
"setfoldmathod=expr
"... which creates a fold for each block structure.

set foldmethod=indent
set foldopen=all
set foldclose=all
set foldcolumn=5
"filetype plugin on
"set omnifunc=syntaxcomplete#Complete
"Define for perls CTRLX CTRLD --- CTRLX- CTRLI  -- CTRLX CTRLN -- CTRLX CTRLO: omnicompletion ( set
"iskeyword=a-z,A-Z,48-57,-,.,_,@,0-9....)
set define=^\\s*sub
