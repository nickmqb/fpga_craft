//tab_size=4
// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

GLUtil {
	createShader(type uint, s string) {
		id := glCreateShader(type)
		glShaderSource(id, 1, pointer_cast(ref s.dataPtr, **sbyte), ref s.length)
		glCompileShader(id)
		status := 0
		glGetShaderiv(id, GL_COMPILE_STATUS, ref status)
		//assert(cast(status, uint) == GL_TRUE)

		if cast(status, uint) != GL_TRUE {
			maxLength := 0
			glGetShaderiv(id, GL_INFO_LOG_LENGTH, ref maxLength)
			log := Array<char>(maxLength)
			glGetShaderInfoLog(id, maxLength, ref maxLength, pointer_cast(log.dataPtr, *sbyte))
			Stderr.writeLine(string.from(log.dataPtr, maxLength))
			abandon()
		}

		return id
	}

	createProgram(vs uint, ps uint) {
		id := glCreateProgram()
		glAttachShader(id, vs)
		glAttachShader(id, ps)
		glLinkProgram(id)
		status := 0
		glGetProgramiv(id, GL_LINK_STATUS, ref status)
		assert(cast(status, uint) == GL_TRUE)
		glDetachShader(id, vs)
		glDetachShader(id, ps)
		return id
	}
}

VertexPos3fColor4b struct {
	pos Vector3
	color ByteColor4

	cons(x float, y float, z float, color ByteColor4) {
		return VertexPos3fColor4b { pos: Vector3(x, y, z), color: color }
	}
}

ColorEffect struct #RefType {
	vs uint
	fs uint
	program uint
	u_transform int
	vao uint
	vbo uint

	:maxNumVertices = 4096

	init(vsText string, fsText string) {
		s := new ColorEffect{}

		s.vs = GLUtil.createShader(GL_VERTEX_SHADER, vsText)
		s.fs = GLUtil.createShader(GL_FRAGMENT_SHADER, fsText)
		s.program = GLUtil.createProgram(s.vs, s.fs)
		s.u_transform = glGetUniformLocation(s.program, pointer_cast("transform\0".dataPtr, *sbyte))

		glGenVertexArrays(1, ref s.vao)
		glGenBuffers(1, ref s.vbo)
		
		glBindVertexArray(s.vao)
		glBindBuffer(GL_ARRAY_BUFFER, s.vbo)
		glBufferData(GL_ARRAY_BUFFER, sizeof(VertexPos3fColor4b) * maxNumVertices, null, GL_DYNAMIC_DRAW)

		glVertexAttribPointer(0, 3, GL_FLOAT, false, sizeof(VertexPos3fColor4b), null)
		glEnableVertexAttribArray(0)

		glVertexAttribPointer(1, 4, GL_UNSIGNED_BYTE, true, sizeof(VertexPos3fColor4b), transmute(12, pointer))
		glEnableVertexAttribArray(1)

		return s
	}

	begin(s ColorEffect, transform Matrix) {
		glUseProgram(s.program)
		glUniformMatrix4fv(s.u_transform, 1, false, ref transform.m00)
	}

	render(s ColorEffect, vertices List<VertexPos3fColor4b>) {
		assert(vertices.count <= maxNumVertices)

		if vertices.count == 0 {
			return
		}

		glBindVertexArray(s.vao)

		glBindBuffer(GL_ARRAY_BUFFER, s.vbo)
		glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(VertexPos3fColor4b) * vertices.count, vertices.dataPtr)

		glDrawArrays(GL_TRIANGLES, 0, vertices.count)
	}
}

GridVertex struct {
	x ushort
	y ushort
	zAttr ushort
	attr ushort
}

GridEffect struct #RefType {
	vs uint
	fs uint
	program uint
	u_transform int
	u_player int
	u_sampler int

	init(vsText string, fsText string) {
		s := new GridEffect{}

		s.vs = GLUtil.createShader(GL_VERTEX_SHADER, vsText)
		s.fs = GLUtil.createShader(GL_FRAGMENT_SHADER, fsText)
		s.program = GLUtil.createProgram(s.vs, s.fs)
		s.u_transform = glGetUniformLocation(s.program, pointer_cast("transform\0".dataPtr, *sbyte))
		s.u_player = glGetUniformLocation(s.program, pointer_cast("player\0".dataPtr, *sbyte))
		s.u_sampler = glGetUniformLocation(s.program, pointer_cast("sampler\0".dataPtr, *sbyte))

		return s
	}

	begin(s GridEffect, transform Matrix, playerX float, playerZ float, enableClip bool) {
		glUseProgram(s.program)
		glUniformMatrix4fv(s.u_transform, 1, false, ref transform.m00)
		glUniform3f(s.u_player, playerX, enableClip ? 1 : 0, playerZ)
		glUniform1i(s.u_sampler, 0)
	}
}

