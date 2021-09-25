//tab_size=4
// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

:pi = 3.1415926535

sin(f float) float #Foreign("sinf")
cos(f float) float #Foreign("cosf")
tan(f float) float #Foreign("tanf")
atan2f(x float, y float) float #Foreign("atan2f")
sqrt(f float) float #Foreign("sqrtf")
pow(x float, y float) float #Foreign("powf")
floor(f float) float #Foreign("floorf")
frac(f float) {
	return f - floor(f)
}
roundToInt(f float) {
	return cast(floor(f + .5), int)
}
absi(n int) {
	return n >= 0 ? n : -n
}
abs(f float) {
	return f >= 0 ? f : -f
}

clamp(f float, from float, to float) {
	if f < from {
		return from
	} else if f > to {
		return to
	}
	return f
}

clampi(f int, from int, to int) {
	if f < from {
		return from
	} else if f > to {
		return to
	}
	return f
}

lerp(t float, a float, b float) {
	if t < 0 {
		return a
	} else if t > 1 {
		return b
	}
	return (1 - t) * a + t * b
}

domain(t float, from float, to float) float {
	if from > to {
		return 1 - domain(t, to, from)
	}
	if t <= from {
		return 0
	} else if t >= to {
		return 1
	}
	return (t - from) / (to - from)
}

IntVector2 struct {
	x int
	y int

	cons(x int, y int) {
		return IntVector2 { x: x, y: y }
	}

	add(a IntVector2, b IntVector2) {
		return IntVector2(a.x + b.x, a.y + b.y)
	}
}

IntVector3 struct {
	x int
	y int
	z int

	cons(x int, y int, z int) {
		return IntVector3 { x: x, y: y, z: z }
	}

	add(a IntVector3, b IntVector3) {
		return IntVector3(a.x + b.x, a.y + b.y, a.z + b.z)
	}
}

Vector2 struct {
	x float
	y float
	
	cons(x float, y float) {
		return Vector2 { x: x, y: y }
	}

	add(a Vector2, b Vector2) {
		return Vector2(a.x + b.x, a.y + b.y)
	}

	scale(a Vector2, f float) {
		return Vector2(a.x * f, a.y * f)
	}

	dot(a Vector2, b Vector2) {
		return a.x * b.x + a.y * b.y
	}

	rotate(p Vector2, angle float) {
		return Vector2 { x: p.x * cos(angle) - p.y * sin(angle), y: p.x * sin(angle) + p.y * cos(angle) }
	}
}

Vector3 struct {
	x float
	y float
	z float
	
	cons(x float, y float, z float) {
		return Vector3 { x: x, y: y, z: z }
	}

	add(a Vector3, b Vector3) {
		return Vector3(a.x + b.x, a.y + b.y, a.z + b.z)
	}

	scale(a Vector3, f float) {
		return Vector3(a.x * f, a.y * f, a.z * f)
	}

	dot(a Vector3, b Vector3) {
		return a.x * b.x + a.y * b.y + a.z * b.z
	}
}

