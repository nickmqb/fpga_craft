// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

AppState struct #RefType {
	playerPos Vector3
	playerYaw float
	playerPitch float
	grid Grid
	light Grid
	blockInfos Array<BlockInfo>
	blockTextureInfos Array<BlockTextureInfo>
	clip bool
	gridVertexBuffer GridBuffer
	waterVertexBuffer GridBuffer
}

readFile(path string) {
	sb := StringBuilder{}
	if !File.tryReadToStringBuilder(path, ref sb) {
		Stderr.writeLine(format("Could not read: {}", path))
		abandon()
	}
	return sb.compactToString()
}

getKeyState() {
	num := 0
	data := SDL_GetKeyboardState(ref num)
	return Array.fromTypedPtr(data, num)
}

updateLight(block Grid, light Grid, skyLightLevel int) {
	for z := 0; z < block.size.z {
		for x := 0; x < block.size.x {
			sky := skyLightLevel
			for y := block.size.y - 1; y >= 0; y -= 1 {
				ci := getCellIndex(block, x, y, z)
				ab := block.cells[ci] == 0 ? 0 : (block.cells[ci] == 1 ? 2 : 15)
				em := 0
				sky = max(0, sky - ab)
				lv := max(sky, em)
				for q in IntVector3.delta {
					ciAdj := getCellIndex(block, x + q.x, y + q.y, z + q.z)
					if ciAdj >= 0 {
						lv = max(lv, light.cells[ciAdj] - max(1, ab))
					}
				}
				light.cells[ci] = cast(lv, byte)
			}
		}
	}
}

generateTerrain(s AppState, args Args, seed uint) {
	if args.dimension == 1 {
		s.grid = generateOverworld(seed)
	} else if args.dimension == 2 {
		s.grid = generateDimStub(seed, 128)
	} else if args.dimension == 3 {
		s.grid = generateDimStub(seed, 256)
	} else {
		abandon()
	}
	initLight(s)
}

initLight(s AppState) {
	s.light = new createGrid(s.grid.size.x, s.grid.size.y, s.grid.size.z)
	Memory.memset(s.light.cells.dataPtr, 0x0f, cast(s.light.cells.count, usize))
	for i := 0; i < 16 {
		//updateLight(s.grid, s.light, 15)
	}
}

generateWorldMesh(s AppState, gridVertices List<GridVertex>, waterVertices List<GridVertex>) {
	gridVertices.clear()
	waterVertices.clear()
	buildGridVertices(s.grid, s.light, s.blockTextureInfos, gridVertices, waterVertices)
	s.gridVertexBuffer.update(ref gridVertices.slice(0, gridVertices.count))
	s.waterVertexBuffer.update(ref waterVertices.slice(0, waterVertices.count))
	//Stdout.writeLine(format("{}", gridVertices.count))
}

