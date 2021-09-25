//tab_size=4
// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

Args struct #RefType {
	outputPath string
	dimension int
    seed uint
}

parseArgs(parser CommandLineArgsParser) {
    args := new Args{}

    token := parser.readToken()

    while token != "" {
		if token == "--output" {
			token = parser.readToken()
			if token != "" {
				args.outputPath = token
			} else {
				parser.expected("path")
			}
		} else if token == "--seed" {
			token = parser.readToken()
			pr := uint.tryParse(token)
			if pr.hasValue && pr.value > 0 {
				args.seed = pr.value
			} else {
				parser.error("Expected: number")
			}
		} else if token == "--dimension" {
			token = parser.readToken()
			pr := int.tryParse(token)
			if pr.hasValue && pr.value >= 1 && pr.value <= 3 {
				args.dimension = pr.value
			} else {
				parser.error("Expected: 1, 2 or 3")
			}
		} else {
			parser.error(format("Invalid flag: {}", token))
		}
		token = parser.readToken()
    }

	if args.outputPath == "" {
		parser.expected("--output [path]")
	}
	if args.dimension == 0 {
		parser.expected("--dimension [1, 2 or 3]")
	}

    return args
}
