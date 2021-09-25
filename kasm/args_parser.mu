//tab_size=4
// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

SourceFile struct #RefType {
    path string
    text string
}

Args struct #RefType {
    source SourceFile
	outputPath string
}

tryReadSourceFile(path string) {
    sb := new StringBuilder{}
    if !File.tryReadToStringBuilder(path, sb) {
        return null
    }
    sb.writeChar('\0')
    return new SourceFile { path: path, text: sb.compactToString() }
}

parseArgs(parser CommandLineArgsParser, isCompiler bool) {
    args := new Args{}

    token := parser.readToken()

    while token != "" {
        if token.startsWith("-") {
			if token == "--output" {
				token = parser.readToken()
				if token != "" {
					args.outputPath = token
				} else {
					parser.expected("path")
				}
			} else {
				parser.error(format("Invalid flag: {}", token))
			}
        } else {
			if args.source == null {
            	sf := tryReadSourceFile(token)
            	if sf != null {
                	args.source = sf
            	} else {
                	parser.error(format("Could not read file: {}", token))
				}
            } else {
				parser.error(format("Invalid argument: {}", token))
			}
        }
		token = parser.readToken()
    }

	if args.source == null {
		parser.expected("source file")
	}
	if args.outputPath == "" {
		parser.expected("--output [path]")
	}

    return args
}
