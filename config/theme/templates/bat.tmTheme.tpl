<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<!-- bat theme for the current Omarchy theme. Rendered (by Omarchy, or by dotfiles
     on machines without it) into ~/.local/state/omarchy/current/theme/bat.tmTheme;
     the theme-set hook installs it as bat's "omarchy" theme. Scopes from knuckles.tmTheme. -->
<plist version="1.0">
<dict>
	<key>colorSpaceName</key>
	<string>sRGB</string>
	<key>name</key>
	<string>Omarchy</string>
	<key>semanticClass</key>
	<string>theme.dark.knuckles</string>
	<key>settings</key>
	<array>
		<dict>
			<key>settings</key>
			<dict>
				<key>background</key>
				<string>{{ background }}</string>
				<key>caret</key>
				<string>{{ bright_foreground }}</string>
				<key>findHighlight</key>
				<string>{{ accent }}</string>
				<key>findHighlightForeground</key>
				<string>{{ background }}</string>
				<key>foreground</key>
				<string>{{ foreground }}</string>
				<key>gutter</key>
				<string>{{ background }}</string>
				<key>gutterForeground</key>
				<string>{{ dark_foreground }}</string>
				<key>invisibles</key>
				<string>{{ muted }}</string>
				<key>lineHighlight</key>
				<string>{{ lighter_background }}</string>
				<key>selection</key>
				<string>{{ selection }}</string>
				<key>selectionForeground</key>
				<string>{{ foreground }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Comment</string>
			<key>scope</key>
			<string>comment, comment.line, comment.block, punctuation.definition.comment</string>
			<key>settings</key>
			<dict>
				<key>fontStyle</key>
				<string>italic</string>
				<key>foreground</key>
				<string>{{ dark_foreground }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>String</string>
			<key>scope</key>
			<string>string, string.quoted, string.quoted.double, string.quoted.single, string.unquoted, punctuation.definition.string</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>{{ green }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Escape</string>
			<key>scope</key>
			<string>constant.character.escape, string.regexp</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>{{ bright_cyan }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Number</string>
			<key>scope</key>
			<string>constant.numeric, constant.language, constant</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>{{ orange }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Constant</string>
			<key>scope</key>
			<string>constant.other, support.constant, variable.language</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>{{ orange }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Keyword</string>
			<key>scope</key>
			<string>keyword, keyword.control, storage, storage.type, storage.modifier</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>{{ magenta }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Operator</string>
			<key>scope</key>
			<string>keyword.operator, punctuation.separator, punctuation.terminator</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>{{ cyan }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Function</string>
			<key>scope</key>
			<string>entity.name.function, support.function, meta.function, meta.function-call</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>{{ blue }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Type</string>
			<key>scope</key>
			<string>entity.name.type, entity.name.class, support.type, support.class, entity.other.inherited-class</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>{{ yellow }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Variable</string>
			<key>scope</key>
			<string>variable, variable.other, variable.parameter, entity.name.tag</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>{{ light_foreground }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Property</string>
			<key>scope</key>
			<string>variable.other.member, meta.object-literal.key, support.type.property-name</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>{{ light_foreground }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Attribute</string>
			<key>scope</key>
			<string>entity.other.attribute-name, meta.attribute</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>{{ yellow }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Tag delimiter</string>
			<key>scope</key>
			<string>punctuation.definition.tag</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>{{ red }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Namespace</string>
			<key>scope</key>
			<string>entity.name.namespace, entity.name.module, meta.namespace</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>{{ yellow }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Decorator</string>
			<key>scope</key>
			<string>meta.decorator, entity.name.decorator, meta.annotation</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>{{ orange }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Heading</string>
			<key>scope</key>
			<string>markup.heading, entity.name.section</string>
			<key>settings</key>
			<dict>
				<key>fontStyle</key>
				<string>bold</string>
				<key>foreground</key>
				<string>{{ blue }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Punctuation</string>
			<key>scope</key>
			<string>punctuation, meta.brace, punctuation.section</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>{{ foreground }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Invalid</string>
			<key>scope</key>
			<string>invalid, invalid.illegal</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>{{ bright_red }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Deprecated</string>
			<key>scope</key>
			<string>invalid.deprecated</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>{{ red }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Diff inserted</string>
			<key>scope</key>
			<string>markup.inserted, markup.inserted.diff</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>{{ green }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Diff deleted</string>
			<key>scope</key>
			<string>markup.deleted, markup.deleted.diff</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>{{ red }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Diff changed</string>
			<key>scope</key>
			<string>markup.changed, markup.changed.diff</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>{{ yellow }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Diff header</string>
			<key>scope</key>
			<string>meta.diff.header, meta.diff.range</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>{{ bright_cyan }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Markup link</string>
			<key>scope</key>
			<string>markup.underline.link, string.other.link</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>{{ blue }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Markup bold</string>
			<key>scope</key>
			<string>markup.bold</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>{{ yellow }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Markup italic</string>
			<key>scope</key>
			<string>markup.italic</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>{{ magenta }}</string>
			</dict>
		</dict>
		<dict>
			<key>name</key>
			<string>Markup raw</string>
			<key>scope</key>
			<string>markup.raw, markup.raw.inline</string>
			<key>settings</key>
			<dict>
				<key>foreground</key>
				<string>{{ green }}</string>
			</dict>
		</dict>
	</array>
	<key>uuid</key>
	<string>888a6e19-80c7-4741-a84d-c9580952155a</string>
</dict>
</plist>
