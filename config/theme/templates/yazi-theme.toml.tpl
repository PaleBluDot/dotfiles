# yazi theme for the current theme: yazi's default layout with its colour
# names (blue, lightcyan…) turned into theme colours, so it matches the theme
# even in a terminal that isn't themed. Copy to ~/.config/yazi/theme.toml
# (yazi's own icon colours aren't included; they stay yazi's defaults).

[app]
overall = {}

# : }}}


# : Manager {{{

[mgr]
cwd = { fg = "{{ cyan }}" }

# Find
find_keyword  = { fg = "{{ yellow }}", bold = true, italic = true, underline = true }
find_position = { fg = "{{ magenta }}", bg = "reset", bold = true, italic = true }

# Symlink
symlink_target = { italic = true }

# Marker
marker_copied   = { fg = "{{ bright_green }}",  bg = "{{ bright_green }}" }
marker_cut      = { fg = "{{ bright_red }}",    bg = "{{ bright_red }}" }
marker_marked   = { fg = "{{ bright_cyan }}",   bg = "{{ bright_cyan }}" }
marker_selected = { fg = "{{ bright_yellow }}", bg = "{{ bright_yellow }}" }
marker_symbol   = "│"

# Count
count_copied   = { fg = "{{ foreground }}", bg = "{{ green }}" }
count_cut      = { fg = "{{ foreground }}", bg = "{{ red }}" }
count_selected = { fg = "{{ background }}", bg = "{{ yellow }}" }

# Border
border_symbol = "│"
border_style  = { fg = "{{ dark_foreground }}" }

# Highlighting
syntect_theme = ""

# : }}}


# : Tabs {{{

[tabs]
active   = { bg = "{{ blue }}", bold = true }
inactive = { fg = "{{ blue }}", bg = "{{ dark_foreground }}" }

# Separator
sep_inner = { open = "", close = "" }
sep_outer = { open = "", close = "" }

# : }}}


# : Mode {{{

[mode]
normal_main = { bg = "{{ blue }}", bold = true }
normal_alt  = { fg = "{{ blue }}", bg = "{{ dark_foreground }}" }

# Select mode
select_main = { bg = "{{ red }}", bold = true }
select_alt  = { fg = "{{ red }}", bg = "{{ dark_foreground }}" }

# Unset mode
unset_main = { bg = "{{ red }}", bold = true }
unset_alt  = { fg = "{{ red }}", bg = "{{ dark_foreground }}" }

# : }}}


# : Indicator of hovered file {{{

[indicator]
parent  = { reversed = true }
current = { reversed = true }
preview = { underline = true }
padding = { open = "", close = "" }

# : }}}


# : Status bar {{{

[status]
overall   = {}
sep_left  = { open = "", close = "" }
sep_right = { open = "", close = "" }

# Permissions
perm_sep   = { fg = "{{ muted }}" }
perm_type  = { fg = "{{ green }}" }
perm_read  = { fg = "{{ yellow }}" }
perm_write = { fg = "{{ red }}" }
perm_exec  = { fg = "{{ cyan }}" }

# Progress
progress_label  = { bold = true }
progress_normal = { fg = "{{ green }}", bg = "{{ background }}" }
progress_error  = { fg = "{{ yellow }}", bg = "{{ red }}" }

# : }}}


# : Which {{{

[which]
border          = { fg = "{{ blue }}" }
cols            = 3
mask            = {}
cand            = { fg = "{{ bright_cyan }}" }
rest            = { fg = "{{ muted }}" }
desc            = { fg = "{{ bright_magenta }}" }
separator       = "  "
separator_style = { fg = "{{ muted }}" }

# : }}}


# : Confirmation {{{

[confirm]
border     = { fg = "{{ blue }}" }
title      = { fg = "{{ blue }}" }
body       = {}
list       = {}
btn_yes    = { reversed = true }
btn_no     = {}
btn_labels = [ "  [Y]es  ", "  (N)o  " ]

# : }}}


# : Spotter {{{

[spot]
border = { fg = "{{ blue }}" }
title  = { fg = "{{ blue }}" }

# Table
tbl_col  = { fg = "{{ blue }}" }
tbl_cell = { fg = "{{ yellow }}", reversed = true }

# : }}}


# : Notification {{{

[notify]
title_info  = { fg = "{{ green }}" }
title_warn  = { fg = "{{ yellow }}" }
title_error = { fg = "{{ red }}" }

# Icons
icon_info  = ""
icon_warn  = ""
icon_error = ""

# : }}}


# : Picker {{{

[pick]
border   = { fg = "{{ blue }}" }
active   = { fg = "{{ magenta }}", bold = true }
inactive = {}

# : }}}


# : Input {{{

[input]
border   = { fg = "{{ blue }}" }
title    = {}
value    = {}
selected = { reversed = true }

# : }}}


# : Completion {{{

[cmp]
border   = { fg = "{{ blue }}" }
active   = { reversed = true }
inactive = {}

# Icons
icon_file    = ""
icon_folder  = ""
icon_command = ""

# : }}}


# : Task manager {{{

[tasks]
border  = { fg = "{{ blue }}" }
title   = {}
hovered = { fg = "{{ magenta }}", bold = true }

# : }}}


# : Help menu {{{

[help]
border  = { fg = "{{ blue }}" }
chord   = { fg = "{{ cyan }}" }
action  = {}
hovered = { reversed = true, bold = true }

# : }}}


# : File-specific styles {{{

[filetype]
rules = [
	# Image
	{ mime = "**/image/*", fg = "{{ yellow }}" },
	# Media
	{ mime = "**/{audio,video}/*", fg = "{{ magenta }}" },
	# Archive
	{ mime = "**/application/{zip,rar,7z*,tar,gzip,xz,zstd,bzip*,lzma,compress,archive,cpio,arj,xar,ms-cab*}", fg = "{{ red }}" },
	# Document
	{ mime = "**/application/{pdf,doc,rtf}", fg = "{{ cyan }}" },
	# Virtual file system
	{ mime = "vfs/{absent,stale}", fg = "{{ dark_foreground }}" },
	# Special file
	{ url = "*", is = "orphan", bg = "{{ red }}" },
	{ url = "*", is = "exec"  , fg = "{{ green }}" },
	# Dummy file
	{ url = "*", is = "dummy", bg = "{{ red }}" },
	{ url = "*/", is = "dummy", bg = "{{ red }}" },
	# Fallback
	{ url = "*/", fg = "{{ blue }}" }
]

# : }}}


# : Icons {{{