Matrix struct {
	m00 float
	m01 float
	m02 float
	m03 float
	m10 float
	m11 float
	m12 float
	m13 float
	m20 float
	m21 float
	m22 float
	m23 float
	m30 float
	m31 float
	m32 float
	m33 float

	translate(v Vector3) {
		return Matrix {
			m00: 1, m30: v.x,
			m11: 1, m31: v.y,
			m22: 1, m32: v.z,
			m33: 1
		}
	}

	rotationX(angle float) {
		return Matrix {
			m00: 1,
			m11: cos(angle), m21: sin(angle),
			m12: -sin(angle), m22: cos(angle),
			m33: 1
		}
	}

	rotationY(angle float) {
		return Matrix {
			m00: cos(angle), m20: -sin(angle),
			m11: 1,
			m02: sin(angle), m22: cos(angle),
			m33: 1
		}
	}

	rotationZ(angle float) {
		return Matrix {
			m00: cos(angle), m10: -sin(angle),
			m01: sin(angle), m11: cos(angle),
			m22: 1,
			m33: 1
		}
	}

	perspectiveFovLH(fov float, aspect float, near float, far float) {
		s := 1 / tan(fov * .5)
		q := 1 / (far - near)
		return Matrix {
			m00: s / aspect,
			m11: s,
			m22: (far + near) * q, m32: -2 * far * near * q,
			m23: 1
		}			
	}

	identity() {
		return Matrix { m00: 1, m11: 1, m22: 1, m33: 1 }
	}

	scale(s float) {
		return Matrix { m00: s, m11: s, m22: s, m33: 1 }
	}

	mulv3(m Matrix, v Vector3) {
		return Vector3 {
			x: m.m00 * v.x + m.m10 * v.y + m.m20 * v.z + m.m30,
			y: m.m01 * v.x + m.m11 * v.y + m.m21 * v.z + m.m31,
			z: m.m02 * v.x + m.m12 * v.y + m.m22 * v.z + m.m32,
		}
	}

	mul(a Matrix, b Matrix) {
		return Matrix {
			m00: a.m00 * b.m00 + a.m10 * b.m01 + a.m20 * b.m02 + a.m30 * b.m03,
			m01: a.m01 * b.m00 + a.m11 * b.m01 + a.m21 * b.m02 + a.m31 * b.m03,
			m02: a.m02 * b.m00 + a.m12 * b.m01 + a.m22 * b.m02 + a.m32 * b.m03,
			m03: a.m03 * b.m00 + a.m13 * b.m01 + a.m23 * b.m02 + a.m33 * b.m03,

			m10: a.m00 * b.m10 + a.m10 * b.m11 + a.m20 * b.m12 + a.m30 * b.m13,
			m11: a.m01 * b.m10 + a.m11 * b.m11 + a.m21 * b.m12 + a.m31 * b.m13,
			m12: a.m02 * b.m10 + a.m12 * b.m11 + a.m22 * b.m12 + a.m32 * b.m13,
			m13: a.m03 * b.m10 + a.m13 * b.m11 + a.m23 * b.m12 + a.m33 * b.m13,

			m20: a.m00 * b.m20 + a.m10 * b.m21 + a.m20 * b.m22 + a.m30 * b.m23,
			m21: a.m01 * b.m20 + a.m11 * b.m21 + a.m21 * b.m22 + a.m31 * b.m23,
			m22: a.m02 * b.m20 + a.m12 * b.m21 + a.m22 * b.m22 + a.m32 * b.m23,
			m23: a.m03 * b.m20 + a.m13 * b.m21 + a.m23 * b.m22 + a.m33 * b.m23,

			m30: a.m00 * b.m30 + a.m10 * b.m31 + a.m20 * b.m32 + a.m30 * b.m33,
			m31: a.m01 * b.m30 + a.m11 * b.m31 + a.m21 * b.m32 + a.m31 * b.m33,
			m32: a.m02 * b.m30 + a.m12 * b.m31 + a.m22 * b.m32 + a.m32 * b.m33,
			m33: a.m03 * b.m30 + a.m13 * b.m31 + a.m23 * b.m32 + a.m33 * b.m33,
		}
	}
}

Quaternion struct {
	x float
	y float
	z float
	w float

	identity() {
		return Quaternion { w: 1 }
	}

	rotationX(angle float) {
		half := angle * .5
		return Quaternion { x: -sin(half), w: cos(half) }
	}

	rotationY(angle float) {
		half := angle * .5
		return Quaternion { y: -sin(half), w: cos(half) }
	}

	rotationZ(angle float) {
		half := angle * .5
		return Quaternion { z: -sin(half), w: cos(half) }
	}

	rotationAxis_buggy(axis Vector3, angle float) {
		// Assumes axis has unit length
		half := angle * .5
		f := -sin(angle) // Should be: half
		return Quaternion { x: axis.x * f, y: axis.y * f, z: axis.z * f, w: cos(half) }
	}

	mul(a Quaternion, b Quaternion) {
		return Quaternion {
			x: a.x * b.w + a.w * b.x + a.y * b.z - a.z * b.y,
			y: a.y * b.w + a.w * b.y + a.z * b.x - a.x * b.z,
			z: a.z * b.w + a.w * b.z + a.x * b.y - a.y * b.x,
			w: a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
		}
	}

	toMatrix(q Quaternion) {
		xx := q.x * q.x
		xy := q.x * q.y
		xz := q.x * q.z
		xw := q.x * q.w
		yy := q.y * q.y
		yz := q.y * q.z
		yw := q.y * q.w
		zz := q.z * q.z
		zw := q.z * q.w
		return Matrix {
			m00: 1 - (2 * (yy + zz)),
			m01: 2 * (xy + zw),
			m02: 2 * (xz - yw),
			m10: 2 * (xy - zw),
			m11: 1 - (2 * (xx + zz)),
			m12: 2 * (xw + yz),
			m20: 2 * (xz + yw),
			m21: 2 * (yz - xw),
			m22: 1 - (2 * (xx + yy)),
			m33: 1,
		}
	}
}

nibbleToHex(val uint) {
	return "0123456789abcdef"[val]
}

writeArray(mem Array<T>, sb StringBuilder) {
	writeByteArray(ref Array<byte> { dataPtr: mem.dataPtr, count: CheckedMath.mulPositiveInt(mem.count, sizeof(T)) }, sb)
}

writeBinaryFile(mem Array<byte>, path string) {
	assert(File.tryWriteString(path, string.from(mem.dataPtr, mem.count)))
}

writeByteArray(mem Array<byte>, sb StringBuilder) {
	rows := (mem.count + 31) / 32
	for j := 0; j < rows {
		sb.write("\t")
		for i := 0; i < 32 {
			addr := j * 32 + i
			if addr < mem.count {
				val := mem[addr]
				sb.write(format("{}{}", nibbleToHex(val / 16_u), nibbleToHex(val % 16_u)))
			} else {
				sb.write("00")
			}
		}
		sb.write("\n")
	}
}
