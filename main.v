module main

import os
import time
import math
import tauraamui.bobatea as tea

// =========================
// Data Types
// =========================

struct Point {
	x f64
	y f64
	z f64
}

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

// =========================
// Dynamic Mesh Storage
// =========================

__global (
	vs []Point
	fs [][]int
)

// =========================
// OBJ Loader
// =========================

fn load_obj(path string) ! {
	lines := os.read_lines(path)!

	for line in lines {
		if line.len == 0 { continue }

		// Vertex
		if line.starts_with('v ') {
			parts := line.split_by_space()
			if parts.len < 4 { continue }

			vs << Point{
				x: parts[1].f64()
				y: parts[2].f64()
				z: parts[3].f64()
			}
		}

		// Face
		if line.starts_with('f ') {
			parts := line.split_by_space()[1..]
			mut face := []int{}

			for p in parts {
				// supports:
				// f v
				// f v/vt
				// f v//vn
				// f v/vt/vn
				idx := p.split('/')[0].int() - 1
				face << idx
			}

			if face.len >= 3 {
				fs << face
			}
		}
	}
}

// =========================
// BubbleTea Methods
// =========================

struct TickMsg {
    time time.Time
}

pub fn tick_cmd() tea.Cmd {
	return tea.tick(1 * time.millisecond, fn (t time.Time) tea.Msg {
		return TickMsg{
			time: t
		}
	})
}

fn (mut m GameModel) init() ?tea.Cmd {
    return tea.sequence(tea.emit_resize, tick_cmd())
}

fn (mut m GameModel) update(msg tea.Msg) (tea.Model, ?tea.Cmd) {
	match msg {
        TickMsg {
            return m.clone(), tick_cmd()
        }
		tea.KeyMsg {
			match msg.k_type {
				.special {
					if msg.string() == 'escape' {
						return m.clone(), tea.quit
					}
				}
				.runes {
					if msg.string() == 'q' {
						return m.clone(), tea.quit
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

// =========================
// Rendering
// =========================

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
		z: (p.x * s) + (p.z * c)
	}
}

fn project(p Point) Point {
	return Point{
		x: p.x / p.z
		y: p.y / p.z
		z: p.z
	}
}

fn screen(width int, height int, p Point) Point {
	w := f64(width)
	h := f64(height)
	return Point{
		x: (p.x + 1) / 2 * w
		y: (1 - (p.y + 1) / 2) * h
		z: p.z
	}
}

fn line(mut ctx tea.Context, p1 Point, p2 Point) {
	ctx.draw_line(int(p1.x), int(p1.y), int(p2.x), int(p2.y), false)
}

fn (mut m GameModel) view(mut ctx tea.Context) {
	m.angle += math.pi * (m.frame_label / 1000.0)

	ctx.set_bg_color(tea.Color{30, 30, 30})
	ctx.draw_rect(0, 0, m.window_width, m.window_height)
	ctx.reset_bg_color()

	ctx.set_color(tea.Color{g: 200})
	ctx.set_stroke('■')
	defer { ctx.set_stroke(` `.str()) }
	for f in fs {
		for i in 0 .. f.len {
			a := vs[f[i]]
			b := vs[f[(i + 1) % f.len]]

			line(
				mut ctx,
				screen(
					m.window_width,
					m.window_height,
					project(translate_z(rotate_xz(a, m.angle), m.delta_z))
				),
				screen(
					m.window_width,
					m.window_height,
					project(translate_z(rotate_xz(b, m.angle), m.delta_z))
				)
			)
		}
	}

	ctx.reset_color()

	ctx.set_color(tea.Color.ansi(255))
	ctx.draw_text(1, 1, "frames: ${m.frame_label}")

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

// =========================
// Entry
// =========================

fn main() {
	load_obj('model.obj') or {
		panic(err)
	}

	mut game_model := GameModel{}
	mut app := tea.new_program(mut game_model)
	game_model.app_send = app.send
	app.run() or { panic('something went wrong! ${err}') }
}
