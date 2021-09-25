//tab_size=4
// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

gridVertexQuad(orig IntVector3, p0 IntVector3, p1 IntVector3, p2 IntVector3, p3 IntVector3, sideLight int, tex int, light int, rotate bool, out List<GridVertex>) {
	out.add(GridVertex { x: cast(orig.x + p0.x, ushort), y: cast(orig.y + p0.y, ushort), zAttr: cast((orig.z + p0.z) | (sideLight << 12), ushort), attr: cast((light << 10) | ((rotate ? 3 : 2) << 8) | tex, ushort) })
	out.add(GridVertex { x: cast(orig.x + p1.x, ushort), y: cast(orig.y + p1.y, ushort), zAttr: cast((orig.z + p1.z) | (sideLight << 12), ushort), attr: cast((light << 10) | ((rotate ? 1 : 3) << 8) | tex, ushort) })
	out.add(GridVertex { x: cast(orig.x + p2.x, ushort), y: cast(orig.y + p2.y, ushort), zAttr: cast((orig.z + p2.z) | (sideLight << 12), ushort), attr: cast((light << 10) | ((rotate ? 2 : 0) << 8) | tex, ushort) })
	out.add(GridVertex { x: cast(orig.x + p1.x, ushort), y: cast(orig.y + p1.y, ushort), zAttr: cast((orig.z + p1.z) | (sideLight << 12), ushort), attr: cast((light << 10) | ((rotate ? 1 : 3) << 8) | tex, ushort) })
	out.add(GridVertex { x: cast(orig.x + p3.x, ushort), y: cast(orig.y + p3.y, ushort), zAttr: cast((orig.z + p3.z) | (sideLight << 12), ushort), attr: cast((light << 10) | ((rotate ? 0 : 1) << 8) | tex, ushort) })
	out.add(GridVertex { x: cast(orig.x + p2.x, ushort), y: cast(orig.y + p2.y, ushort), zAttr: cast((orig.z + p2.z) | (sideLight << 12), ushort), attr: cast((light << 10) | ((rotate ? 2 : 0) << 8) | tex, ushort) })
}

buildGridVertices(g Grid, lg Grid, blockInfos Array<BlockTextureInfo>, blockOut List<GridVertex>, waterOut List<GridVertex>) {
	for x := 0; x < g.size.x {
		for z := 0; z < g.size.z {
			for y := 0; y < g.size.y {
				index := getCellIndex(g, x, y, z)
				block := g.cells[index]
				if block > 0 {
					for d := 0; d < 6 {
						dir := IntVector3.delta[d]
						adj := getCellIndexWrappedXZ(g, x + dir.x, y + dir.y, z + dir.z)
						if adj == -1 && y == 0 {
							continue
						}
						if adj == -1 || (g.cells[adj] <= 1 && g.cells[adj] != block) {
							light := adj >= 0 ? cast(lg.cells[adj], int) : 15
							out := (block == 1) ? waterOut : blockOut
							bi := blockInfos[block]
							if d == 0 {
								gridVertexQuad(IntVector3(x, y, z), IntVector3(0, 0, 1), IntVector3(0, 0, 0), IntVector3(0, 1, 1), IntVector3(0, 1, 0), 1, bi.sideX0, light, bi.rotateSide, out)
							} else if d == 1 {
								gridVertexQuad(IntVector3(x, y, z), IntVector3(1, 0, 0), IntVector3(1, 0, 1), IntVector3(1, 1, 0), IntVector3(1, 1, 1), 1, bi.sideX1, light, bi.rotateSide, out)
							} else if d == 2 {
								gridVertexQuad(IntVector3(x, y, z), IntVector3(0, 0, 0), IntVector3(1, 0, 0), IntVector3(0, 1, 0), IntVector3(1, 1, 0), 2, bi.sideZ0, light, bi.rotateSide, out)
							} else if d == 3 {
								gridVertexQuad(IntVector3(x, y, z), IntVector3(1, 0, 1), IntVector3(0, 0, 1), IntVector3(1, 1, 1), IntVector3(0, 1, 1), 2, bi.sideZ1, light, bi.rotateSide, out)
							} else if d == 4 {
								gridVertexQuad(IntVector3(x, y, z), IntVector3(0, 0, 1), IntVector3(1, 0, 1), IntVector3(0, 0, 0), IntVector3(1, 0, 0), 2, bi.bottom, light, bi.rotateTop, out)
							} else if d == 5 {
								gridVertexQuad(IntVector3(x, y, z), IntVector3(0, 1, 0), IntVector3(1, 1, 0), IntVector3(0, 1, 1), IntVector3(1, 1, 1), 0, bi.top, light, bi.rotateTop, out)
							}
						}
					}
				}
			}
		}
	}
}