prepareTextures(textures Array<*Image>) {
	textures[126] = new Image.fromColor(16, 16, ByteColor4.rgbaf(4 / 15.0, 8 / 15.0, 1, 0.5)) // Repurpose for water rendering on PC

	for i := 0; i < textures.count {
		if textures[i].height > 16 {
			textures[i] = textures[i].cropHeight(16)
		}
		textures[i] = quantizeImage(textures[i])
	}
}

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

	width := 1280
	height := 800

	assert(SDL_Init(SDL_INIT_VIDEO) == 0)
	windowPtr := SDL_CreateWindow(pointer_cast("Terrain viewer", *sbyte), 200, 200, width, height, SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE)
	assert(windowPtr != null)
	glContextPtr := SDL_GL_CreateContext(windowPtr)
	assert(glContextPtr != null)

	s := new AppState{}

	gridEffect := GridEffect.init(readFile("grid_vs.glsl"), readFile("grid_fs.glsl"))

	images := loadImages()
	prepareTextures(images)
	s.blockInfos = initBlockInfos()
	s.blockTextureInfos = getBlockTextureInfos(s.blockInfos)
	textureArray := createTextureArrayFromImages(images)

	s.gridVertexBuffer = GridBuffer.init(83886080)
	s.waterVertexBuffer = GridBuffer.init(512 * 512 * 16)

	gridVertices := new List<GridVertex>{}
	gridVertices.reserve(s.gridVertexBuffer.maxNumVertices)
	waterVertices := new List<GridVertex>{}
	waterVertices.reserve(s.waterVertexBuffer.maxNumVertices)

	glEnable(GL_CULL_FACE)
	glCullFace(GL_BACK)

	glEnable(GL_DEPTH_TEST)
	glDepthFunc(GL_LEQUAL)

	if args.inputPath != "" {
		str := readFile(args.inputPath)
		bytes := new Array<byte> { dataPtr: str.dataPtr, count: str.length }
		s.grid = readGrid(bytes)
		initLight(s)
	} else {
		seed := args.seed != 0 ? args.seed : time(null)
		generateTerrain(s, args, seed)
		Stdout.writeLine("Note: map file will only be written to outputh path when you press F12")
		Stdout.writeLine(format("Seed: {}", seed))
	}

	s.playerPos = Vector3(-20, 40, -20)
	s.playerYaw = -.76
	s.playerPitch = -.6
	generateWorldMesh(s, gridVertices, waterVertices)
	bias := 0.0

	while true {
		e := SDL_Event{}
		while SDL_PollEvent(ref e) != 0 {
			ce := transmute(e, SDL_CommonEvent)
			if ce.type == cast(SDL_EventType.SDL_QUIT, uint) {
				return
			} else if ce.type == cast(SDL_EventType.SDL_WINDOWEVENT, uint) {
				ee := transmute(e, SDL_WindowEvent)
				if ee.event == cast(SDL_WindowEventID.SDL_WINDOWEVENT_SIZE_CHANGED, uint) {
					width = max(1280, ee.data1)
					height = max(768, ee.data2)
				}
			} else if ce.type == cast(SDL_EventType.SDL_KEYDOWN, uint) {
				ke := transmute(e, SDL_KeyboardEvent)
				mod := cast(SDL_GetModState(), uint)
				shift := (mod & KMOD_SHIFT) != 0
				if ke.keysym.scancode == SDL_Scancode.SDL_SCANCODE_F1 {
					s.clip = !s.clip
				}
				if ke.keysym.scancode == SDL_Scancode.SDL_SCANCODE_F2 {
					Stdout.writeLine(format("{} {} {}", s.playerPos.x, s.playerPos.y, s.playerPos.z))
				}
				if ke.keysym.scancode == SDL_Scancode.SDL_SCANCODE_F3 {
					seed := time(null)
					Stdout.writeLine(format("Seed: {}", seed))
					generateTerrain(s, args, seed)
					generateWorldMesh(s, gridVertices, waterVertices)
				}				
				//if ke.keysym.scancode == SDL_Scancode.SDL_SCANCODE_F11 {
				//	writeGridSim(s.grid, cast(s.playerPos.x, int), cast(s.playerPos.z, int))
				//	Stdout.writeLine("Map section (sim only) written to disk")
				//}				
				if ke.keysym.scancode == SDL_Scancode.SDL_SCANCODE_F12 {
					writeGrid(s.grid, args.outputPath)
					Stdout.writeLine(format("Map written to: {}", args.outputPath))
				}				
			}
		}

		dt := 1 / 60.0
		mod := cast(SDL_GetModState(), uint)
		shift := (mod & KMOD_SHIFT) != 0
		moveSpeed := shift ? 10 : 100
		rotateSpeed := shift ? 5 : 5
		move := Vector3(0, 0, 0)
		ks := getKeyState()
		if ks[cast(SDL_Scancode.SDL_SCANCODE_A, uint)] != 0 {
			move = Vector3.add(move, Vector3(-1, 0, 0))
		}
		if ks[cast(SDL_Scancode.SDL_SCANCODE_D, uint)] != 0 {
			move = Vector3.add(move, Vector3(1, 0, 0))
		}
		if ks[cast(SDL_Scancode.SDL_SCANCODE_S, uint)] != 0 {
			move = Vector3.add(move, Vector3(0, 0, -1))
		}
		if ks[cast(SDL_Scancode.SDL_SCANCODE_W, uint)] != 0 {
			move = Vector3.add(move, Vector3(0, 0, 1))
		}
		if ks[cast(SDL_Scancode.SDL_SCANCODE_LEFT, uint)] != 0 {
			s.playerYaw += dt * rotateSpeed
		}
		if ks[cast(SDL_Scancode.SDL_SCANCODE_RIGHT, uint)] != 0 {
			s.playerYaw -= dt * rotateSpeed
		}
		if ks[cast(SDL_Scancode.SDL_SCANCODE_DOWN, uint)] != 0 {
			s.playerPitch += dt * rotateSpeed
		}
		if ks[cast(SDL_Scancode.SDL_SCANCODE_UP, uint)] != 0 {
			s.playerPitch -= dt * rotateSpeed
		}
		if ks[cast(SDL_Scancode.SDL_SCANCODE_SPACE, uint)] != 0 {
			s.playerPos.y += dt * moveSpeed			
		}
		if ks[cast(SDL_Scancode.SDL_SCANCODE_C, uint)] != 0 {
			s.playerPos.y -= dt * moveSpeed
		}

		s.playerPitch = clamp(s.playerPitch, -.5 * pi, .5 * pi)

		playerMatrix := Matrix.mul(Matrix.rotationY(s.playerYaw), Matrix.rotationX(s.playerPitch))
		s.playerPos = s.playerPos.add(playerMatrix.mulv3(move.scale(moveSpeed * dt)))

		aspectRatio := cast(width, float) / height
		transform := Matrix.mul(Matrix.mul(Matrix.mul(Matrix.perspectiveFovLH(.333 * pi, aspectRatio, .05, 5000), 
			Matrix.rotationX(-s.playerPitch)),
			Matrix.rotationY(-s.playerYaw)),
			Matrix.translate(Vector3(-s.playerPos.x, -s.playerPos.y, -s.playerPos.z)))

		glViewport(0, 0, width, height)
		glClearColor(8 / 15.0, 12 / 15.0, 1, 0)
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

		gridEffect.begin(transform, s.playerPos.x, s.playerPos.z, s.clip)
		s.gridVertexBuffer.draw(textureArray.id)
		
		glEnable(GL_BLEND)
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
		s.waterVertexBuffer.draw(textureArray.id)
		glDisable(GL_BLEND)

		SDL_GL_SwapWindow(windowPtr)
	}
}
