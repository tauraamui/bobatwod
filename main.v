module main

import time
import math
import tauraamui.bobatea as tea

struct GameModel {
mut:
	app_send ?fn (tea.Msg)
	window_width int
	window_height int
	position Point
	delta_z  f64 = 1
	frame_label f64
	frame_count int
	last_fps_update time.Time = time.now()
	angle f64
}

struct FrameTickMsg {
	time time.Time
}

fn (mut m GameModel) init() ?tea.Cmd {
	return tea.emit_resize
}

fn (mut m GameModel) update(msg tea.Msg) (tea.Model, ?tea.Cmd) {
	match msg {
		tea.KeyMsg {
			match msg.k_type {
				.special {
					if msg.string() == 'escape' {
						return m.clone(), tea.quit
					}
					match msg.string() {
						'escape' {
							return m.clone(), tea.quit
						}
						else {}
					}
				}
				.runes {
					if msg.string() == 'q' {
						return m.clone(), tea.quit
					}
					if msg.string() == 'x' {
						m.position = Point{ x: m.position.x + 1, y: m.position.y }
						return m.clone(), none
					}
				}
			}
		}
		tea.ResizedMsg {
			m.window_width = msg.window_width
			m.window_height = msg.window_height
		}
		else {}
	}
	return m.clone(), none
}

const vs := [
	Point{x: .25, y: .25, z: .25}
	Point{x: -.25, y: .25, z: .25}
	Point{x: -.25, y: -.25, z: .25}
	Point{x: .25, y: -.25, z: .25}

	Point{x: .25, y: .25, z: -.25}
	Point{x: -.25, y: .25, z: -.25}
	Point{x: -.25, y: -.25, z: -.25}
	Point{x: .25, y: -.25, z: -.25}
]

const fs := [
	[0, 1, 2, 3]
	[4, 5, 6, 7]
	[0, 4]
	[1, 5]
	[2, 6]
	[3, 7]
]

fn translate_z(p Point, delta_z f64) Point {
	return Point{
		x: p.x
		y: p.y
		z: p.z + delta_z
	}
}

fn rotate_xz(p Point, angle f64) Point {
	c := math.cos(angle)
	s := math.sin(angle)
	return Point{
		x: (p.x * c) - (p.z * s)
		y: p.y
		z: (p.z * s) + (p.z * c)
	}
}

fn (mut m GameModel) view(mut ctx tea.Context) {
	// m.delta_z += (m.frame_label / 1000.0)
	m.angle += math.pi * (m.frame_label / 1000.0)

	ctx.set_bg_color(tea.Color{ 30, 30, 30 })
	ctx.draw_rect(0, 0, m.window_width, m.window_height)
	ctx.reset_bg_color()

	ctx.set_bg_color(tea.Color{ g: 200 })

	/*
	for v in vs {
		point(mut ctx, screen(m.window_width, m.window_height, project(translate_z(rotate_xz(v, m.angle), m.delta_z))))
	}
	*/

	for f in fs {
		for i in 0..f.len {
			a := vs[f[i]]
			b := vs[f[(i + 1) % f.len]]
			line(mut ctx, screen(m.window_width, m.window_height, project(translate_z(rotate_xz(a, m.angle), m.delta_z))),
			screen(m.window_width, m.window_height, project(translate_z(rotate_xz(b, m.angle), m.delta_z))))
		}
	}

	ctx.reset_bg_color()

	ctx.set_color(tea.Color.ansi(255))
	ctx.draw_text(1, 1, "frames: ${m.frame_label}, DELTA Z: ${1 + m.delta_z}")

	if time.now() - m.last_fps_update >= (1 * time.second) {
		m.frame_label = 1000.0 / f64(m.frame_count)
		m.frame_count = 0
		m.last_fps_update = time.now()
	}
	m.frame_count += 1
}

fn (m GameModel) clone() tea.Model {
	return GameModel{
		...m
	}
}

struct Point{
	x f64
	y f64
	z f64
}

fn point(mut ctx tea.Context, p Point) {
	s := 1.0
	ctx.draw_rect(int(p.x - s / 2), int(p.y - s / 2), int(s), int(s))
}

fn line(mut ctx tea.Context, p1 Point, p2 Point) {
	ctx.draw_line(int(p1.x), int(p1.y), int(p2.x), int(p2.y), false)
}

fn screen(width int, height int, p Point) Point {
	w := f64(width)
	h := f64(height)
	return Point{
		x: (p.x + 1) / 2 * w
		y: (1 - (p.y + 1) / 2) * h
	}
}

fn project(p Point) Point {
	return Point{
		x: p.x / p.z
		y: p.y / p.z
	}
}

fn main() {
	mut game_model := GameModel{}
	mut app := tea.new_program(mut game_model)
	game_model.app_send = app.send
	app.run() or { panic('something went wrong! ${err}') }
}

