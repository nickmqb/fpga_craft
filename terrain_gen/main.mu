//tab_size=4
// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

main() {
	::currentAllocator = Memory.newArenaAllocator(checked_cast(uint.maxValue, ssize))

	IntVector2.static_init_delta_8()
	IntVector3.static_init_delta()
	Biomes.static_init_masks()

	argErrors := new List<CommandLineArgsParserError>{}
	parser := new CommandLineArgsParser.from(Environment.getCommandLineArgs(), argErrors)
	args := parseArgs(parser)

	if argErrors.count > 0 {
		info := parser.getCommandLineInfo()
		for argErrors {
			Stderr.writeLine(CommandLineArgsParser.getErrorDesc(it, info))
		}
		exit(1)
	}

	seed := args.seed != 0 ? args.seed : time(null)

	grid := cast(null, Grid)
	if args.dimension == 1 {
		grid = generateOverworld(seed)
	} else if args.dimension == 2 {
		grid = generateDimStub(seed, 128)
	} else if args.dimension == 3 {
		grid = generateDimStub(seed, 256)
	} else {
		abandon()
	}

	writeGrid(grid, args.outputPath)
	Stdout.writeLine(format("Map written to: {}", args.outputPath))
}
