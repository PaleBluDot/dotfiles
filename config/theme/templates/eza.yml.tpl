# eza theme: copy to ~/.config/eza/theme.yml (or set EZA_CONFIG_DIR).
colourful: true
filekinds:
  normal: { foreground: "{{ foreground }}" }
  directory: { foreground: "{{ blue }}", is_bold: true }
  symlink: { foreground: "{{ cyan }}" }
  pipe: { foreground: "{{ yellow }}" }
  block_device: { foreground: "{{ yellow }}", is_bold: true }
  char_device: { foreground: "{{ yellow }}", is_bold: true }
  socket: { foreground: "{{ magenta }}" }
  special: { foreground: "{{ magenta }}" }
  executable: { foreground: "{{ green }}", is_bold: true }
perms:
  user_read: { foreground: "{{ yellow }}" }
  user_write: { foreground: "{{ red }}" }
  user_execute_file: { foreground: "{{ green }}" }
  user_execute_other: { foreground: "{{ green }}" }
  group_read: { foreground: "{{ yellow }}" }
  group_write: { foreground: "{{ red }}" }
  group_execute: { foreground: "{{ green }}" }
  other_read: { foreground: "{{ yellow }}" }
  other_write: { foreground: "{{ red }}" }
  other_execute: { foreground: "{{ green }}" }
size:
  number_byte: { foreground: "{{ foreground }}" }
  number_kilo: { foreground: "{{ cyan }}" }
  number_mega: { foreground: "{{ blue }}" }
  number_giga: { foreground: "{{ magenta }}" }
  number_huge: { foreground: "{{ red }}" }
  unit_byte: { foreground: "{{ dark_foreground }}" }
  unit_kilo: { foreground: "{{ dark_foreground }}" }
  unit_mega: { foreground: "{{ dark_foreground }}" }
  unit_giga: { foreground: "{{ dark_foreground }}" }
  unit_huge: { foreground: "{{ dark_foreground }}" }
users:
  user_you: { foreground: "{{ yellow }}" }
  user_other: { foreground: "{{ dark_foreground }}" }
  group_yours: { foreground: "{{ yellow }}" }
  group_other: { foreground: "{{ dark_foreground }}" }
git:
  new: { foreground: "{{ green }}" }
  modified: { foreground: "{{ yellow }}" }
  deleted: { foreground: "{{ red }}" }
  renamed: { foreground: "{{ cyan }}" }
  ignored: { foreground: "{{ muted }}" }
  conflicted: { foreground: "{{ bright_red }}" }
date: { foreground: "{{ blue }}" }
inode: { foreground: "{{ dark_foreground }}" }
links: { foreground: "{{ dark_foreground }}" }
punctuation: { foreground: "{{ muted }}" }
