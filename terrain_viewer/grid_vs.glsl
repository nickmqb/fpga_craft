// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

#version 330 core

layout(location = 0) in ivec4 vs_data;

uniform mat4 transform;
uniform vec3 player;

out vec3 fs_tex;
out float fs_light;
out float fs_discard;

void main() {
	int z = vs_data.z & 0x3ff;
	gl_Position = transform * vec4(vs_data.x, vs_data.y, z, 1);
	fs_tex = vec3((vs_data.w >> 8) & 0x1, (vs_data.w >> 9) & 0x1, vs_data.w & 0xff);
	float lightLevel = (vs_data.w >> 10) / 15.0;
	fs_light = (1.0 - 0.25 * (vs_data.z >> 12)) * lightLevel * lightLevel;
	fs_discard = (player.y > 0 && (abs(vs_data.x - player.x) > 28 || abs(z - player.z) > 28)) ? 1 : 0;
}