GridBuffer struct #RefType {
	vao uint
	vbo uint	
	numVertices int
	maxNumVertices int

	init(maxNumVertices int) {
		s := new GridBuffer { maxNumVertices: maxNumVertices }

		glGenVertexArrays(1, ref s.vao)
		glGenBuffers(1, ref s.vbo)
		
		glBindVertexArray(s.vao)
		glBindBuffer(GL_ARRAY_BUFFER, s.vbo)
		glBufferData(GL_ARRAY_BUFFER, sizeof(GridVertex) * maxNumVertices, null, GL_DYNAMIC_DRAW)

		glVertexAttribIPointer(0, 4, GL_UNSIGNED_SHORT, sizeof(GridVertex), null)
		glEnableVertexAttribArray(0)

		return s
	}

	update(s GridBuffer, vertices Array<GridVertex>) {
		assert(vertices.count <= s.maxNumVertices)

		s.numVertices = vertices.count

		if vertices.count == 0 {
			return
		}

		glBindVertexArray(s.vao)
		glBindBuffer(GL_ARRAY_BUFFER, s.vbo)
		glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(GridVertex) * vertices.count, vertices.dataPtr)
	}
	
	draw(s GridBuffer, textureArrayID uint) {
		if s.numVertices == 0 {
			return
		}

		glActiveTexture(GL_TEXTURE0)
		glBindTexture(GL_TEXTURE_2D_ARRAY, textureArrayID)

		glBindVertexArray(s.vao)
		glBindBuffer(GL_ARRAY_BUFFER, s.vbo)
		glDrawArrays(GL_TRIANGLES, 0, s.numVertices)
	}
}

GLTexture struct #RefType {
	id uint
	size IntVector2
	format uint
}

createTextureFromImage(image *Image) {
	textureID := 0_u
	glGenTextures(1, ref textureID)
	glBindTexture(GL_TEXTURE_2D, textureID)

	glPixelStorei(GL_UNPACK_ALIGNMENT, 4)
	glTexImage2D(
		GL_TEXTURE_2D,
		0,
		cast(GL_RGBA8, int),
		image.width,
		image.height,
		0,
		GL_RGBA,
		GL_UNSIGNED_BYTE,
		image.data)

	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, checked_cast(GL_CLAMP_TO_EDGE, int))
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, checked_cast(GL_CLAMP_TO_EDGE, int))
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, checked_cast(GL_NEAREST, int))
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, checked_cast(GL_NEAREST, int))

	return GLTexture { id: textureID, size: IntVector2(image.width, image.height), format: GL_RGBA }
}

createTextureArrayFromImages(images Array<*Image>) {
	textureID := 0_u
	glGenTextures(1, ref textureID)
	glBindTexture(GL_TEXTURE_2D_ARRAY, textureID)

	pixels := new Array<ByteColor4>(images[0].width * images[0].height * images.count)
	for img, i in images {
		if img != null {
			img.array.copySlice(0, img.array.count, pixels, i * img.array.count)
		}
	}

	glPixelStorei(GL_UNPACK_ALIGNMENT, 4)
	glTexImage3D(
		GL_TEXTURE_2D_ARRAY,
		0,
		cast(GL_RGBA8, int),
		images[0].width,
		images[0].height,
		images.count,
		0,
		GL_RGBA,
		GL_UNSIGNED_BYTE,
		pixels.dataPtr)

	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_S, checked_cast(GL_CLAMP_TO_EDGE, int))
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_T, checked_cast(GL_CLAMP_TO_EDGE, int))
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, checked_cast(GL_NEAREST, int))
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, checked_cast(GL_NEAREST, int))

	return GLTexture { id: textureID, size: IntVector2(images[0].width, images[0].height), format: GL_RGBA }
}
